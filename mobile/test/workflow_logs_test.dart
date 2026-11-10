import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vista_mobile/data/models/workflow_run.dart';
import 'package:vista_mobile/data/repositories/github_actions_repository.dart';
import 'package:vista_mobile/data/services/github_service.dart';
import 'package:vista_mobile/ui/projects/project_form_view.dart';
import 'package:vista_mobile/ui/projects/projects_view_model.dart';
import 'package:vista_mobile/ui/projects/workflow_run_detail_view.dart';
import 'package:vista_mobile/ui/projects/workflow_run_view_model.dart';
import 'package:vista_mobile/ui/theme/app_theme.dart';
import 'package:vista_mobile/ui/widgets/workflow_log_panel.dart';

import 'github_actions_test.dart' show FakeActionsRepository, jobJson;
import 'projects_test.dart' show FakeProjectRepository, savedRepo, testProject;

void main() {
  test(
    'Provider log groups preserve order, line numbers and unclosed content',
    () {
      final log = WorkflowLog.fromText(
        'before\n2026-11-04T10:00:00Z ##[group]Checkout\nfetch\n##[group]Submodule\npull\n##[endgroup]\ndone\n##[endgroup]\nafter',
      );
      expect(log.sections.map((s) => s.title), [
        null,
        'Checkout',
        'Checkout / Submodule',
        'Checkout',
        null,
      ]);
      expect(log.sections.map((s) => s.startLine), [1, 3, 5, 7, 9]);
      expect(log.sections.map((s) => s.text), [
        'before',
        'fetch',
        'pull',
        'done',
        'after',
      ]);
      expect(
        WorkflowLog.fromText('##[group]Build\n[ERROR] failed')
            .sections
            .single
            .text,
        '[ERROR] failed',
      );
      expect(
        WorkflowLog.fromText('example ##[group]literal').sections.single.title,
        isNull,
      );
      expect(log.text, contains('##[group]Checkout'));
    },
  );
  test('Signed log download never receives the provider token or follows redirects', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        final log = await GitHubActionsRepository().getJobLog(
          'fake-token',
          savedRepo,
          1,
        );
        expect(log.text, '10:14 [ERROR] failed\n<html>plain text</html>');
        expect(log.truncated, isFalse);
        expect(calls, 2);
      },
      () => MockClient((request) async {
        calls++;
        expect(request.followRedirects, isFalse);
        if (calls == 1) {
          expect(request.url.path, '/repos/linh/mobile/actions/jobs/1/logs');
          expect(request.headers['Authorization'], 'Bearer fake-token');
          return http.Response(
            '',
            302,
            headers: {'location': 'https://logs.example/file?sig=fake'},
          );
        }
        expect(request.url.host, 'logs.example');
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('cookie')),
        );
        return http.Response(
          '10:14 \x1B[31m[ERROR]\x1B[0m failed\r\n<html>plain text</html>',
          200,
          headers: {'content-type': 'text/plain'},
        );
      }),
    );
  });

  test(
    'Unsafe redirect destinations are rejected before sending another request',
    () async {
      for (final url in [
        'http://logs.example/file',
        '/relative',
        'https://user:pass@logs.example/file',
        'https://logs.example:1234/file',
      ]) {
        var calls = 0;
        await http.runWithClient(
          () async {
            await expectLater(
              GitHubActionsRepository().getJobLog('fake', savedRepo, 1),
              throwsA(isA<GitHubException>()),
            );
            expect(calls, 1);
          },
          () => MockClient((_) async {
            calls++;
            return http.Response('', 302, headers: {'location': url});
          }),
        );
      }
    },
  );

  test(
    'Log preview bounds bytes and lines and removes terminal control sequences',
    () async {
      await http.runWithClient(() async {
        final log = await GitHubActionsRepository().getJobLog(
          'fake',
          savedRepo,
          1,
        );
        expect(log.text.length, 256 * 1024);
        expect(log.truncated, isTrue);
      }, () => MockClient((_) async => http.Response('x' * (300 * 1024), 200)));
      final log = WorkflowLog.fromText(
        List.generate(1002, (i) => 'line $i').join('\n'),
      );
      expect(log.text.split('\n').length, 1000);
      expect(log.truncated, isTrue);
      expect(
        WorkflowLog.fromText('\x1B[31mError\x1B[0m\r\nnext\x00').text,
        'Error\nnext',
      );
    },
  );

  test('Expired logs and failed signed downloads remain separate from lost repo access', () async {
    for (final status in [404, 410]) {
      await http.runWithClient(() async {
        await expectLater(
          GitHubActionsRepository().getJobLog('fake', savedRepo, 1),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.accessDenied,
              'access denied',
              isFalse,
            ),
          ),
        );
      }, () => MockClient((_) async => http.Response('', status)));
    }
    await http.runWithClient(
      () async {
        await expectLater(
          GitHubActionsRepository().getJobLog('fake', savedRepo, 1),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.accessDenied,
              'access denied',
              isFalse,
            ),
          ),
        );
      },
      () => MockClient(
        (request) async => request.url.host == 'api.github.com'
            ? http.Response(
                '',
                302,
                headers: {'location': 'https://logs.example/expired'},
              )
            : http.Response('', 403),
      ),
    );
  });

  test(
    'Log failures use the shared API cooldown and report timeouts readably',
    () async {
      var calls = 0;
      await http.runWithClient(
        () async {
          final repository = GitHubActionsRepository();
          await expectLater(
            repository.getJobLog('fake', savedRepo, 1),
            throwsA(isA<GitHubException>()),
          );
          await expectLater(
            repository.getRuns('fake', savedRepo),
            throwsA(isA<GitHubException>()),
          );
          expect(calls, 1);
        },
        () => MockClient((_) async {
          calls++;
          return http.Response('', 429, headers: {'retry-after': '60'});
        }),
      );
      await http.runWithClient(() async {
        await expectLater(
          GitHubActionsRepository().getJobLog('fake', savedRepo, 1),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.message,
              'message',
              contains('quá lâu'),
            ),
          ),
        );
      }, () => MockClient((_) async => throw TimeoutException('timeout')));
    },
  );

  test('Jobs retain independent logs; refresh preserves data and disposal ignores late responses', () async {
    final repository = FakeActionsRepository();
    repository.details = WorkflowRunDetails(
      run: repository.details.run,
      jobs: [
        WorkflowJob.fromJson(jobJson(1)),
        WorkflowJob.fromJson(jobJson(2)),
      ],
    );
    repository.pendingLogs[1] = Completer<WorkflowLog>();
    repository.pendingLogs[2] = Completer<WorkflowLog>();
    final model = WorkflowRunViewModel(
      repository,
      repo: savedRepo,
      run: repository.details.run,
      accessToken: 'fake',
    );
    final initial = model.load();
    await Future<void>.delayed(Duration.zero);
    expect(model.initialJobId, 1);
    final select = model.loadJobLog(2);
    repository.pendingLogs[2]!.complete(const WorkflowLog(text: 'job two'));
    await select;
    repository.pendingLogs[1]!.complete(const WorkflowLog(text: 'old job one'));
    await initial;
    expect(model.logs[2]!.text, 'job two');
    expect(model.logs[1]!.text, 'old job one');
    repository.pendingLogs[2] = Completer<WorkflowLog>();
    final refresh = model.loadJobLog(2, refresh: true);
    expect(model.logs[2]!.text, 'job two');
    repository.pendingLogs[2]!.completeError(const GitHubException('offline'));
    await refresh;
    expect(model.logs[2]!.text, 'job two');
    expect(model.logErrors[2], 'offline');
    repository.pendingLogs[2] = Completer<WorkflowLog>();
    final late = model.loadJobLog(2, refresh: true);
    model.dispose();
    repository.pendingLogs[2]!.complete(const WorkflowLog(text: 'late'));
    await late;
    expect(model.logs[2]!.text, 'job two');
  });

  testWidgets(
    'Dark terminal always wraps, copies literal source and fits large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final log = WorkflowLog(
        text:
            '10:14 [ERROR] failed\n<script>literal</script>\n${'long source path ' * 30}',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                WorkflowLogPanel(
                  jobs: [WorkflowJob.fromJson(jobJson(1))],
                  logs: {1: log},
                  errors: const {},
                  loadingJobs: const {},
                  onLoadJob: (_) async {},
                  initialJobId: 1,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Ngắt dòng'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  WorkflowLogColors.background,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sao chép'));
      await tester.pumpAndSettle();
      expect(copied, log.text);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Terminal jobs and provider groups fold independently and reuse loaded logs',
    (tester) async {
      final repository = FakeActionsRepository();
      repository.details = WorkflowRunDetails(
        run: repository.details.run,
        jobs: [
          WorkflowJob.fromJson(jobJson(1)),
          WorkflowJob.fromJson(jobJson(2)),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WorkflowRunDetailView(
            repo: savedRepo,
            run: repository.details.run,
            repository: repository,
            accessToken: 'fake',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.logCalls, [1]);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tester.ensureVisible(find.text('Run Flutter tests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run Flutter tests'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      await tester.ensureVisible(find.text('Build Android 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build Android 2'));
      await tester.pumpAndSettle();
      expect(repository.logCalls, [1, 2]);
      for (var toggle = 0; toggle < 2; toggle++) {
        await tester.ensureVisible(find.text('Build Android 2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Build Android 2'));
        await tester.pumpAndSettle();
      }
      expect(repository.logCalls, [1, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Expanded terminal supports pull refresh without reload buttons',
    (tester) async {
      final repository = FakeActionsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
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
        find.text('Mở log'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở log'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowLogPanel), findsOneWidget);
      expect(find.text('Tải lại'), findsNothing);
      final previous = repository.logCalls.length;
      await tester.dragFrom(const Offset(200, 95), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(repository.logCalls.length, greaterThan(previous));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Repository picker cancels draft changes and confirms without losing form fields',
    (tester) async {
      final repository = FakeProjectRepository();
      final model = ProjectsViewModel(
        repository,
        uid: 'user-a',
        accessToken: 'fake',
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ProjectFormView(viewModel: model, project: testProject),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Local draft');
      await tester.pumpAndSettle();
      Future<void> openPicker() async {
        await tester.scrollUntilVisible(
          find.text('Chọn repository'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn repository'));
        await tester.pumpAndSettle();
      }

      await openPicker();
      await tester.scrollUntilVisible(
        find.widgetWithText(CheckboxListTile, 'team/api'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'team/api'));
      await tester.pumpAndSettle();
      expect(model.selectedRepositories.length, 2);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(model.selectedRepositories.map((r) => r.id), [1]);
      await openPicker();
      await tester.scrollUntilVisible(
        find.widgetWithText(CheckboxListTile, 'team/api'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'team/api'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận lựa chọn'));
      await tester.pumpAndSettle();
      expect(model.selectedRepositories.length, 2);
      await tester.scrollUntilVisible(
        find.text('Tên project'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Local draft',
      );
      expect(repository.writeCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
