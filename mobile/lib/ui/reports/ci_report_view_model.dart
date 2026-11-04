import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../data/models/ci_report.dart';
import '../../data/repositories/ci_report_repository.dart';
import '../../data/services/cloudinary_report_storage_service.dart';

class CiReportViewModel extends ChangeNotifier {
  CiReportViewModel(
    this.repository,
    this.report, {
    this.telemetry,
    this.uploadTimeout = const Duration(minutes: 2),
  }) {
    _session = repository.storage.sessions.listen((uid) {
      if (uid != report.ownerUid) _revoke();
    }, onError: (Object error) => _revoke());
  }
  final CiReportRepository repository;
  final CiReportSnapshot report;
  final AppTelemetry? telemetry;
  final Duration uploadTimeout;
  AsyncState<CiReportFile> state = const AsyncState.empty();
  double progress = 0;
  bool uploaded = false;
  bool uploading = false;
  bool sharing = false;
  bool opening = false;
  String? downloadUrl;
  String message = '';
  bool _disposed = false;
  bool _revoked = false;
  int _operation = 0;
  ReportUpload? _task;
  StreamSubscription<double>? _progress;
  StreamSubscription<String?>? _session;
  CiReportFile? get file => state.data;
  bool get busy => state.isLoading || uploading || sharing || opening;
  bool get available => !_disposed && !_revoked;
  bool _current(int operation) => available && operation == _operation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _checkOwner() {
    if (!available) {
      throw const CiReportException('Phiên đã thay đổi. Hãy mở lại báo cáo.');
    }
    repository.requireOwner(report.ownerUid);
  }

  void _revoke() {
    if (_disposed || _revoked) return;
    _revoked = true;
    _operation++;
    _cancelTask();
    downloadUrl = null;
    uploaded = false;
    uploading = false;
    state = const AsyncState.error('Phiên đã thay đổi. Hãy mở lại báo cáo.');
    _notify();
  }

  Future<void> generate() async {
    if (!available || busy || file != null) return;
    final operation = ++_operation;
    state = const AsyncState.loading();
    message = '';
    _notify();
    try {
      final result = await repository.generate(report);
      if (!_current(operation)) return;
      state = AsyncState.success(result);
      telemetry?.event(AppEvent.reportExport);
    } catch (error, stack) {
      if (!_current(operation)) return;
      telemetry?.nonFatal(error, stack, AppOperation.reportGenerate);
      state = AsyncState.error(reportErrorMessage(error));
    }
    if (_current(operation)) _notify();
  }

  Future<void> upload() async {
    final pdf = file;
    if (!available || busy || pdf == null || downloadUrl != null) return;
    final operation = ++_operation;
    state = AsyncState.loading(pdf);
    uploading = true;
    message = '';
    _notify();
    try {
      _checkOwner();
      progress = 0;
      final task = repository.storage.upload(report.ownerUid, pdf);
      _task = task;
      _progress = task.progress.listen(
        (value) {
          if (_current(operation) && value.isFinite) {
            progress = value.clamp(0.0, 1.0);
            _notify();
          }
        },
        onError: (Object error) {
          /* The completion future reports upload failure. */
        },
      );
      final resultUrl = await task.done.timeout(uploadTimeout);
      if (!_current(operation)) return;
      _checkOwner();
      downloadUrl = resultUrl;
      uploaded = true;
      progress = 1;
      state = AsyncState.success(pdf);
      message = 'Đã lưu báo cáo lên đám mây.';
      telemetry?.event(AppEvent.reportUpload);
    } catch (error, stack) {
      if (!_current(operation)) return;
      telemetry?.nonFatal(error, stack, AppOperation.reportUpload);
      if (error is TimeoutException) _cancelTask();
      state = AsyncState.error(reportErrorMessage(error), pdf);
    } finally {
      if (_current(operation)) {
        final subscription = _progress;
        if (subscription != null) unawaited(subscription.cancel());
        _progress = null;
        _task = null;
        uploading = false;
        _notify();
      }
    }
  }

  Future<void> cancelUpload() async {
    if (!uploading || !available) return;
    final pdf = file;
    _operation++;
    _cancelTask();
    uploading = false;
    state = pdf == null ? const AsyncState.empty() : AsyncState.success(pdf);
    message = 'Đã hủy upload. Bản PDF vẫn có thể lưu hoặc thử tải lên lại.';
    _notify();
  }

  void _cancelTask() {
    final task = _task;
    _task = null;
    if (task != null) unawaited(task.cancel().catchError((Object _) {}));
    _progress?.cancel();
    _progress = null;
  }

  Future<void> share() async {
    final pdf = file;
    if (!available || busy || pdf == null) return;
    sharing = true;
    _notify();
    try {
      _checkOwner();
      final accepted = await repository.sharing.share(pdf);
      if (!available) return;
      _checkOwner();
      message = accepted
          ? 'Đã mở trình lưu/chia sẻ PDF.'
          : 'Đã đóng trình lưu/chia sẻ.';
    } catch (error, stack) {
      if (!available) return;
      telemetry?.nonFatal(error, stack, AppOperation.reportShare);
      state = AsyncState.error(reportErrorMessage(error), pdf);
    } finally {
      sharing = false;
      _notify();
    }
  }

  Future<void> openUploaded() async {
    final url = downloadUrl;
    final pdf = file;
    if (!available || busy || url == null || pdf == null) return;
    opening = true;
    _notify();
    try {
      _checkOwner();
      if (!await repository.sharing.openUrl(url)) {
        throw const CiReportException(
          'Chưa mở được báo cáo. Bạn vẫn có thể lưu/chia sẻ PDF trên máy.',
        );
      }
    } catch (error, stack) {
      if (!available) return;
      telemetry?.nonFatal(error, stack, AppOperation.reportOpen);
      state = AsyncState.error(reportErrorMessage(error), pdf);
    } finally {
      opening = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    _cancelTask();
    _session?.cancel();
    downloadUrl = null;
    state = const AsyncState.empty();
    super.dispose();
  }
}
