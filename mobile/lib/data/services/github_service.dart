import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/github_repo.dart';

class GitHubException implements Exception {
  const GitHubException(this.message, {this.requiresSignIn = false});
  final String message;
  final bool requiresSignIn;
}

class GitHubService {
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
