import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../data/models/ci_notification_mode.dart';
import '../../data/models/project.dart';
import '../../data/services/ci_notification_preferences_service.dart';

class CiNotificationPreferencesViewModel extends ChangeNotifier {
  CiNotificationPreferencesViewModel(
    this.source, {
    required this.uid,
    required this.repo,
    this.telemetry,
  });
  final CiNotificationPreferences source;
  final String uid;
  final ProjectRepo repo;
  final AppTelemetry? telemetry;
  AsyncState<CiNotificationMode> state = const AsyncState.loading();
  bool saving = false;
  String message = '';
  bool _disposed = false;
  Timer? _deadline;
  int _version = 0;
  StreamSubscription<CiNotificationMode>? _subscription;

  Future<void> load() async {
    if (_disposed) return;
    final version = ++_version;
    state = const AsyncState.loading();
    message = '';
    _deadline?.cancel();
    _deadline = Timer(const Duration(seconds: 15), () {
      if (_disposed || version != _version || !state.isLoading) return;
      state = const AsyncState.error(
        'Chưa xác minh được tùy chọn với Firebase. Kiểm tra mạng rồi tải lại.',
      );
      notifyListeners();
    });
    notifyListeners();
    await _subscription?.cancel();
    if (_disposed || version != _version) return;
    try {
      _subscription = source
          .watch(uid, repo)
          .listen(
            (mode) {
              if (_disposed || version != _version) return;
              _deadline?.cancel();
              state = AsyncState.success(mode);
              notifyListeners();
            },
            onError: (Object error, StackTrace stack) {
              if (_disposed || version != _version) return;
              _deadline?.cancel();
              telemetry?.nonFatal(error, stack, AppOperation.notifications);
              state = const AsyncState.error(
                'Chưa đọc được tùy chọn thông báo. Kiểm tra mạng và Rules ciSubscriptions rồi thử lại.',
              );
              notifyListeners();
            },
          );
    } catch (error, stack) {
      if (_disposed || version != _version) return;
      _deadline?.cancel();
      telemetry?.nonFatal(error, stack, AppOperation.notifications);
      state = const AsyncState.error(
        'Chưa đọc được tùy chọn thông báo. Hãy thử lại.',
      );
      notifyListeners();
    }
  }

  Future<void> save(CiNotificationMode mode) async {
    if (_disposed || saving || state.data == null || state.hasError) return;
    final version = _version;
    saving = true;
    message = '';
    notifyListeners();
    try {
      await source.save(uid, repo, mode);
      if (_disposed || version != _version) return;
      state = AsyncState.success(mode);
      message = 'Đã lưu tùy chọn cho repository này.';
    } catch (error, stack) {
      if (_disposed || version != _version) return;
      telemetry?.nonFatal(error, stack, AppOperation.notifications);
      message =
          'Chưa xác nhận được thay đổi. Kiểm tra mạng rồi tải lại tùy chọn.';
    } finally {
      if (!_disposed && version == _version) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _disposed = true;
    _version++;
    _subscription?.cancel();
    super.dispose();
  }
}
