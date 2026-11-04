import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/github_repo.dart';
import '../models/workflow_run.dart';

class GitHubException implements Exception {
  const GitHubException(
    this.message, {
    this.requiresSignIn = false,
    this.accessDenied = false,
    this.retryAt,
    this.outcomeUnknown = false,
  });
  final String message;
  final bool requiresSignIn;
  final bool accessDenied;
  final DateTime? retryAt;
  final bool outcomeUnknown;
}

/// Raw GitHub data and its pagination signal. Repository creates app models.
class GitHubResponse {
  const GitHubResponse(this.data, {required this.hasMore});
  final Map<String, dynamic> data;
  final bool hasMore;
}

class GitHubService {
  Future<GitHubResponse> fetchWorkflowRuns(
    String accessToken,
    String fullName, {
    int page = 1,
    int perPage = 20,
    String? status,
  }) => _fetchActions(
    accessToken,
    fullName,
    'runs',
    page: page,
    perPage: perPage,
    status: status,
  );

  Future<GitHubResponse> fetchRunAttempt(
    String accessToken,
    String fullName,
    int runId,
    int attempt,
  ) => _fetchActions(accessToken, fullName, 'runs/$runId/attempts/$attempt');

  Future<GitHubResponse> fetchWorkflowJobs(
    String accessToken,
    String fullName,
    int runId,
    int attempt, {
    int page = 1,
  }) => _fetchActions(
    accessToken,
    fullName,
    'runs/$runId/attempts/$attempt/jobs',
    page: page,
    perPage: 100,
  );

  Future<GitHubResponse> fetchLatestRun(String token, String repo, int runId) =>
      _fetchActions(token, repo, 'runs/$runId');

  Future<GitHubResponse> fetchPullRequest(
    String token,
    String repo,
    int number,
  ) => _request(token, repo, 'pulls/$number');

  Future<GitHubResponse> fetchCommitPullRequests(
    String token,
    String repo,
    String sha, {
    int page = 1,
  }) => _request(
    token,
    repo,
    'commits/$sha/pulls',
    query: {'page': '$page', 'per_page': '100'},
  );

  Future<GitHubResponse> fetchComments(
    String token,
    String repo,
    int number, {
    int page = 1,
  }) => _request(
    token,
    repo,
    'issues/$number/comments',
    query: {'page': '$page', 'per_page': '100'},
  );

  Future<void> rerunWorkflow(
    String token,
    String repo,
    int runId, {
    required bool failedOnly,
  }) async {
    await _request(
      token,
      repo,
      'actions/runs/$runId/${failedOnly ? 'rerun-failed-jobs' : 'rerun'}',
      method: 'POST',
    );
  }

  Future<GitHubResponse> createComment(
    String token,
    String repo,
    int number,
    String body,
  ) => _request(
    token,
    repo,
    'issues/$number/comments',
    method: 'POST',
    body: {'body': body},
  );

  Future<GitHubResponse> _fetchActions(
    String accessToken,
    String fullName,
    String path, {
    int page = 1,
    int perPage = 20,
    String? status,
  }) => _request(
    accessToken,
    fullName,
    'actions/$path',
    query: path == 'runs' || path.endsWith('/jobs')
        ? {
            'page': '$page',
            'per_page': '$perPage',
            'status': ?status,
          }
        : null,
  );

  Future<GitHubResponse> _request(
    String accessToken,
    String fullName,
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (accessToken.isEmpty) {
      throw const GitHubException(
        'Chưa có phiên GitHub. Hãy đăng xuất rồi đăng nhập lại để xem Actions.',
        requiresSignIn: true,
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(fullName) ||
        path.contains('..') ||
        (query != null &&
            ((int.tryParse(query['page'] ?? '1') ?? 0) < 1 ||
                (int.tryParse(query['per_page'] ?? '20') ?? 0) < 1 ||
                (int.tryParse(query['per_page'] ?? '20') ?? 0) > 100))) {
      throw const GitHubException(
        'Thông tin repository hoặc trang chưa hợp lệ. Hãy đồng bộ lại project.',
      );
    }
    final client = http.Client();
    try {
      final url = Uri.https('api.github.com', '/repos/$fullName/$path', query);
      final request = http.Request(method, url)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2026-03-10',
        });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (method == 'POST' && response.statusCode >= 500) {
        throw const GitHubException(
          'Chưa xác định GitHub đã nhận thao tác hay chưa. Kiểm tra trên GitHub trước khi gửi lại.',
          outcomeUnknown: true,
        );
      }
      if (!(method == 'POST' && response.statusCode == 201)) {
        _checkActionsStatus(response.statusCode, response.headers);
      }
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
      return GitHubResponse(
        decoded is List ? {'items': decoded} : decoded as Map<String, dynamic>,
        hasMore: (response.headers['link'] ?? '').contains('rel="next"'),
      );
    } on TimeoutException {
      throw GitHubException(
        method == 'POST'
            ? 'Hết thời gian chờ. Thao tác có thể đã được gửi; kiểm tra trên GitHub trước khi gửi lại.'
            : 'GitHub phản hồi quá lâu. Hãy kiểm tra mạng rồi thử lại.',
        outcomeUnknown: method == 'POST',
      );
    } on http.ClientException {
      throw GitHubException(
        method == 'POST'
            ? 'Mất kết nối khi gửi thao tác. Kiểm tra kết quả trên GitHub trước khi gửi lại.'
            : 'Không kết nối được GitHub. Hãy kiểm tra mạng rồi thử lại.',
        outcomeUnknown: method == 'POST',
      );
    } on FormatException {
      throw GitHubException(
        'GitHub trả về dữ liệu chưa hợp lệ. Kiểm tra kết quả trên GitHub.',
        outcomeUnknown: method == 'POST',
      );
    } on TypeError {
      throw GitHubException(
        'GitHub trả về dữ liệu chưa hợp lệ. Kiểm tra kết quả trên GitHub.',
        outcomeUnknown: method == 'POST',
      );
    } finally {
      client.close();
    }
  }

  Future<WorkflowLog> fetchJobLog(
    String accessToken,
    String fullName,
    int jobId, {
    bool forAnalysis = false,
  }) async {
    if (accessToken.isEmpty) {
      throw const GitHubException(
        'Chưa có phiên GitHub. Hãy đăng xuất rồi đăng nhập lại.',
        requiresSignIn: true,
      );
    }
    if (jobId <= 0 ||
        !RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(fullName)) {
      throw const GitHubException('Thông tin job chưa hợp lệ.');
    }
    final client = http.Client();
    try {
      return await _downloadJobLog(
        client,
        accessToken,
        fullName,
        jobId,
        forAnalysis: forAnalysis,
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const GitHubException('Tải log quá lâu. Kéo xuống để thử lại.');
    } on http.ClientException {
      throw const GitHubException(
        'Không kết nối được nguồn log. Kiểm tra mạng và kéo xuống để thử lại.',
      );
    } on FormatException {
      throw const GitHubException('GitHub trả về đường dẫn log chưa hợp lệ.');
    } finally {
      client.close();
    }
  }

  Future<WorkflowLog> _downloadJobLog(
    http.Client client,
    String token,
    String fullName,
    int jobId, {
    bool forAnalysis = false,
  }) async {
    final request =
        http.Request(
            'GET',
            Uri.https(
              'api.github.com',
              '/repos/$fullName/actions/jobs/$jobId/logs',
            ),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2026-03-10',
          });
    var response = await client.send(request);
    if (response.statusCode == 404 || response.statusCode == 410) {
      throw const GitHubException(
        'Log chưa sẵn sàng hoặc đã hết hạn lưu trữ. Kéo xuống để thử lại.',
      );
    }
    _checkActionsStatus(
      response.statusCode,
      response.headers,
      allowRedirect: true,
    );
    if (response.statusCode == 302) {
      final location = Uri.tryParse(response.headers['location'] ?? '');
      if (location == null ||
          location.scheme != 'https' ||
          location.host.isEmpty ||
          location.userInfo.isNotEmpty ||
          location.port != 443) {
        throw const GitHubException('GitHub trả về đường dẫn log chưa hợp lệ.');
      }
      // The signed download URL receives no GitHub token, cookies or redirect-following.
      await response.stream.drain<void>();
      final download = http.Request('GET', location)..followRedirects = false;
      response = await client.send(download);
      if (response.statusCode != 200) {
        throw const GitHubException(
          'Chưa tải được log từ nguồn GitHub. Liên kết có thể đã hết hạn; kéo xuống để lấy lại.',
        );
      }
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('application/zip') ||
        contentType.contains('application/json') ||
        contentType.contains('text/html')) {
      throw const GitHubException(
        'Nguồn log không trả về văn bản. Hãy mở run trên GitHub.',
      );
    }
    final maxBytes = forAnalysis ? 4 * 1024 * 1024 : 256 * 1024;
    final bytes = BytesBuilder(copy: false);
    var truncated = false;
    await for (final chunk in response.stream) {
      final remaining = maxBytes - bytes.length;
      if (chunk.length > remaining) {
        bytes.add(chunk.sublist(0, remaining));
        truncated = true;
        break;
      }
      bytes.add(chunk);
    }
    final text = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    return forAnalysis
        ? WorkflowLog(text: WorkflowLog.cleanText(text), truncated: truncated)
        : WorkflowLog.fromText(text, truncated: truncated);
  }

  void _checkActionsStatus(
    int status,
    Map<String, String> headers, {
    bool allowRedirect = false,
  }) {
    if (status == 200 || (allowRedirect && status == 302)) return;
    if (status == 401) {
      throw const GitHubException(
        'Phiên GitHub không còn hợp lệ. Hãy đăng xuất rồi đăng nhập lại.',
        requiresSignIn: true,
      );
    }
    if (status == 429 ||
        (status == 403 &&
            (headers['x-ratelimit-remaining'] == '0' ||
                headers.containsKey('retry-after')))) {
      final delay = int.tryParse(headers['retry-after'] ?? '');
      final reset = int.tryParse(headers['x-ratelimit-reset'] ?? '');
      throw GitHubException(
        'GitHub đang giới hạn yêu cầu. Hãy chờ một lúc rồi thử lại.',
        retryAt: delay != null
            ? DateTime.now().add(Duration(seconds: delay))
            : reset != null
            ? DateTime.fromMillisecondsSinceEpoch(reset * 1000)
            : DateTime.now().add(const Duration(minutes: 1)),
      );
    }
    if (status == 403) {
      throw const GitHubException(
        'Chưa có quyền thực hiện thao tác. Kiểm tra quyền repository và organization/SSO trên GitHub.',
        accessDenied: true,
      );
    }
    if ([301, 302, 307, 308, 404].contains(status)) {
      throw const GitHubException(
        'Không truy cập được repository hoặc lần chạy. Repo có thể đã đổi tên, bị xóa hoặc bạn không còn quyền truy cập.',
        accessDenied: true,
      );
    }
    if (status == 422 || status == 409) {
      throw const GitHubException(
        'GitHub từ chối thao tác. Run có thể đang chạy, đã hết hạn chạy lại hoặc dữ liệu gửi chưa hợp lệ.',
      );
    }
    if (status != 200) {
      throw const GitHubException('Chưa tải được GitHub Actions. Hãy thử lại.');
    }
  }

  Future<List<GitHubRepo>> fetchRepositories(String accessToken) async {
    final client = http.Client();
    final repositories = <int, GitHubRepo>{};
    var page = 1;
    try {
      while (true) {
        final url = Uri.https('api.github.com', '/user/repos', {
          'visibility': 'all',
          'affiliation': 'owner,collaborator,organization_member',
          'sort': 'full_name',
          'direction': 'asc',
          'per_page': '100',
          'page': '$page',
        });
        final response = await client
            .get(
              url,
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2026-03-10',
              },
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 401) {
          throw const GitHubException(
            'Phiên GitHub không còn hợp lệ. Hãy đăng xuất rồi đăng nhập lại.',
            requiresSignIn: true,
          );
        }
        if (response.statusCode == 429 ||
            (response.statusCode == 403 &&
                (response.headers['x-ratelimit-remaining'] == '0' ||
                    response.headers.containsKey('retry-after')))) {
          throw const GitHubException(
            'GitHub đang giới hạn yêu cầu. Hãy chờ một lúc rồi đồng bộ lại.',
          );
        }
        if (response.statusCode == 403) {
          throw const GitHubException(
            'GitHub từ chối truy cập. Kiểm tra quyền ứng dụng và quyền organization trên GitHub.',
          );
        }
        if (response.statusCode != 200) {
          throw const GitHubException(
            'Chưa lấy được repo từ GitHub. Hãy thử đồng bộ lại.',
          );
        }

        final data = jsonDecode(response.body) as List<dynamic>;
        for (final item in data) {
          final repo = GitHubRepo.fromJson(item as Map<String, dynamic>);
          repositories[repo.id] = repo;
        }
        // Follow GitHub's pagination signal, but always construct our own URL.
        // Never send the token to a URL supplied in a response header.
        if (!(response.headers['link'] ?? '').contains('rel="next"')) break;
        page++;
      }
      return repositories.values.toList();
    } on TimeoutException {
      throw const GitHubException(
        'GitHub phản hồi quá lâu. Hãy kiểm tra mạng rồi thử lại.',
      );
    } on http.ClientException {
      throw const GitHubException(
        'Không kết nối được GitHub. Hãy kiểm tra mạng rồi thử lại.',
      );
    } finally {
      client.close();
    }
  }
}
