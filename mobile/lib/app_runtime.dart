import 'dart:async';

import 'data/services/firebase_analytics_service.dart';
import 'data/services/firebase_crash_reporting_service.dart';
import 'data/services/remote_config_service.dart';
import 'data/services/telemetry_service.dart';
import 'ui/settings/app_config_view_model.dart';
import 'core/telemetry/app_telemetry.dart';

/// Composition root: all three SDKs use the default Firebase app (vista-ci).
class AppRuntime {
  AppRuntime() {
    crashes = FirebaseCrashReportingService();
    telemetry = TelemetryService(FirebaseAnalyticsService(), crashes);
    configuration = AppConfigViewModel(
      RemoteConfigService(),
      telemetry: telemetry,
    );
  }
  late final FirebaseCrashReportingService crashes;
  late final TelemetryService telemetry;
  late final AppConfigViewModel configuration;
  Future<void> initialize() async {
    crashes.installGlobalHandlers(telemetry);
    telemetry.identify(null);
    try {
      await crashes.initialize().timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      telemetry.nonFatal(error, stack, AppOperation.bootstrap);
    }
    unawaited(configuration.refresh());
  }
}
