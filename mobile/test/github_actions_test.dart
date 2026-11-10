import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vista_mobile/data/models/project.dart';
import 'package:vista_mobile/data/models/workflow_run.dart';
import 'package:vista_mobile/data/repositories/github_actions_repository.dart';
import 'package:vista_mobile/data/services/github_service.dart';
import 'package:vista_mobile/ui/projects/project_detail_view_model.dart';
import 'package:vista_mobile/ui/projects/projects_view.dart';
import 'package:vista_mobile/ui/projects/projects_view_model.dart';
import 'package:vista_mobile/ui/projects/repository_runs_view.dart';
import 'package:vista_mobile/ui/projects/repository_runs_view_model.dart';
import 'package:vista_mobile/ui/projects/workflow_run_detail_view.dart';
import 'package:vista_mobile/ui/projects/workflow_run_view_model.dart';
import 'package:vista_mobile/ui/theme/app_theme.dart';
import 'package:vista_mobile/ui/widgets/app_loading.dart';

import 'projects_test.dart' show FakeProjectRepository, testProject, savedRepo;

Map<String, dynamic> runJson(int id, {int attempt = 2}) => {
  'id': id,
  'name': 'CI',
  'display_title': 'Build mobile $id',
  'run_number': id,
  'run_attempt': attempt,
  'status': 'completed',
  'conclusion': 'failure',
  'head_branch': 'main',
  'head_sha': '1234567890abcdef',
  'event': 'push',
  'created_at': '2026-11-04T10:00:00Z',
};

Map<String, dynamic> jobJson(int id, {int attempt = 2}) => {
  'id': id,
  'run_id': 10,
  'run_attempt': attempt,
  'name': 'Build Android $id',
  'status': 'completed',
  'conclusion': 'failure',
  'started_at': '2026-11-04T10:00:00Z',
  'completed_at': '2026-11-04T10:02:30Z',
  'steps': [
    {
      'number': 1,
      'name': 'Checkout source',
      'status': 'completed',
      'conclusion': 'success',
    },
    {
      'number': 2,
      'name': 'Run Flutter tests',
      'status': 'completed',
      'conclusion': 'failure',
    },
  ],
};

http.Response runsResponse(List<int> ids, {bool more = false}) => http.Response(
  jsonEncode({'workflow_runs': ids.map((id) => runJson(id)).toList()}),
  200,
  headers: more
      ? {'link': '<https://untrusted.example/page=2>; rel="next"'}
      : {},
);

class FakeActionsRepository implements GitHubActionsRepository {
  final calls = <({int repoId, int page, int size, String? status})>[];
  final pending = <int, Completer<WorkflowRunsPage>>{};
  Map<int, WorkflowRunsPage> pages = {};
  Object? error;
  Completer<WorkflowRunDetails>? pendingDetails;
  WorkflowRunDetails details = WorkflowRunDetails(
    run: WorkflowRun.fromJson(runJson(10)),
    jobs: [WorkflowJob.fromJson(jobJson(1))],
  );
  int detailsCalls = 0;
  final pendingLogs = <int, Completer<WorkflowLog>>{};
  final logCalls = <int>[];
  Object? logError;
  int rerunCalls = 0;
  final rerunModes = <bool>[];
  int commentCalls = 0;
  WorkflowRun? latestRun;
  Object? writeError;
  final commentBodies = <String>[];
  List<GitHubPullRequest> relatedPulls = [
    const GitHubPullRequest(
      number: 7,
      title: 'Fix CI',
      headSha: '1234567890abcdef',
    ),
  ];
  GitHubComment? foundComment;

  @override
  Future<WorkflowRun> getRunAttempt(
    String? token,
    ProjectRepo repo,
    int runId,
    int attempt,
  ) async {
    if (error != null) throw error!;
    if (pendingDetails != null) return (await pendingDetails!.future).run;
    return details.run;
  }

  @override
  Future<WorkflowLog> getAnalysisLog(
    String? token,
    ProjectRepo repo,
    int jobId,
  ) => getJobLog(token, repo, jobId);
  @override
  Future<WorkflowRun> getLatestRun(
    String? token,
    ProjectRepo repo,
    int id,
  ) async => latestRun ?? details.run;
  @override
  Future<void> rerun(
    String? token,
    ProjectRepo repo,
    WorkflowRun run, {
    required bool failedOnly,
  }) async {
    rerunCalls++;
    rerunModes.add(failedOnly);
    if (writeError != null) throw writeError!;
  }

  @override
  Future<List<GitHubPullRequest>> getPullRequests(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
  ) async {
    if (error != null) throw error!;
    return relatedPulls;
  }

  @override
  Future<GitHubComment?> findAnalysisComment(
    String? token,
    ProjectRepo repo,
    int number,
    String id,
  ) async => foundComment;
  @override
  Future<GitHubComment> postAnalysisComment(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
    GitHubPullRequest pull,
    String id,
    String body,
  ) async {
    commentCalls++;
    commentBodies.add(body);
    if (writeError != null) throw writeError!;
    return GitHubComment(
      id: 20,
      url: Uri.parse(
        'https://github.com/${repo.fullName}/pull/${pull.number}#issuecomment-20',
      ),
    );
  }

  @override
  Future<WorkflowLog> getJobLog(
    String? token,
    ProjectRepo repo,
    int jobId,
  ) async {
    logCalls.add(jobId);
    if (pendingLogs[jobId] != null) return pendingLogs[jobId]!.future;
    if (logError != null) throw logError!;
    return const WorkflowLog(
      text: '##[group]Run Flutter tests\n10:14:25 [ERROR] Tests failed\n##[endgroup]',
    );
  }

  @override
  Future<WorkflowRunsPage> getRuns(
    String? token,
    ProjectRepo repo, {
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    calls.add((repoId: repo.id, page: page, size: perPage, status: status));
    if (pending[repo.id] != null) return await pending[repo.id]!.future;
    if (error != null) throw error!;
    return pages[page] ?? WorkflowRunsPage(runs: [details.run], hasMore: false);
  }

  @override
  Future<WorkflowRunDetails> getRunDetails(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
  ) async {
    detailsCalls++;
    if (pendingDetails != null) return await pendingDetails!.future;
    if (error != null) throw error!;
    return details;
  }
}

void main() {
  test('Status and conclusion are separate; unknown and incomplete are never success', () {
    expect(WorkflowState.fromGitHub('completed', null), WorkflowState.unknown);
    expect(
      WorkflowState.fromGitHub('in_progress', 'success'),
      WorkflowState.running,
    );
    expect(WorkflowState.fromGitHub('queued', null), WorkflowState.queued);
    expect(
      WorkflowState.fromGitHub('completed', 'timed_out'),
      WorkflowState.timedOut,
    );
    expect(
      WorkflowState.fromGitHub('completed', 'skipped'),
      WorkflowState.skipped,
    );
    expect(
      WorkflowState.fromGitHub('completed', 'cancelled'),
      WorkflowState.cancelled,
    );
    expect(
      WorkflowState.fromGitHub('new_status', 'success'),
      WorkflowState.unknown,
    );
    final run = WorkflowRun.fromJson({
      ...runJson(10),
      'name': null,
      'display_title': null,
      'head_branch': null,
      'created_at': null,
    });
    expect(run.workflowName, 'Workflow');
    expect(run.branch, isEmpty);
    expect(run.createdAt, isNull);
  });

  test(
    'Run pages use the provider token, fixed host and safe pagination',
    () async {
      final repository = GitHubActionsRepository();
      var calls = 0;
      await http.runWithClient(
        () async {
          final first = await repository.getRuns(
            'fake-provider-token',
            savedRepo,
          );
          final second = await repository.getRuns(
            'fake-provider-token',
            savedRepo,
            page: 2,
          );
          expect(first.hasMore, isTrue);
          expect(first.runs.single.attempt, 2);
          expect(second.hasMore, isFalse);
          expect(second.runs.single.id, 11);
        },
        () => MockClient((request) async {
          calls++;
          expect(request.url.host, 'api.github.com');
          expect(request.url.path, '/repos/linh/mobile/actions/runs');
          expect(request.url.queryParameters['page'], '$calls');
          expect(request.url.queryParameters['per_page'], '20');
          expect(request.url.queryParameters.containsKey('status'), isFalse);
          expect(
            request.headers['Authorization'],
            'Bearer fake-provider-token',
          );
          expect(request.followRedirects, isFalse);
          return runsResponse([calls == 1 ? 10 : 11], more: calls == 1);
        }),
      );
    },
  );

  test('Every filtered page sends its status to GitHub', () async {
    final queries = <Map<String, String>>[];
    await http.runWithClient(
      () async {
        final repository = GitHubActionsRepository();
        for (final filter in RunFilter.values.where(
          (item) => item.status != null,
        )) {
          await repository.getRuns('fake', savedRepo, status: filter.status);
          await repository.getRuns(
            'fake',
            savedRepo,
            page: 2,
            status: filter.status,
          );
        }
      },
      () => MockClient((request) async {
        queries.add(request.url.queryParameters);
        return runsResponse([]);
      }),
    );
    expect(queries.map((query) => query['status']), [
      'success',
      'success',
      'failure',
      'failure',
      'in_progress',
      'in_progress',
    ]);
    expect(queries.map((query) => query['page']), [
      '1',
      '2',
      '1',
      '2',
      '1',
      '2',
    ]);
  });

  test(
    'Run detail pins the attempt and collects all job pages atomically',
    () async {
      final paths = <String>[];
      await http.runWithClient(
        () async {
          final details = await GitHubActionsRepository().getRunDetails(
            'fake',
            savedRepo,
            WorkflowRun.fromJson(runJson(10)),
          );
          expect(details.jobs.map((job) => job.id), [1, 2]);
          expect(details.jobs.first.steps.last.conclusion, 'failure');
          expect(details.run.attempt, 2);
          expect(paths, [
            '/repos/linh/mobile/actions/runs/10/attempts/2',
            '/repos/linh/mobile/actions/runs/10/attempts/2/jobs',
            '/repos/linh/mobile/actions/runs/10/attempts/2/jobs',
          ]);
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          if (!request.url.path.endsWith('/jobs')) {
            expect(request.url.query, isEmpty);
            return http.Response(jsonEncode(runJson(10)), 200);
          }
          final page = int.parse(request.url.queryParameters['page']!);
          expect(request.url.queryParameters['per_page'], '100');
          return http.Response(
            jsonEncode({
              'jobs': [jobJson(page)],
            }),
            200,
            headers: page == 1 ? {'link': '<next>; rel="next"'} : {},
          );
        }),
      );
    },
  );

  test('A failed job page or mismatched attempt cannot return partial/wrong details', () async {
    for (final mode in [
      'second-page-error',
      'wrong-run-attempt',
      'wrong-job-attempt',
    ]) {
      await http.runWithClient(
        () async {
          await expectLater(
            GitHubActionsRepository().getRunDetails(
              'fake',
              savedRepo,
              WorkflowRun.fromJson(runJson(10)),
            ),
            throwsA(isA<GitHubException>()),
          );
        },
        () => MockClient((request) async {
          if (!request.url.path.endsWith('/jobs')) {
            return http.Response(
              jsonEncode(
                runJson(10, attempt: mode == 'wrong-run-attempt' ? 3 : 2),
              ),
              200,
            );
          }
          if (request.url.queryParameters['page'] == '2') {
            return http.Response('{}', 500);
          }
          return http.Response(
            jsonEncode({
              'jobs': [
                jobJson(1, attempt: mode == 'wrong-job-attempt' ? 3 : 2),
              ],
            }),
            200,
            headers: {'link': '<next>; rel="next"'},
          );
        }),
      );
    }
  });

  for (final status in [401, 403, 404, 429, 500]) {
    test(
      'Actions HTTP $status is readable and not treated as an empty history',
      () async {
        await http.runWithClient(() async {
          await expectLater(
            GitHubActionsRepository().getRuns('fake', savedRepo),
            throwsA(
              isA<GitHubException>()
                  .having((error) => error.message, 'message', isNotEmpty)
                  .having(
                    (error) => error.requiresSignIn,
                    'requiresSignIn',
                    status == 401,
                  ),
            ),
          );
        }, () => MockClient((_) async => http.Response('{}', status)));
      },
    );
  }

  test(
    'Retry-After blocks extra calls and missing credentials never reach HTTP',
    () async {
      var calls = 0;
      await http.runWithClient(
        () async {
          final repository = GitHubActionsRepository();
          for (var attempt = 0; attempt < 2; attempt++) {
            await expectLater(
              repository.getRuns('fake', savedRepo),
              throwsA(isA<GitHubException>()),
            );
          }
          expect(calls, 1);
          await expectLater(
            GitHubActionsRepository().getRuns(null, savedRepo),
            throwsA(
              isA<GitHubException>().having(
                (e) => e.requiresSignIn,
                'sign-in',
                isTrue,
              ),
            ),
          );
          expect(calls, 1);
        },
        () => MockClient((_) async {
          calls++;
          return http.Response('{}', 403, headers: {'retry-after': '60'});
        }),
      );
    },
  );

  test('Malformed JSON, malformed schema, timeouts and network errors are readable', () async {
    for (final failure in ['html', 'schema', 'timeout', 'network']) {
      await http.runWithClient(
        () async {
          await expectLater(
            GitHubActionsRepository().getRuns('fake', savedRepo),
            throwsA(isA<GitHubException>()),
          );
        },
        () => MockClient((_) async {
          if (failure == 'timeout') throw TimeoutException('fake timeout');
          if (failure == 'network') throw http.ClientException('offline');
          return http.Response(
            failure == 'html' ? '<html>error</html>' : '{"workflow_runs":{}}',
            200,
          );
        }),
      );
    }
  });

  test(
    'Summary loads five at a time and reveals only the completed batch',
    () async {
      final repository = FakeActionsRepository();
      final repos = List.generate(
        6,
        (id) => ProjectRepo(id: id + 1, fullName: 'team/repo-$id'),
      );
      for (final repo in repos) {
        repository.pending[repo.id] = Completer<WorkflowRunsPage>();
      }
      final model = ProjectDetailViewModel(
        repository,
        repositories: repos,
        accessToken: 'fake',
      );
      addTearDown(model.dispose);
      final first = model.load();
      await model.load();
      expect(repository.calls.length, 5);
      expect(model.loading, isTrue);
      repository.pending[1]!.complete(
        const WorkflowRunsPage(runs: [], hasMore: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(model.visibleCount, 0);
      expect(model.latestRuns, isEmpty);
      for (final repo in repos.skip(1).take(4)) {
        repository.pending[repo.id]!.complete(
          WorkflowRunsPage(runs: [repository.details.run], hasMore: true),
        );
      }
      await first;
      expect(model.visibleCount, 5);
      expect(model.latestRuns[1], isNull);
      expect(model.errors, isEmpty);
      final next = model.load(more: true);
      expect(model.visibleCount, 5);
      repository.pending[6]!.completeError(
        const GitHubException('Repo này không có quyền', accessDenied: true),
      );
      await next;
      expect(model.visibleCount, 6);
      expect(model.errors[6], contains('không có quyền'));
      expect(model.latestRuns[2], isNotNull);
    },
  );

  test(
    'Editing repo selection and disposing ignore old pending summaries',
    () async {
      final repository = FakeActionsRepository();
      repository.pending[1] = Completer<WorkflowRunsPage>();
      final model = ProjectDetailViewModel(
        repository,
        repositories: [savedRepo],
        accessToken: 'fake',
      );
      final oldLoad = model.load();
      await model.updateRepositories([
        const ProjectRepo(id: 2, fullName: 'team/new'),
      ]);
      repository.pending[1]!.complete(
        WorkflowRunsPage(runs: [repository.details.run], hasMore: false),
      );
      await oldLoad;
      expect(model.latestRuns.keys, [2]);
      final pending = Completer<WorkflowRunsPage>();
      repository.pending[2] = pending;
      final refresh = model.load();
      model.dispose();
      pending.complete(const WorkflowRunsPage(runs: [], hasMore: false));
      await refresh;
      expect(model.latestRuns[2], isNotNull);
    },
  );

  test('Pagination retries the failed page, deduplicates runs and preserves refresh data', () async {
    final repository = FakeActionsRepository();
    repository.pages[1] = WorkflowRunsPage(
      runs: [WorkflowRun.fromJson(runJson(10))],
      hasMore: true,
    );
    final model = RepositoryRunsViewModel(
      repository,
      repo: savedRepo,
      accessToken: 'fake',
    );
    addTearDown(model.dispose);
    await model.load();
    repository.error = const GitHubException('offline');
    await model.load(more: true);
    expect(model.runs.single.id, 10);
    expect(model.hasMore, isTrue);
    repository.error = null;
    repository.pages[2] = WorkflowRunsPage(
      runs: [
        WorkflowRun.fromJson(runJson(10, attempt: 3)),
        WorkflowRun.fromJson(runJson(11)),
      ],
      hasMore: false,
    );
    await model.load(more: true);
    expect(repository.calls.map((c) => c.page), [1, 2, 2]);
    expect(model.runs.map((run) => run.id), [10, 11]);
    expect(model.runs.first.attempt, 3);
    repository.pending[savedRepo.id] = Completer<WorkflowRunsPage>();
    final refresh = model.load();
    expect(model.runs.length, 2);
    await model.load();
    repository.pending[savedRepo.id]!.completeError(
      const GitHubException('offline'),
    );
    await refresh;
    expect(model.runs.length, 2);
    expect(model.error, 'offline');
  });

  test(
    'Changing a filter resets pagination and ignores a late old page',
    () async {
      final repository = FakeActionsRepository();
      repository.pages[1] = WorkflowRunsPage(
        runs: [WorkflowRun.fromJson(runJson(10))],
        hasMore: true,
      );
      final model = RepositoryRunsViewModel(
        repository,
        repo: savedRepo,
        accessToken: 'fake',
      );
      addTearDown(model.dispose);
      await model.load();
      final oldPage = Completer<WorkflowRunsPage>();
      repository.pending[savedRepo.id] = oldPage;
      final loadMore = model.load(more: true);
      final filtered = Completer<WorkflowRunsPage>();
      repository.pending[savedRepo.id] = filtered;
      final select = model.selectFilter(RunFilter.success);
      expect(model.runs, isEmpty);
      expect(model.loadingMore, isFalse);
      expect(repository.calls.last.page, 1);
      expect(repository.calls.last.status, 'success');
      oldPage.complete(
        WorkflowRunsPage(
          runs: [WorkflowRun.fromJson(runJson(11))],
          hasMore: true,
        ),
      );
      await loadMore;
      expect(model.loading, isTrue);
      expect(model.runs, isEmpty);
      final success = WorkflowRun.fromJson({
        ...runJson(20),
        'conclusion': 'success',
      });
      filtered.complete(WorkflowRunsPage(runs: [success], hasMore: true));
      await select;
      expect(model.runs.single.id, 20);
      repository.pending.clear();
      repository.error = const GitHubException('offline');
      await model.load(more: true);
      expect(repository.calls.last.page, 2);
      expect(repository.calls.last.status, 'success');
      expect(model.runs.single.id, 20);
      await model.selectFilter(RunFilter.failure);
      expect(model.runs, isEmpty);
      expect(model.error, 'offline');
      expect(repository.calls.last.page, 1);
      expect(repository.calls.last.status, 'failure');
    },
  );

  testWidgets(
    'History groups dates, filters on GitHub and links back to its project',
    (tester) async {
      final now = DateTime.now();
      final dates = [now, DateTime(now.year, now.month, now.day - 1, 12)];
      final queries = <Map<String, String>>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RepositoryRunsView(
                          repo: savedRepo,
                          projectName: 'Vista',
                          repository: GitHubActionsRepository(),
                          accessToken: 'fake',
                        ),
                      ),
                    ),
                    child: const Text('Project gốc'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Project gốc'));
          await tester.pumpAndSettle();
          expect(find.text('Hôm nay'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('Hôm qua'), 150);
          expect(find.text('Hôm qua'), findsOneWidget);
          await tester.scrollUntilVisible(find.byType(ChoiceChip).first, -200);
          await tester.tap(find.widgetWithText(ChoiceChip, 'Thành công'));
          await tester.pumpAndSettle();
          expect(queries.last['status'], 'success');
          expect(find.text('Build mobile 10'), findsNothing);
          expect(
            find.text('Không có lần chạy ở trạng thái đã chọn.'),
            findsOneWidget,
          );
          await tester.tap(find.widgetWithText(TextButton, 'Vista'));
          await tester.pumpAndSettle();
          expect(find.text('Project gốc'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          queries.add(request.url.queryParameters);
          return http.Response(
            jsonEncode({
              'workflow_runs': [
                if (request.url.queryParameters['status'] == null)
                  for (var index = 0; index < dates.length; index++)
                    {
                      ...runJson(index + 10),
                      'created_at': dates[index].toUtc().toIso8601String(),
                    },
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets(
    'History handles long names and filters at 320px with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeActionsRepository();
      repository.pages[1] = WorkflowRunsPage(
        runs: [
          WorkflowRun.fromJson({
            ...runJson(10),
            'name': 'Kiểm thử và triển khai ứng dụng mobile trên Android',
            'head_branch': 'feature/very-long-repository-branch-name',
          }),
        ],
        hasMore: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: RepositoryRunsView(
            repo: const ProjectRepo(
              id: 1,
              fullName: 'owner/repository-with-a-very-long-name',
            ),
            projectName: 'Dự án quản lý kiểm thử tự động của nhóm phát triển',
            repository: repository,
            accessToken: 'fake',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Build mobile 10'), 200);
      expect(tester.takeException(), isNull);
    },
  );

  test('Run refresh preserves data on a server failure and clears it on lost access', () async {
    final repository = FakeActionsRepository();
    final model = WorkflowRunViewModel(
      repository,
      repo: savedRepo,
      run: repository.details.run,
      accessToken: 'fake',
    );
    addTearDown(model.dispose);
    await model.load();
    repository.error = const GitHubException('offline');
    await model.load();
    expect(model.details, isNotNull);
    repository.error = const GitHubException('forbidden', accessDenied: true);
    await model.load();
    expect(model.details, isNull);
    expect(model.error, 'forbidden');
  });

  test(
    'Late run and history requests cannot update disposed view models',
    () async {
      final repository = FakeActionsRepository();
      repository.pending[savedRepo.id] = Completer<WorkflowRunsPage>();
      repository.pendingDetails = Completer<WorkflowRunDetails>();
      final history = RepositoryRunsViewModel(
        repository,
        repo: savedRepo,
        accessToken: 'fake',
      );
      final detail = WorkflowRunViewModel(
        repository,
        repo: savedRepo,
        run: repository.details.run,
        accessToken: 'fake',
      );
      final request = history.load();
      final runRequest = detail.load();
      history.dispose();
      detail.dispose();
      repository.pending[savedRepo.id]!.complete(
        WorkflowRunsPage(runs: [repository.details.run], hasMore: false),
      );
      repository.pendingDetails!.complete(repository.details);
      await Future.wait([request, runRequest]);
      expect(history.runs, isEmpty);
      expect(detail.details, isNull);
    },
  );

  testWidgets(
    'Project → repo → run waits for complete data and returns to cached summaries',
    (tester) async {
      final projectRepository = FakeProjectRepository()
        ..savedProjects = [testProject];
      final projects = ProjectsViewModel(
        projectRepository,
        uid: 'user-a',
        accessToken: 'fake',
      );
      addTearDown(projects.dispose);
      await projects.loadProjects();
      final summaryGate = Completer<http.Response>();
      final historyGate = Completer<http.Response>();
      final jobsGate = Completer<http.Response>();
      var summaries = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(body: ProjectsView(viewModel: projects)),
            ),
          );
          await tester.tap(find.text('Vista'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(AppLoading), findsOneWidget);
          expect(find.text('Build mobile 10'), findsNothing);
          summaryGate.complete(runsResponse([10]));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('mobile'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('mobile'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(RepositoryRunsView), findsOneWidget);
          expect(find.text('Lịch sử chạy'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Vista'), findsOneWidget);
          expect(find.byType(AppLoading), findsOneWidget);
          historyGate.complete(runsResponse([10]));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Build mobile 10'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Build mobile 10'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(WorkflowRunDetailView), findsOneWidget);
          expect(find.byType(AppLoading), findsOneWidget);
          expect(find.text('Build Android 1'), findsNothing);
          jobsGate.complete(
            http.Response(
              jsonEncode({
                'jobs': [jobJson(1)],
              }),
              200,
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Run Flutter tests'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Run Flutter tests'), findsOneWidget);
          expect(find.byType(AppLoading), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(summaries, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/logs')) {
            return http.Response(
              '##[group]Run Flutter tests\n10:14:25 [ERROR] Tests failed\n##[endgroup]',
              200,
              headers: {'content-type': 'text/plain'},
            );
          }
          if (request.url.path.endsWith('/jobs')) return jobsGate.future;
          if (request.url.path.endsWith('/attempts/2')) {
            return http.Response(jsonEncode(runJson(10)), 200);
          }
          if (request.url.queryParameters['per_page'] == '1') {
            summaries++;
            return summaryGate.future;
          }
          return historyGate.future;
        }),
      );
    },
  );

  testWidgets(
    'Long job/step names and badges fit a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeActionsRepository();
      repository.details = WorkflowRunDetails(
        run: repository.details.run,
        jobs: [
          WorkflowJob.fromJson({
            ...jobJson(1),
            'name': 'Build ứng dụng Android và chạy toàn bộ kiểm thử',
          }),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: WorkflowRunDetailView(
            repo: savedRepo,
            run: repository.details.run,
            repository: repository,
            accessToken: 'fake',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Run Flutter tests'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced motion keeps loading readable without spinning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: AppLoading(label: 'Đang tải…')),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
