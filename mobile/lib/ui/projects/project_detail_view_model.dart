import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';

import '../../data/models/project.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../../data/services/github_service.dart';

class ProjectDetailViewModel extends ChangeNotifier {
  ProjectDetailViewModel(
    this._repository, {
    required List<ProjectRepo> repositories,
    required this.accessToken,
    this.telemetry,
  }) : repositories = [...repositories] {
    telemetry?.event(
      AppEvent.projectDetailView,
      parameters: {'repo_count': repositories.length},
    );
  }

  AsyncState<Map<int, WorkflowRun?>> get state => AsyncState.resolve(
    data: Map.unmodifiable(latestRuns),
    loading: loading,
    empty: latestRuns.isEmpty || latestRuns.values.every((run) => run == null),
    error: errors.values.join('\n'),
  );

  final GitHubActionsRepository _repository;
  final AppTelemetry? telemetry;
  static const int pageSize = 5;
  final String? accessToken;
  List<ProjectRepo> repositories;
  Map<int, WorkflowRun?> latestRuns = {};
  Map<int, String> errors = {};
  int visibleCount = 0;
  bool loading = false;
  DateTime? updatedAt;
  bool _disposed = false;
  int _version = 0;

  bool get hasMore => visibleCount < repositories.length;

  Future<void> updateRepositories(
    List<ProjectRepo> updated, {
    bool refresh = false,
  }) async {
    if (_disposed) return;
    if (listEquals(
      repositories.map((r) => '${r.id}:${r.fullName}').toList(),
      updated.map((r) => '${r.id}:${r.fullName}').toList(),
    )) {
      if (refresh) await load();
      return;
    }
    _version++;
    repositories = [...updated];
    latestRuns = {};
    errors = {};
    visibleCount = 0;
    updatedAt = null;
    loading = false;
    await load();
  }

  Future<void> load({bool more = false}) async {
    if (_disposed || loading || (more && !hasMore)) return;
    final version = ++_version;
    final size = pageSize;
    final append = more;
    final count = math.min(
      repositories.length,
      append ? visibleCount + size : math.max(visibleCount, size),
    );
    final start = append ? visibleCount : 0;
    final batch = repositories.sublist(start, count);
    final nextRuns = {...latestRuns};
    final nextErrors = append ? {...errors} : <int, String>{};
    var signInRequired = false;
    loading = true;
    notifyListeners();

    // Keep at most five requests in flight, and publish the whole result together.
    for (var index = 0; index < batch.length; index += 5) {
      if (_disposed || version != _version) return;
      await Future.wait(
        batch.skip(index).take(5).map((repo) async {
          try {
            final page = await _repository.getRuns(
              accessToken,
              repo,
              perPage: 1,
            );
            nextRuns[repo.id] = page.runs.isEmpty ? null : page.runs.first;
            nextErrors.remove(repo.id);
          } catch (error, stack) {
            if (!_disposed) {
              telemetry?.nonFatal(error, stack, AppOperation.runRead);
            }
            nextErrors[repo.id] = error is GitHubException
                ? error.message
                : 'Chưa tải được lần chạy gần nhất. Hãy thử lại.';
            if (error is GitHubException &&
                (error.accessDenied || error.requiresSignIn)) {
              nextRuns.remove(repo.id);
            }
            if (error is GitHubException && error.requiresSignIn) {
              signInRequired = true;
            }
          }
        }),
      );
    }
    if (_disposed || version != _version) return;
    if (signInRequired) {
      nextRuns.clear();
      for (final repo in repositories.take(count)) {
        nextErrors[repo.id] =
            'Phiên GitHub không còn hợp lệ. Hãy đăng xuất rồi đăng nhập lại.';
      }
    }
    latestRuns = nextRuns;
    errors = nextErrors;
    visibleCount = count;
    loading = false;
    updatedAt = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }
}
