enum AppEvent {
  login('login'),
  logout('logout'),
  sessionRestored('session_restored'),
  projectCreate('project_create'),
  projectUpdate('project_update'),
  projectDelete('project_delete'),
  projectDetailView('project_detail_view'),
  workflowDetailView('workflow_detail_view'),
  analysisStart('ci_analysis_start'),
  analysisComplete('ci_analysis_complete'),
  rerunRequested('workflow_rerun_requested'),
  commentSent('pr_comment_sent');

  const AppEvent(this.name);
  final String name;
}

enum AppOperation {
  bootstrap,
  authSession,
  profileRead,
  oauth,
  logout,
  projectRead,
  projectWrite,
  repositoryRead,
  runRead,
  logRead,
  analysisRead,
  analysisPrepare,
  analysisRun,
  analysisSave,
  rerun,
  attemptRead,
  pullRequestRead,
  commentWrite,
  remoteConfig,
  flutterFramework,
  platformDispatcher,
  debugTest,
}

abstract class AppTelemetry {
  String get analyticsError => '';
  String get crashError => '';
  void identify(String? uid);
  void event(AppEvent event, {Map<String, Object> parameters = const {}});
  void nonFatal(Object error, StackTrace stack, AppOperation operation);
}

/// Keep event payloads small, numeric and defined by the analytics plan.
Map<String, Object> analyticsParameters(
  AppEvent event,
  Map<String, Object> input,
) {
  if (event == AppEvent.login) return {'method': 'github'};
  final key = switch (event) {
    AppEvent.projectCreate ||
    AppEvent.projectUpdate ||
    AppEvent.projectDetailView => 'repo_count',
    AppEvent.workflowDetailView => 'attempt',
    AppEvent.rerunRequested => 'failed_only',
    _ => null,
  };
  final value = input[key];
  if (key == null || value is! int) return const {};
  final valid = switch (key) {
    'repo_count' => value >= 0 && value <= 50,
    'attempt' => value >= 1,
    'failed_only' => value == 0 || value == 1,
    _ => false,
  };
  return valid ? {key: value} : const {};
}

/// Deliberately excludes exception messages, URLs, logs and provider payloads.
String diagnosticError(Object error, AppOperation operation) =>
    '${operation.name}:${error.runtimeType}';
