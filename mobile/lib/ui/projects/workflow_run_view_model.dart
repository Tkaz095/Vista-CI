import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';

import '../../data/models/ci_analysis.dart';
import '../../data/repositories/ci_analysis_repository.dart';

import '../../data/models/project.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../../data/services/github_service.dart';

class WorkflowRunViewModel extends ChangeNotifier {
  WorkflowRunViewModel(
    this._repository, {
    required this.repo,
    required this.run,
    required this.accessToken,
    CiAnalysisRepository? analysisRepository,
  }) : _analyses = analysisRepository ?? CiAnalysisRepository(_repository);

  AsyncState<WorkflowRunDetails?> get state => AsyncState.resolve(
    data: details,
    loading: loading,
    empty: details == null || details!.jobs.isEmpty,
    error: error,
  );
  AsyncState<CiAnalysis?> get analysisState => AsyncState.resolve(
    data: analysis,
    loading: readingAnalysis || analyzing,
    empty: analysis == null,
    error: analysisError,
  );
  AsyncState<CiAnalysisInput?> get preparationState => AsyncState.resolve(
    data: preparedAnalysis,
    loading: preparingAnalysis,
    empty: preparedAnalysis == null,
    error: analysisError,
  );
  AsyncState<List<GitHubPullRequest>> get pullRequestsState =>
      AsyncState.resolve(
        data: List.unmodifiable(pullRequests),
        loading: loadingPullRequests,
        empty: pullRequests.isEmpty,
        error: commentError,
      );
  AsyncState<WorkflowLog?> logState(int jobId) => AsyncState.resolve(
    data: logs[jobId],
    loading: loadingJobs.contains(jobId),
    empty: logs[jobId] == null || logs[jobId]!.text.isEmpty,
    error: logErrors[jobId] ?? '',
  );

  final GitHubActionsRepository _repository;
  final ProjectRepo repo;
  WorkflowRun run;
  final CiAnalysisRepository _analyses;
  final String? accessToken;
  WorkflowRunDetails? details;
  bool loading = false;
  String error = '';
  final Map<int, WorkflowLog> logs = {};
  final Map<int, String> logErrors = {};
  final Set<int> loadingJobs = {};
  final Map<int, int> _jobVersions = {};
  bool _disposed = false;
  int _analysisVersion = 0;
  CiAnalysis? analysis;
  CiAnalysisInput? preparedAnalysis;
  bool preparingAnalysis = false;
  bool analyzing = false;
  bool readingAnalysis = false;
  String analysisError = '';
  String analysisWarning = '';
  bool actionBusy = false;
  bool waitingForRerun = false;
  String actionError = '';
  String actionMessage = '';
  bool loadingPullRequests = false;
  bool hasLoadedPullRequests = false;
  bool postingComment = false;
  String commentError = '';
  List<GitHubPullRequest> pullRequests = [];
  GitHubPullRequest? selectedPullRequest;
  final Map<int, GitHubComment> postedComments = {};
  final Set<int> uncertainComments = {};

  bool get canRerun =>
      details != null &&
      run.status == 'completed' &&
      !loading &&
      !actionBusy &&
      !waitingForRerun &&
      !analyzing &&
      !preparingAnalysis;
  bool get hasFailedJobs =>
      details?.jobs.any(
        (job) => job.conclusion == 'failure' || job.conclusion == 'timed_out',
      ) ??
      false;
  bool get canAnalyze => canRerun && hasFailedJobs && !readingAnalysis;

  int? get initialJobId {
    final jobs = details?.jobs ?? [];
    for (final job in jobs) {
      if (job.conclusion == 'failure' || job.conclusion == 'timed_out') {
        return job.id;
      }
    }
    return jobs.isEmpty ? null : jobs.first.id;
  }

  Future<void> load() async {
    if (_disposed || loading || actionBusy) return;
    if (waitingForRerun) {
      await showLatestAttempt();
      return;
    }
    loading = true;
    error = '';
    notifyListeners();
    try {
      final result = await _repository.getRunDetails(accessToken, repo, run);
      if (_disposed) return;
      details = result;
      run = result.run;
      final validIds = result.jobs.map((job) => job.id).toSet();
      for (final id in _jobVersions.keys.toList()) {
        if (!validIds.contains(id)) _jobVersions[id] = _jobVersions[id]! + 1;
      }
      logs.removeWhere((id, _) => !validIds.contains(id));
      logErrors.removeWhere((id, _) => !validIds.contains(id));
      loadingJobs.removeWhere((id) => !validIds.contains(id));
      final refreshIds = {
        ...logs.keys,
        ...logErrors.keys,
        ...loadingJobs,
        ?initialJobId,
      }.toList();
      // Refresh loaded jobs in small batches, without discarding their current log.
      for (var index = 0; index < refreshIds.length; index += 3) {
        if (_disposed) return;
        await Future.wait(
          refreshIds
              .skip(index)
              .take(3)
              .map((id) => loadJobLog(id, refresh: true)),
        );
      }
    } catch (failure) {
      if (_disposed) return;
      error = failure is GitHubException
          ? failure.message
          : 'Chưa tải được thông tin run. Kéo xuống để thử lại.';
      if (failure is GitHubException &&
          (failure.requiresSignIn || failure.accessDenied)) {
        details = null;
        _clearAnalysis();
        for (final id in _jobVersions.keys.toList()) {
          _jobVersions[id] = _jobVersions[id]! + 1;
        }
        logs.clear();
        logErrors.clear();
        loadingJobs.clear();
      }
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
        if (details != null &&
            analysis == null &&
            !analyzing &&
            !preparingAnalysis) {
          unawaited(_readSavedAnalysis());
        }
      }
    }
  }

  Future<void> loadJobLog(int jobId, {bool refresh = false}) async {
    if (_disposed ||
        details == null ||
        !details!.jobs.any((job) => job.id == jobId)) {
      return;
    }
    if (!refresh && (loadingJobs.contains(jobId) || logs.containsKey(jobId))) {
      return;
    }
    final version = (_jobVersions[jobId] ?? 0) + 1;
    _jobVersions[jobId] = version;
    logErrors.remove(jobId);
    loadingJobs.add(jobId);
    notifyListeners();
    try {
      final result = await _repository.getJobLog(accessToken, repo, jobId);
      if (!_disposed && _jobVersions[jobId] == version) logs[jobId] = result;
    } catch (failure) {
      if (_disposed || _jobVersions[jobId] != version) return;
      logErrors[jobId] = failure is GitHubException
          ? failure.message
          : 'Chưa tải được log. Kéo xuống để thử lại.';
      if (failure is GitHubException &&
          (failure.requiresSignIn || failure.accessDenied)) {
        logs.remove(jobId);
      }
    } finally {
      if (!_disposed && _jobVersions[jobId] == version) {
        loadingJobs.remove(jobId);
        notifyListeners();
      }
    }
  }

  void _clearAnalysis() {
    _analysisVersion++;
    analysis = null;
    preparedAnalysis = null;
    analysisError = '';
    analysisWarning = '';
    readingAnalysis = false;
    preparingAnalysis = false;
    analyzing = false;
    pullRequests = [];
    selectedPullRequest = null;
    loadingPullRequests = false;
    hasLoadedPullRequests = false;
    postingComment = false;
    commentError = '';
    postedComments.clear();
    uncertainComments.clear();
  }

  String _message(Object failure, String fallback) => switch (failure) {
    GitHubException() => failure.message,
    CiAnalysisException() => failure.message,
    _ => fallback,
  };

  Future<void> _readSavedAnalysis() async {
    if (_disposed ||
        readingAnalysis ||
        analysis != null ||
        !hasFailedJobs ||
        run.status != 'completed') {
      return;
    }
    final version = _analysisVersion;
    readingAnalysis = true;
    notifyListeners();
    try {
      final saved = await _analyses.readSaved(repo, run);
      if (_disposed || version != _analysisVersion) return;
      analysis = saved;
      analysisWarning = '';
    } catch (failure) {
      if (_disposed || version != _analysisVersion) return;
      analysisWarning = _message(
        failure,
        'Chưa đọc được phân tích đã lưu. Kiểm tra kết nối và quyền Firestore; vẫn có thể phân tích mới.',
      );
    } finally {
      if (!_disposed && version == _analysisVersion) {
        readingAnalysis = false;
        notifyListeners();
      }
    }
  }

  Future<CiAnalysisInput?> prepareAnalysis() async {
    if (_disposed || !canAnalyze || analysis != null) return null;
    final version = ++_analysisVersion;
    preparingAnalysis = true;
    analysisError = '';
    preparedAnalysis = null;
    notifyListeners();
    try {
      final input = await _analyses.prepare(accessToken, repo, run);
      if (_disposed || version != _analysisVersion) return null;
      preparedAnalysis = input;
      return input;
    } catch (failure) {
      if (_disposed || version != _analysisVersion) return null;
      analysisError = _message(failure, 'Chưa chuẩn bị được log để phân tích.');
      return null;
    } finally {
      if (!_disposed && version == _analysisVersion) {
        preparingAnalysis = false;
        notifyListeners();
      }
    }
  }

  void cancelAnalysisPreview() {
    preparedAnalysis = null;
  }

  Future<void> analyze() async {
    final input = preparedAnalysis;
    if (_disposed || input == null || analyzing || !canAnalyze) return;
    if (input.run.id != run.id ||
        input.run.attempt != run.attempt ||
        input.run.sha != run.sha) {
      return;
    }
    final version = ++_analysisVersion;
    analyzing = true;
    analysisError = '';
    notifyListeners();
    try {
      final result = await _analyses.analyze(input);
      if (_disposed || version != _analysisVersion) return;
      if (!result.matches(repo, run)) {
        throw const CiAnalysisException(
          'Kết quả không thuộc lần thực thi đang xem.',
        );
      }
      analysis = result;
      analysisWarning = '';
      preparedAnalysis = null;
      notifyListeners();
      try {
        await _analyses.save(result);
      } catch (failure) {
        if (!_disposed && version == _analysisVersion) {
          analysisWarning =
              'Đã phân tích nhưng chưa lưu được vào Firestore. ${_message(failure, 'Kết quả đang được giữ trên màn hình này.')}';
        }
      }
    } catch (failure) {
      if (_disposed || version != _analysisVersion) return;
      analysisError = _message(
        failure,
        'Chưa phân tích được log. Hãy thử lại.',
      );
    } finally {
      if (!_disposed && version == _analysisVersion) {
        analyzing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> rerun({required bool failedOnly}) async {
    if (_disposed || !canRerun) return false;
    actionBusy = true;
    actionError = '';
    actionMessage = '';
    var accepted = false;
    notifyListeners();
    try {
      await _repository.rerun(accessToken, repo, run, failedOnly: failedOnly);
      if (_disposed) return false;
      accepted = true;
      waitingForRerun = true;
      actionMessage =
          'Đã gửi yêu cầu chạy lại trên commit ${run.sha}. Kéo xuống để theo dõi attempt mới.';
    } catch (failure) {
      if (_disposed) return false;
      actionError = _message(failure, 'Chưa gửi được yêu cầu chạy lại.');
      if (failure is GitHubException && failure.outcomeUnknown) {
        waitingForRerun = true;
      }
    } finally {
      if (!_disposed) {
        actionBusy = false;
        notifyListeners();
      }
    }
    if (accepted && !_disposed) await showLatestAttempt();
    return accepted;
  }

  Future<void> showLatestAttempt() async {
    if (_disposed || loading || actionBusy || analyzing || preparingAnalysis) {
      return;
    }
    loading = true;
    error = '';
    var changed = false;
    notifyListeners();
    try {
      final latest = await _repository.getLatestRun(accessToken, repo, run.id);
      if (_disposed) return;
      if (latest.attempt != run.attempt) {
        changed = true;
        run = latest;
        details = null;
        for (final id in _jobVersions.keys.toList()) {
          _jobVersions[id] = _jobVersions[id]! + 1;
        }
        logs.clear();
        logErrors.clear();
        loadingJobs.clear();
        _clearAnalysis();
        waitingForRerun = false;
        actionError = '';
        actionMessage = 'Đang xem attempt ${latest.attempt}.';
      }
    } catch (failure) {
      if (!_disposed) {
        error = _message(
          failure,
          'Chưa kiểm tra được attempt mới. Kéo xuống để thử lại.',
        );
      }
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
    if (changed && !_disposed) await load();
  }

  Future<void> loadPullRequests() async {
    if (_disposed ||
        analysis == null ||
        loadingPullRequests ||
        postingComment) {
      return;
    }
    final version = _analysisVersion;
    loadingPullRequests = true;
    commentError = '';
    notifyListeners();
    try {
      final result = await _repository.getPullRequests(accessToken, repo, run);
      if (_disposed || version != _analysisVersion) return;
      pullRequests = result;
      final current = selectedPullRequest;
      if (current != null &&
          !result.any(
            (item) =>
                item.number == current.number &&
                item.headSha == current.headSha,
          )) {
        selectedPullRequest = null;
      }
      if (selectedPullRequest == null && result.length == 1) {
        selectedPullRequest = result.single;
      }
    } catch (failure) {
      if (!_disposed && version == _analysisVersion) {
        commentError = _message(failure, 'Chưa tìm được PR liên quan.');
      }
    } finally {
      if (!_disposed && version == _analysisVersion) {
        loadingPullRequests = false;
        hasLoadedPullRequests = true;
        notifyListeners();
      }
    }
  }

  void selectPullRequest(GitHubPullRequest pull) {
    if (postingComment) return;
    selectedPullRequest = pull;
    commentError = '';
    notifyListeners();
  }

  Future<void> postComment(String body) async {
    final pull = selectedPullRequest;
    final saved = analysis;
    if (_disposed ||
        pull == null ||
        saved == null ||
        postingComment ||
        !saved.matches(repo, run)) {
      return;
    }
    if (postedComments.containsKey(pull.number)) return;
    postingComment = true;
    commentError = '';
    final version = _analysisVersion;
    notifyListeners();
    try {
      GitHubComment? comment;
      if (uncertainComments.contains(pull.number)) {
        comment = await _repository.findAnalysisComment(
          accessToken,
          repo,
          pull.number,
          saved.documentId,
        );
        if (comment == null) {
          throw const GitHubException(
            'Chưa tìm thấy comment đã gửi. Kiểm tra trên GitHub trước khi gửi lại; app chưa gửi thêm comment.',
          );
        }
      } else {
        comment = await _repository.postAnalysisComment(
          accessToken,
          repo,
          run,
          pull,
          saved.documentId,
          body,
        );
      }
      if (_disposed || version != _analysisVersion) return;
      postedComments[pull.number] = comment;
      uncertainComments.remove(pull.number);
    } catch (failure) {
      if (_disposed || version != _analysisVersion) return;
      commentError = _message(
        failure,
        'Chưa gửi được comment. Bản nháp được giữ lại.',
      );
      if (failure is GitHubException && failure.outcomeUnknown) {
        uncertainComments.add(pull.number);
      }
    } finally {
      if (!_disposed && version == _analysisVersion) {
        postingComment = false;
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
