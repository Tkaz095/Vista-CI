import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vista_mobile/data/services/github_service.dart';

Map<String, dynamic> repoJson(int id, {bool private = false}) => {
  'id': id,
  'full_name': 'team/repo-$id',
  'private': private,
  'description': null,
  'language': null,
  'default_branch': 'main',
};

void main() {
  test('Fetches every page with provider token, includes private and deduplicates IDs', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        final repos = await GitHubService().fetchRepositories(
          'fake-github-token',
        );
        expect(repos.map((repo) => repo.id), [1, 2]);
        expect(repos.last.isPrivate, isTrue);
        expect(repos.first.description, '');
        expect(calls, 2);
      },
      () => MockClient((request) async {
        calls++;
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, '/user/repos');
        expect(request.url.queryParameters['visibility'], 'all');
        expect(
          request.url.queryParameters['affiliation'],
          'owner,collaborator,organization_member',
        );
        expect(request.url.queryParameters['type'], isNull);
        expect(request.url.queryParameters['page'], '$calls');
        expect(request.headers['Authorization'], 'Bearer fake-github-token');
        if (calls == 1) {
          return http.Response(
            jsonEncode([repoJson(1)]),
            200,
            headers: {
              'link':
                  '<https://untrusted.example/user/repos?page=2>; rel="next"',
            },
          );
        }
        return http.Response(
          jsonEncode([repoJson(1), repoJson(2, private: true)]),
          200,
        );
      }),
    );
  });

  test('Page failure cannot return a partial successful sync', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          GitHubService().fetchRepositories('fake'),
          throwsA(isA<GitHubException>()),
        );
      },
      () => MockClient(
        (request) async => request.url.queryParameters['page'] == '1'
            ? http.Response(
                jsonEncode([repoJson(1)]),
                200,
                headers: {'link': '<next>; rel="next"'},
              )
            : http.Response('{"message":"Unavailable"}', 503),
      ),
    );
  });

  for (final status in [401, 403, 429, 500]) {
    test(
      'Maps HTTP $status to a readable error and requests sign-in only for 401',
      () async {
        await http.runWithClient(() async {
          await expectLater(
            GitHubService().fetchRepositories('fake'),
            throwsA(
              isA<GitHubException>()
                  .having((e) => e.message, 'message', isNotEmpty)
                  .having(
                    (e) => e.requiresSignIn,
                    'requiresSignIn',
                    status == 401,
                  ),
            ),
          );
        }, () => MockClient((_) async => http.Response('{}', status)));
      },
    );
  }

  test('Recognizes exhausted rate limit and connection failures', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          GitHubService().fetchRepositories('fake'),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.message,
              'message',
              contains('giới hạn'),
            ),
          ),
        );
      },
      () => MockClient(
        (_) async =>
            http.Response('{}', 403, headers: {'x-ratelimit-remaining': '0'}),
      ),
    );
    await http.runWithClient(
      () async {
        await expectLater(
          GitHubService().fetchRepositories('fake'),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.message,
              'message',
              contains('kiểm tra mạng'),
            ),
          ),
        );
      },
      () => MockClient(
        (_) async => throw http.ClientException('Connection lost'),
      ),
    );
    await http.runWithClient(() async {
      await expectLater(
        GitHubService().fetchRepositories('fake'),
        throwsA(isA<GitHubException>()),
      );
    }, () => MockClient((_) async => throw TimeoutException('Timed out')));
  });
}
