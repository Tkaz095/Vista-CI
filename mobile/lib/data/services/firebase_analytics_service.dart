import 'package:firebase_analytics/firebase_analytics.dart';

import 'telemetry_service.dart';

class FirebaseAnalyticsService implements AnalyticsSink {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  @override
  Future<void> identify(String? uid) => _analytics.setUserId(id: uid);
  @override
  Future<void> event(String name, Map<String, Object> parameters) => _analytics
      .logEvent(name: name, parameters: parameters.isEmpty ? null : parameters);
}
