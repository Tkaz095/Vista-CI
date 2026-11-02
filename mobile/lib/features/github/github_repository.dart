import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/backend_client.dart';

class GitHubRepo {
  const GitHubRepo(
    this.id,
    this.fullName,
    this.htmlUrl,
    this.defaultBranch,
    this.isPrivate,
  );
  final String id, fullName, htmlUrl, defaultBranch;
  final bool isPrivate;
}

class GitHubRepository {
  GitHubRepository._();
  static final instance = GitHubRepository._();
  int _connectionGeneration = 0;
  bool connecting = false;
  void clear() {
    _connectionGeneration++;
    connecting = false;
  }

  void cancelConnection() => clear();
  Future<Map<String, dynamic>> connectionInfo() =>
      BackendClient.json('/api/github-session', query: {'action': 'info'});
  Future<Map<String, dynamic>> refreshConnection() async {
    await BackendClient.json(
      '/api/github-session',
      query: {'action': 'status'},
    );
    return connectionInfo();
  }

  Future<String> disconnect() async {
    clear();
    final result = await BackendClient.json(
      '/api/github-session',
      query: {'action': 'disconnect'},
      post: true,
    );
    return '${result['message'] ?? 'Đã ngắt kết nối.'}';
  }

  Future<void> connect(bool includePrivate) async {
    if (includePrivate) {
      throw BackendException(
        'PUBLIC_ONLY',
        'Repo private chưa thuộc phạm vi hiện tại.',
      );
    }
    if (connecting) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final generation = ++_connectionGeneration;
    connecting = true;
    try {
      final request = await BackendClient.json(
        '/api/github-session',
        query: {'action': 'mobile-start'},
        post: true,
      );
      if (generation != _connectionGeneration ||
          uid != FirebaseAuth.instance.currentUser?.uid) {
        throw BackendException('CONNECTION_CANCELLED', 'Đã dừng chờ kết nối.');
      }
      final uri = Uri.parse('${request['openUrl']}');
      final base = BackendClient.validateOrigin(await BackendClient.origin());
      if (uri.origin != base.origin ||
          uri.path != '/api/github-session' ||
          uri.queryParameters['action'] != 'mobile-open') {
        throw BackendException(
          'INVALID_RESPONSE',
          'Địa chỉ kết nối backend không hợp lệ.',
        );
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw BackendException(
          'BROWSER_UNAVAILABLE',
          'Không mở được trình duyệt để kết nối GitHub.',
        );
      }
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      while (DateTime.now().isBefore(deadline)) {
        if (generation != _connectionGeneration ||
            uid != FirebaseAuth.instance.currentUser?.uid) {
          throw BackendException(
            'CONNECTION_CANCELLED',
            'Đã dừng chờ kết nối. Nếu đã cấp quyền trên trình duyệt, có thể tải lại dữ liệu.',
          );
        }
        Map<String, dynamic> result;
        try {
          result = await BackendClient.json(
            '/api/github-session',
            query: {
              'action': 'mobile-result',
              'request': '${request['requestId']}',
            },
          );
        } on BackendException catch (error) {
          if (error.code == 'REQUEST_NOT_FOUND') {
            final info = await connectionInfo();
            if (info['connected'] == true &&
                info['updatedAt'] is num &&
                request['createdAt'] is num &&
                info['updatedAt'] >= request['createdAt']) {
              return;
            }
          }
          rethrow;
        }
        if (generation != _connectionGeneration ||
            uid != FirebaseAuth.instance.currentUser?.uid) {
          throw BackendException(
            'CONNECTION_CANCELLED',
            'Đã dừng chờ kết nối.',
          );
        }
        if (result['status'] == 'success') return;
        if (result['status'] == 'error') {
          throw BackendException(
            'CONNECTION_FAILED',
            '${result['message'] ?? 'Kết nối GitHub thất bại.'}',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      throw BackendException(
        'CONNECTION_TIMEOUT',
        'Phiên kết nối hết thời gian. Thử lại.',
      );
    } finally {
      if (generation == _connectionGeneration) connecting = false;
    }
  }

  Future<Map<String, dynamic>> _data(Map<String, String> query) =>
      BackendClient.json('/api/github-data', query: query);
  Future<({List<GitHubRepo> repos, bool more})> page(int page) async {
    final result = await _data({'kind': 'repos', 'page': '$page'});
    final dynamic rows = result['data'];
    if (rows is! List) {
      throw BackendException('INVALID_RESPONSE', 'Dữ liệu repo không hợp lệ.');
    }
    final repos = <GitHubRepo>[];
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! int ||
          row['full_name'] is! String ||
          row['default_branch'] is! String ||
          row['private'] != false) {
        continue;
      }
      repos.add(
        GitHubRepo(
          '${row['id']}',
          row['full_name'],
          'https://github.com/${row['full_name']}',
          row['default_branch'],
          false,
        ),
      );
    }
    return (repos: repos, more: result['more'] == true);
  }

  Future<({List<WorkflowRun> runs, bool more})> runs(
    String repo,
    int page,
    String branch,
    String status,
  ) async {
    final result = await _data({
      'kind': 'runs',
      'repo': repo,
      'page': '$page',
      'branch': branch.trim(),
      'status': status,
    });
    final dynamic data = result['data'];
    if (data is! Map || data['workflow_runs'] is! List) {
      throw BackendException('INVALID_RESPONSE', 'Dữ liệu CI/CD không hợp lệ.');
    }
    final runs = <WorkflowRun>[];
    for (final row in data['workflow_runs']) {
      if (row is! Map || row['id'] is! int || row['created_at'] is! String) {
        continue;
      }
      final created = DateTime.tryParse(row['created_at']);
      if (created == null) continue;
      runs.add(
        WorkflowRun(
          id: row['id'],
          repo: repo,
          title: '${row['display_title'] ?? row['name'] ?? 'Workflow'}',
          workflow: '${row['name'] ?? 'Workflow'}',
          branch: '${row['head_branch'] ?? '—'}',
          sha: '${row['head_sha'] ?? ''}',
          actor: row['actor'] is Map ? '${row['actor']['login'] ?? '—'}' : '—',
          status: '${row['status'] ?? 'unknown'}',
          conclusion: row['conclusion'] is String ? row['conclusion'] : null,
          created: created,
          attempt: row['run_attempt'] is int ? row['run_attempt'] : 1,
        ),
      );
    }
    return (runs: runs, more: result['more'] == true);
  }

  Future<({List<WorkflowJob> jobs, bool more})> jobs(
    WorkflowRun run,
    int page,
  ) async {
    final result = await _data({
      'kind': 'jobs',
      'repo': run.repo,
      'run': '${run.id}',
      'attempt': '${run.attempt}',
      'page': '$page',
    });
    final dynamic data = result['data'];
    if (data is! Map || data['jobs'] is! List) {
      throw BackendException('INVALID_RESPONSE', 'Dữ liệu job không hợp lệ.');
    }
    final jobs = <WorkflowJob>[];
    for (final row in data['jobs']) {
      if (row is! Map || row['id'] is! int) continue;
      jobs.add(
        WorkflowJob(
          row['id'],
          '${row['name'] ?? 'Job'}',
          '${row['status'] ?? 'unknown'}',
          row['conclusion'] is String ? row['conclusion'] : null,
          row['steps'] is List
              ? [
                  for (final step in row['steps'])
                    if (step is Map && step['number'] is int)
                      WorkflowStep(
                        step['number'],
                        '${step['name'] ?? 'Step'}',
                        '${step['status'] ?? 'unknown'}',
                        step['conclusion'] is String
                            ? step['conclusion']
                            : null,
                      ),
                ]
              : [],
        ),
      );
    }
    return (jobs: jobs, more: result['more'] == true);
  }

  Future<({String text, bool truncated})> log(String repo, int job) async {
    final result = await BackendClient.request(
      '/api/github-job-log',
      query: {'repo': repo, 'job': '$job'},
    );
    if (!(result.headers['content-type']?.startsWith('text/plain') ?? false)) {
      throw BackendException(
        'BACKEND_SETUP',
        'Backend chưa phục vụ log dạng text.',
      );
    }
    return (
      text: result.body,
      truncated: result.headers['x-vista-truncated'] == 'true',
    );
  }
}

class WorkflowJob {
  WorkflowJob(this.id, this.name, this.status, this.conclusion, this.steps);
  final int id;
  final String name, status;
  final String? conclusion;
  final List<WorkflowStep> steps;
}

class WorkflowStep {
  WorkflowStep(this.number, this.name, this.status, this.conclusion);
  final int number;
  final String name, status;
  final String? conclusion;
}

class WorkflowRun {
  const WorkflowRun({
    required this.id,
    required this.repo,
    required this.title,
    required this.workflow,
    required this.branch,
    required this.sha,
    required this.actor,
    required this.status,
    required this.conclusion,
    required this.created,
    required this.attempt,
  });
  final int id, attempt;
  final String repo, title, workflow, branch, sha, actor, status;
  final String? conclusion;
  final DateTime created;
}
