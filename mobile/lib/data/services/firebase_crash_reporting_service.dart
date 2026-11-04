import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/telemetry/app_telemetry.dart';
import 'telemetry_service.dart';

class FirebaseCrashReportingService implements CrashSink {
  final FirebaseCrashlytics _crashes = FirebaseCrashlytics.instance;
  Future<void> initialize() async {
    await _crashes.setCrashlyticsCollectionEnabled(true);
    await _crashes.setCustomKey(
      'build_mode',
      kDebugMode
          ? 'debug'
          : kProfileMode
          ? 'profile'
          : 'release',
    );
  }

  void installGlobalHandlers(TelemetryService telemetry) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      telemetry.record(
        details.exception,
        details.stack ?? StackTrace.current,
        AppOperation.flutterFramework,
        fatal: true,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      telemetry.record(
        error,
        stack,
        AppOperation.platformDispatcher,
        fatal: true,
      );
      return true;
    };
  }

  @override
  Future<void> identify(String? uid) => _crashes.setUserIdentifier(uid ?? '');
  @override
  Future<void> record(
    String safeError,
    StackTrace stack,
    AppOperation operation, {
    required bool fatal,
  }) async {
    await _crashes.setCustomKey('app_area', operation.name);
    await _crashes.recordError(
      safeError,
      stack,
      reason: operation.name,
      fatal: fatal,
      printDetails: false,
    );
  }

  void testCrash() {
    if (!kDebugMode) return;
    _crashes.crash();
  }
}
