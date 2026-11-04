import '../models/project.dart';
import '../models/workflow_run.dart';
import '../services/github_service.dart';

class GitHubActionsRepository {
  final GitHubService _github = GitHubService();
  DateTime? _retryAt;
  bool _requiresSignIn = false;

  void _checkConnection() {
    if (_requiresSignIn) {
      throw const GitHubException(
        'Phiên GitHub không còn hợp lệ. Hãy đăng xuất rồi đăng nhập lại.',
        requiresSignIn: true,
      );
    }
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
      throw GitHubException(
        'GitHub đang giới hạn yêu cầu. Hãy chờ một lúc rồi thử lại.',
        retryAt: _retryAt,
      );
    }
  }

  Future<WorkflowRunsPage> getRuns(
    String? token,
    ProjectRepo repo, {
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    try {
      _checkConnection();
      final response = await _github.fetchWorkflowRuns(
        token ?? '',
        repo.fullName,
        page: page,
        perPage: perPage,
        status: status,
      );
      final runs = (response.data['workflow_runs'] as List<dynamic>)
          .map((item) => WorkflowRun.fromJson(item as Map<String, dynamic>))
          .toList();
      return WorkflowRunsPage(runs: runs, hasMore: response.hasMore);
    } on GitHubException catch (error) {
      _retryAt = error.retryAt ?? _retryAt;
      _requiresSignIn = _requiresSignIn || error.requiresSignIn;
      rethrow;
    } on TypeError {
      throw const GitHubException(
        'GitHub trả về dữ liệu lần chạy chưa hợp lệ. Hãy thử lại.',
      );
    }
  }

  Future<WorkflowRunDetails> getRunDetails(
    String? token,
    ProjectRepo repo,
    WorkflowRun selectedRun,
  ) async {
    try {
      _checkConnection();
      final response = await _github.fetchRunAttempt(
        token ?? '',
        repo.fullName,
        selectedRun.id,
        selectedRun.attempt,
      );
      final run = WorkflowRun.fromJson(response.data);
      if (run.id != selectedRun.id || run.attempt != selectedRun.attempt) {
        throw const GitHubException(
          'GitHub trả về lần thực thi khác. Hãy tải lại lịch sử chạy.',
        );
      }
      final jobs = <int, WorkflowJob>{};
      var page = 1;
      while (true) {
        _checkConnection();
        final response = await _github.fetchWorkflowJobs(
          token ?? '',
          repo.fullName,
          run.id,
          run.attempt,
          page: page,
        );
        for (final item in response.data['jobs'] as List<dynamic>) {
          final data = item as Map<String, dynamic>;
          if (data['run_id'] != run.id ||
              (data['run_attempt'] != null &&
                  data['run_attempt'] != run.attempt)) {
            throw const GitHubException(
              'Job không thuộc lần thực thi đang xem. Hãy tải lại.',
            );
          }
          final job = WorkflowJob.fromJson(data);
          jobs[job.id] = job;
        }
        if (!response.hasMore) break;
        page++;
      }
      // Publish only after the header and every job page have succeeded.
      return WorkflowRunDetails(run: run, jobs: jobs.values.toList());
    } on GitHubException catch (error) {
      _retryAt = error.retryAt ?? _retryAt;
      _requiresSignIn = _requiresSignIn || error.requiresSignIn;
      rethrow;
    } on TypeError {
      throw const GitHubException(
        'GitHub trả về dữ liệu job/step chưa hợp lệ. Hãy thử lại.',
      );
    }
  }

  Future<WorkflowLog> getJobLog(
    String? token,
    ProjectRepo repo,
    int jobId,
  ) async {
    try {
      _checkConnection();
      return await _github.fetchJobLog(token ?? '', repo.fullName, jobId);
    } on GitHubException catch (error) {
      _retryAt = error.retryAt ?? _retryAt;
      _requiresSignIn = _requiresSignIn || error.requiresSignIn;
      rethrow;
    }
  }

  Future<T> _withConnection<T>(Future<T> Function() request) async {
    try {
      _checkConnection();
      return await request();
    } on GitHubException catch (error) {
      _retryAt = error.retryAt ?? _retryAt;
      _requiresSignIn = _requiresSignIn || error.requiresSignIn;
      rethrow;
    } on TypeError {
      throw const GitHubException(
        'GitHub trả về dữ liệu chưa hợp lệ. Kiểm tra lại trên GitHub.',
      );
    }
  }

  Future<WorkflowLog> getAnalysisLog(
    String? token,
    ProjectRepo repo,
    int jobId,
  ) => _withConnection(
    () => _github.fetchJobLog(
      token ?? '',
      repo.fullName,
      jobId,
      forAnalysis: true,
    ),
  );

  Future<WorkflowRun> getLatestRun(
    String? token,
    ProjectRepo repo,
    int runId,
  ) => _withConnection(() async {
    final response = await _github.fetchLatestRun(
      token ?? '',
      repo.fullName,
      runId,
    );
    final run = WorkflowRun.fromJson(response.data);
    if (run.id != runId) {
      throw const GitHubException(
        'GitHub trả về run khác. Hãy mở lại lịch sử.',
      );
    }
    return run;
  });

  Future<void> rerun(
    String? token,
    ProjectRepo repo,
    WorkflowRun selected, {
    required bool failedOnly,
  }) => _withConnection(() async {
    final latest = await getLatestRun(token, repo, selected.id);
    if (latest.attempt != selected.attempt || latest.sha != selected.sha) {
      throw const GitHubException(
        'Run đã có attempt khác. Chọn “Xem attempt mới nhất” trước khi chạy lại.',
      );
    }
    if (latest.status != 'completed') {
      throw const GitHubException(
        'CI chưa hoàn tất. Không gửi thêm yêu cầu chạy lại.',
      );
    }
    if (failedOnly && !['failure', 'timed_out'].contains(latest.conclusion)) {
      throw const GitHubException(
        'Lần chạy hiện tại không có kết quả lỗi để chạy lại.',
      );
    }
    await _github.rerunWorkflow(
      token ?? '',
      repo.fullName,
      selected.id,
      failedOnly: failedOnly,
    );
  });

  Future<List<GitHubPullRequest>> getPullRequests(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
  ) => _withConnection(() async {
    final response = await _github.fetchLatestRun(
      token ?? '',
      repo.fullName,
      run.id,
    );
    final latest = WorkflowRun.fromJson(response.data);
    if (latest.id != run.id || latest.sha != run.sha) {
      throw const GitHubException(
        'Commit của run không còn khớp. Hãy mở lại lịch sử.',
      );
    }
    final numbers = <int>{
      for (final item in response.data['pull_requests'] as List<dynamic>? ?? [])
        (item as Map<String, dynamic>)['number'] as int,
    };
    if (numbers.isEmpty) {
      if (!RegExp(r'^[a-fA-F0-9]{7,64}$').hasMatch(run.sha)) {
        throw const GitHubException('Commit SHA chưa hợp lệ để tìm PR.');
      }
      var page = 1;
      while (true) {
        final pageResult = await _github.fetchCommitPullRequests(
          token ?? '',
          repo.fullName,
          run.sha,
          page: page,
        );
        for (final item in pageResult.data['items'] as List<dynamic>) {
          numbers.add((item as Map<String, dynamic>)['number'] as int);
        }
        if (!pageResult.hasMore) break;
        if (++page > 5) {
          throw const GitHubException(
            'Có quá nhiều PR liên quan. Hãy kiểm tra trên GitHub.',
          );
        }
      }
    }
    final pulls = <GitHubPullRequest>[];
    for (final number in numbers) {
      final result = await _github.fetchPullRequest(
        token ?? '',
        repo.fullName,
        number,
      );
      final pull = GitHubPullRequest.fromJson(result.data);
      if (pull.number != number) {
        throw const GitHubException('GitHub trả về PR không khớp.');
      }
      if (result.data['state'] == 'open') pulls.add(pull);
    }
    return pulls;
  });

  String _commentMarker(String analysisId) => '<!-- vista-ci:$analysisId -->';

  GitHubComment _comment(
    Map<String, dynamic> data,
    ProjectRepo repo,
    int number,
  ) {
    final url = Uri.parse(data['html_url'] as String);
    final expected = [
      '/${repo.fullName}/pull/$number',
      '/${repo.fullName}/issues/$number',
    ];
    if (url.scheme != 'https' ||
        url.host != 'github.com' ||
        !expected.contains(url.path) ||
        url.userInfo.isNotEmpty) {
      throw const GitHubException(
        'Đường dẫn comment GitHub chưa hợp lệ.',
        outcomeUnknown: true,
      );
    }
    return GitHubComment(id: data['id'] as int, url: url);
  }

  Future<GitHubComment?> findAnalysisComment(
    String? token,
    ProjectRepo repo,
    int number,
    String analysisId,
  ) => _withConnection(() async {
    var page = 1;
    while (true) {
      final response = await _github.fetchComments(
        token ?? '',
        repo.fullName,
        number,
        page: page,
      );
      for (final raw in response.data['items'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        if ((item['body'] as String? ?? '').contains(
          _commentMarker(analysisId),
        )) {
          return _comment(item, repo, number);
        }
      }
      if (!response.hasMore) return null;
      if (++page > 5) {
        throw const GitHubException(
          'PR có nhiều comment. Chưa kiểm tra hết bản đã gửi; hãy mở GitHub.',
        );
      }
    }
  });

  Future<GitHubComment> postAnalysisComment(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
    GitHubPullRequest selected,
    String analysisId,
    String body,
  ) => _withConnection(() async {
    if (body.trim().isEmpty || body.length > 30000) {
      throw const GitHubException(
        'Comment cần có nội dung và tối đa 30.000 ký tự.',
      );
    }
    final candidates = await getPullRequests(token, repo, run);
    final matches = candidates.where((pull) => pull.number == selected.number);
    if (matches.isEmpty || matches.first.headSha != selected.headSha) {
      throw const GitHubException(
        'PR đã thay đổi hoặc không còn mở/liên quan đến run. Hãy chọn lại PR và kiểm tra bản nháp.',
      );
    }
    final existing = await findAnalysisComment(
      token,
      repo,
      selected.number,
      analysisId,
    );
    if (existing != null) return existing;
    final response = await _github.createComment(
      token ?? '',
      repo.fullName,
      selected.number,
      '$body\n\n${_commentMarker(analysisId)}',
    );
    try {
      return _comment(response.data, repo, selected.number);
    } catch (_) {
      throw const GitHubException(
        'Comment có thể đã được gửi nhưng phản hồi chưa hợp lệ. Kiểm tra comment trước khi gửi lại.',
        outcomeUnknown: true,
      );
    }
  });
}
