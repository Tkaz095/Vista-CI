import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';

import '../../data/models/project.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../../data/services/github_service.dart';

enum RunFilter {
  all('Tất cả', null),
  success('Thành công', 'success'),
  failure('Thất bại', 'failure'),
  running('Đang chạy', 'in_progress');

  const RunFilter(this.label, this.status);
  final String label;
  final String? status;
}

class RepositoryRunsViewModel extends ChangeNotifier {
  RepositoryRunsViewModel(
    this._repository, {
    required this.repo,
    required this.accessToken,
  });

  AsyncState<List<WorkflowRun>> get state => AsyncState.resolve(
    data: List.unmodifiable(runs),
    loading: loading,
    empty: runs.isEmpty,
    error: error,
  );

  final GitHubActionsRepository _repository;
  final ProjectRepo repo;
  final String? accessToken;
  List<WorkflowRun> runs = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasLoaded = false;
  bool hasMore = false;
  String error = '';
  RunFilter filter = RunFilter.all;
  int _page = 0;
  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> selectFilter(RunFilter selected) async {
    if (_disposed || filter == selected) return;
    // A different filter starts a new query; old requests cannot publish results.
    _requestVersion++;
    filter = selected;
    runs = [];
    _page = 0;
    hasMore = false;
    hasLoaded = false;
    loading = false;
    await load();
  }

  Future<void> load({bool more = false}) async {
    if (_disposed || loading || (more && !hasMore)) return;
    final version = ++_requestVersion;
    loading = true;
    loadingMore = more;
    error = '';
    notifyListeners();
    try {
      final page = more ? _page + 1 : 1;
      final result = await _repository.getRuns(
        accessToken,
        repo,
        page: page,
        status: filter.status,
      );
      if (_disposed || version != _requestVersion) return;
      final byId = {
        if (more)
          for (final run in runs) run.id: run,
      };
      for (final run in result.runs) {
        byId[run.id] = run;
      }
      runs = byId.values.toList();
      _page = page;
      hasMore = result.hasMore;
    } catch (failure) {
      if (_disposed || version != _requestVersion) return;
      error = failure is GitHubException
          ? failure.message
          : 'Chưa tải được lịch sử chạy. Hãy thử lại.';
      if (failure is GitHubException &&
          (failure.requiresSignIn || failure.accessDenied)) {
        runs = [];
        hasMore = false;
        _page = 0;
      }
    } finally {
      if (!_disposed && version == _requestVersion) {
        hasLoaded = true;
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
