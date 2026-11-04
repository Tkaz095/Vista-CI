import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/telemetry/app_telemetry.dart';

abstract interface class AnalyticsSink {
  Future<void> identify(String? uid);
  Future<void> event(String name, Map<String, Object> parameters);
}

abstract interface class CrashSink {
  Future<void> identify(String? uid);
  Future<void> record(
    String safeError,
    StackTrace stack,
    AppOperation operation, {
    required bool fatal,
  });
}

/// Serializes identity changes before events; SDK failures never fail business work.
class TelemetryService extends ChangeNotifier implements AppTelemetry {
  TelemetryService(this.analytics, this.crashes);
  final AnalyticsSink analytics;
  final CrashSink crashes;
  Future<void> _analyticsTail = Future.value();
  Future<void> _crashTail = Future.value();
  @override
  String analyticsError = '';
  @override
  String crashError = '';
  bool _analyticsReady = true;
  bool _crashReady = true;
  bool _disposed = false;
  Future<void> get settled => Future.wait([_analyticsTail, _crashTail]);

  Future<bool> _safe(
    Future<void> Function() action, {
    required bool crash,
  }) async {
    try {
      await action().timeout(const Duration(seconds: 5));
      if (!_disposed && (crash ? crashError : analyticsError).isNotEmpty) {
        if (crash) {
          crashError = '';
        } else {
          analyticsError = '';
        }
        notifyListeners();
      }
      return true;
    } catch (_) {
      if (_disposed) return false;
      if (crash) {
        crashError = 'Chưa ghi được chẩn đoán lỗi.';
      } else {
        analyticsError = 'Chưa ghi được sự kiện sử dụng.';
      }
      notifyListeners();
      return false;
    }
  }

  @override
  void identify(String? uid) {
    if (_disposed) return;
    _analyticsTail = _analyticsTail.then((_) async {
      _analyticsReady = await _safe(
        () => analytics.identify(uid),
        crash: false,
      );
    });
    _crashTail = _crashTail.then((_) async {
      _crashReady = await _safe(() => crashes.identify(uid), crash: true);
    });
  }

  @override
  void event(AppEvent event, {Map<String, Object> parameters = const {}}) {
    if (_disposed) return;
    final safe = analyticsParameters(event, parameters);
    _analyticsTail = _analyticsTail.then((_) async {
      if (_analyticsReady) {
        await _safe(() => analytics.event(event.name, safe), crash: false);
      }
    });
  }

  @override
  void nonFatal(Object error, StackTrace stack, AppOperation operation) =>
      record(error, stack, operation, fatal: false);

  void record(
    Object error,
    StackTrace stack,
    AppOperation operation, {
    required bool fatal,
  }) {
    if (_disposed) return;
    final safe = diagnosticError(error, operation);
    _crashTail = _crashTail.then((_) async {
      if (_crashReady) {
        await _safe(
          () => crashes.record(safe, stack, operation, fatal: fatal),
          crash: true,
        );
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
