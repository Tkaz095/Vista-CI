import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vista_mobile/data/services/gemini_analysis_service.dart';
import 'package:vista_mobile/data/services/firestore_ci_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vista_mobile/data/models/ci_analysis.dart';
import 'package:vista_mobile/data/models/project.dart';
import 'package:vista_mobile/data/models/workflow_run.dart';
import 'package:vista_mobile/data/repositories/ci_analysis_repository.dart';
import 'package:vista_mobile/data/repositories/github_actions_repository.dart';
import 'package:vista_mobile/data/services/github_service.dart';
import 'package:vista_mobile/ui/projects/ci_comment_view.dart';
import 'package:vista_mobile/ui/projects/ci_analysis_view.dart';
import 'package:vista_mobile/ui/projects/workflow_run_detail_view.dart';
import 'package:vista_mobile/ui/projects/workflow_run_view_model.dart';
import 'package:vista_mobile/ui/theme/app_theme.dart';

import 'github_actions_test.dart' show FakeActionsRepository, runJson, jobJson;
import 'projects_test.dart' show savedRepo;

CiAnalysisInput inputFor(WorkflowRun run) => CiAnalysisInput(
  repo: savedRepo,
  run: run,
  logs: const [
    CiJobLog(
      jobId: 1,
      name: 'Run tests',
      lines: {218: 'ERROR: Connection refused'},
      incomplete: true,
    ),
  ],
  failedJobCount: 1,
);

Map<String, dynamic> validOutput() => {
  'summary': 'Không kết nối được PostgreSQL.',
  'probableCause': 'Database có thể chưa sẵn sàng.',
  'suggestions': ['Kiểm tra health check trước khi chạy test.'],
  'missingContext': ['Cần xem cấu hình service database.'],
  'evidence': [
    {'jobId': 1, 'line': 218, 'quote': 'Connection refused'},
  ],
};

class FakeCiRepository extends CiAnalysisRepository {
  FakeCiRepository(super.github);
  CiAnalysis? saved;
  Completer<CiAnalysis?>? readGate;
  Completer<CiAnalysisInput>? prepareGate;
  Completer<CiAnalysis>? analyzeGate;
  Object? saveError;
  Object? readError;
  int analyzeCalls = 0;
  int saveCalls = 0;
  @override
  Future<CiAnalysis?> readSaved(ProjectRepo repo, WorkflowRun run) async {
    if (readError != null) throw readError!;
    return readGate == null ? saved : readGate!.future;
  }

  @override
  Future<CiAnalysisInput> prepare(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
  ) async => prepareGate == null ? inputFor(run) : prepareGate!.future;
  @override
  Future<CiAnalysis> analyze(CiAnalysisInput input) async {
    analyzeCalls++;
    if (analyzeGate != null) return analyzeGate!.future;
    return CiAnalysisRepository.validateOutput(input, validOutput());
  }

  @override
  Future<void> save(CiAnalysis analysis) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    saved = analysis;
  }
}

void main() {
  test(
    'AI setup errors distinguish App Check, model, quota and API restrictions',
    () {
      final cases = <Object, String>{
        ServerException(
          'PERMISSION_DENIED: To access this model, you must enforce Firebase App Check.',
        ): 'AI_APP_CHECK',
        ServerException('Firebase AI Logic genai config not found'): 'AI_SETUP',
        ServerException(
          'Requests to this API firebasevertexai.googleapis.com are blocked.',
        ): 'AI_API_RESTRICTION',
        ServerException(
          'Model models/example was not found or your project does not have access to it.',
        ): 'AI_MODEL',
        ServerException('RESOURCE_EXHAUSTED: rate limit'): 'AI_QUOTA',
        ServerException(
          'PERMISSION_DENIED: The caller does not have permission.',
        ): 'AI_PERMISSION',
        ServerException('INVALID_ARGUMENT: response_schema is invalid'):
            'AI_REQUEST',
        ServerException('Billing is disabled'): 'AI_BILLING',
        InvalidApiKey('bad key'): 'AI_API_KEY',
        ServiceApiNotEnabled('projects/test-project'): 'AI_SETUP',
        FirebaseAISdkException('private generated response'): 'AI_SDK_RESPONSE',
        FirebaseException(plugin: 'firebase_app_check', code: 'token-error'):
            'AI_APP_CHECK',
      };
      for (final entry in cases.entries) {
        expect(
          GeminiAnalysisService.errorMessage(entry.key),
          contains(entry.value),
        );
      }
      expect(
        GeminiAnalysisService.errorMessage(
          FirebaseAISdkException('private generated response'),
        ),
        isNot(contains('private generated response')),
      );
    },
  );

  test('Unexpected provider reasons are bounded and credentials are redacted', () {
    final message = GeminiAnalysisService.errorMessage(
      ServerException(
        'Unexpected upstream failure. Authorization: Bearer verySensitiveBearer API_KEY=privateApiKey https://example.test/?token=privateQuery ${'x' * 1000}',
      ),
    );
    expect(message, contains('AI_SERVER'));
    expect(message, isNot(contains('verySensitiveBearer')));
    expect(message, isNot(contains('privateApiKey')));
    expect(message, isNot(contains('privateQuery')));
    expect(message.length, lessThan(320));
  });

  test(
    'Billing failures keep the provider reason without exposing credentials',
    () {
      final message = GeminiAnalysisService.errorMessage(
        ServerException(
          'Billing requires prepaid credits. API_KEY=privateBillingKey',
        ),
      );
      expect(message, contains('AI_BILLING'));
      expect(message, contains('prepaid credits'));
      expect(message, contains('Google AI Studio'));
      expect(message, isNot(contains('privateBillingKey')));
    },
  );

  test('Firestore permission and connection failures give different recovery steps', () {
    final denied = FirestoreCiAnalysisService.errorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      action: 'đọc',
    );
    final offline = FirestoreCiAnalysisService.errorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      action: 'lưu',
    );
    expect(denied, contains('Publish Rules'));
    expect(denied, contains('ciAnalyses'));
    expect(offline, contains('kết nối'));
    expect(offline, isNot(contains('Rules')));
  });

  test(
    'Run view model preserves the specific storage error instead of hiding it',
    () async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github)
        ..readError = const CiAnalysisException(
          'Firestore: permission-denied; Publish Rules ciAnalyses',
        );
      final model = WorkflowRunViewModel(
        github,
        repo: savedRepo,
        run: github.details.run,
        accessToken: 'fake',
        analysisRepository: ai,
      );
      addTearDown(model.dispose);
      await model.load();
      await Future<void>.delayed(Duration.zero);
      expect(model.analysisWarning, contains('permission-denied'));
      expect(model.canAnalyze, isTrue);
    },
  );

  test('Redacts credentials before excerpts or prompts are built', () {
    final raw = '''Authorization: Bearer verySensitiveBearer
GITHUB_TOKEN=ghp_abcdefghijklmnop
PASSWORD="database-password"
https://user:private-password@example.com/database
-----BEGIN RSA PRIVATE KEY-----
privateKeyValue
-----END RSA PRIVATE KEY-----''';
    final redacted = redactCiText(raw);
    for (final value in [
      'verySensitiveBearer',
      'ghp_abcdefghijklmnop',
      'database-password',
      'private-password',
      'privateKeyValue',
    ]) {
      expect(redacted, isNot(contains(value)));
    }
    expect(redacted, contains('REDACTED'));
    expect(redacted.split('\n').length, raw.split('\n').length);
  });

  test(
    'Analysis preserves error tail and original line numbers beyond UI preview',
    () {
      final log = WorkflowLog(
        text: [
          for (var i = 1; i < 1800; i++) 'line $i',
          'ERROR: Connection refused',
        ].join('\n'),
      );
      final input = CiJobLog.fromLog(WorkflowJob.fromJson(jobJson(1)), log);
      expect(input.lines[1800], 'ERROR: Connection refused');
      expect(input.lines.length, lessThanOrEqualTo(80));
      expect(input.incomplete, isTrue);
      expect(
        input.lines.keys.toList(),
        orderedEquals(input.lines.keys.toList()..sort()),
      );
    },
  );

  test('Output metadata is assigned locally and evidence must match supplied lines', () {
    final input = inputFor(WorkflowRun.fromJson(runJson(10)));
    final result = CiAnalysisRepository.validateOutput(input, {
      ...validOutput(),
      'runId': 999,
      'attempt': 999,
    });
    expect(result.runId, 10);
    expect(result.attempt, 2);
    expect(result.incomplete, isTrue);
    final restored = CiAnalysis.fromJson(result.toJson());
    expect(restored.matches(savedRepo, input.run), isTrue);
    expect(restored.comment(savedRepo, input.run), contains('attempt 2'));
    expect(restored.comment(savedRepo, input.run), isNot(contains('<!--')));
    for (final evidence in [
      {'jobId': 2, 'line': 218, 'quote': 'Connection refused'},
      {'jobId': 1, 'line': 219, 'quote': 'Connection refused'},
      {'jobId': 1, 'line': 218, 'quote': 'Wrong log'},
    ]) {
      expect(
        () => CiAnalysisRepository.validateOutput(input, {
          ...validOutput(),
          'evidence': [evidence],
        }),
        throwsA(isA<CiAnalysisException>()),
      );
    }
  });

  test(
    'Analysis downloads a separate bounded log without UI line truncation',
    () async {
      await http.runWithClient(
        () async {
          final repo = GitHubActionsRepository();
          final full = await repo.getAnalysisLog('fake', savedRepo, 1);
          final preview = await repo.getJobLog('fake', savedRepo, 1);
          expect(full.text, contains('ERROR AT END'));
          expect(preview.text, isNot(contains('ERROR AT END')));
          expect(preview.truncated, isTrue);
        },
        () => MockClient(
          (request) async => http.Response(
            [
              for (var i = 0; i < 1500; i++) 'line $i',
              'ERROR AT END',
            ].join('\n'),
            200,
          ),
        ),
      );
    },
  );

  test(
    'Rerun validates latest attempt and sends exactly the selected action',
    () async {
      final writes = <String>[];
      var latestAttempt = 2;
      await http.runWithClient(
        () async {
          final repo = GitHubActionsRepository();
          final run = WorkflowRun.fromJson(runJson(10));
          await repo.rerun('fake', savedRepo, run, failedOnly: true);
          await repo.rerun('fake', savedRepo, run, failedOnly: false);
          latestAttempt = 3;
          await expectLater(
            repo.rerun('fake', savedRepo, run, failedOnly: true),
            throwsA(isA<GitHubException>()),
          );
          expect(writes, [
            '/repos/linh/mobile/actions/runs/10/rerun-failed-jobs',
            '/repos/linh/mobile/actions/runs/10/rerun',
          ]);
        },
        () => MockClient((request) async {
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer fake');
          if (request.method == 'POST') {
            writes.add(request.url.path);
            return http.Response('', 201);
          }
          return http.Response(
            jsonEncode(runJson(10, attempt: latestAttempt)),
            200,
          );
        }),
      );
    },
  );

  test('A write connection failure has unknown outcome and is never automatically retried', () async {
    var writes = 0;
    await http.runWithClient(
      () async {
        await expectLater(
          GitHubActionsRepository().rerun(
            'fake',
            savedRepo,
            WorkflowRun.fromJson(runJson(10)),
            failedOnly: false,
          ),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.outcomeUnknown,
              'outcomeUnknown',
              isTrue,
            ),
          ),
        );
        expect(writes, 1);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          writes++;
          throw http.ClientException('network interrupted');
        }
        return http.Response(jsonEncode(runJson(10)), 200);
      }),
    );
  });

  test(
    'PR comment checks relationship, head SHA, draft and duplicate marker',
    () async {
      final bodies = <String>[];
      var posted = false;
      var prSha = '1234567890abcdef';
      await http.runWithClient(
        () async {
          final repo = GitHubActionsRepository();
          final run = WorkflowRun.fromJson(runJson(10));
          final pulls = await repo.getPullRequests('fake', savedRepo, run);
          expect(pulls.single.number, 7);
          final first = await repo.postAnalysisComment(
            'fake',
            savedRepo,
            run,
            pulls.single,
            '1_10_2',
            'User reviewed this draft',
          );
          final second = await repo.postAnalysisComment(
            'fake',
            savedRepo,
            run,
            pulls.single,
            '1_10_2',
            'Should not send twice',
          );
          expect(first.id, second.id);
          expect(bodies, hasLength(1));
          expect(bodies.single, contains('User reviewed this draft'));
          expect(bodies.single, contains('<!-- vista-ci:1_10_2 -->'));
          prSha = 'new-sha';
          await expectLater(
            repo.postAnalysisComment(
              'fake',
              savedRepo,
              run,
              pulls.single,
              '1_10_2',
              'stale draft',
            ),
            throwsA(isA<GitHubException>()),
          );
          expect(bodies, hasLength(1));
        },
        () => MockClient((request) async {
          final path = request.url.path;
          final comment = {
            'id': 20,
            'html_url': 'https://github.com/linh/mobile/pull/7#issuecomment-20',
            'body': '<!-- vista-ci:1_10_2 -->',
          };
          if (path.endsWith('/runs/10')) {
            return http.Response(
              jsonEncode({
                ...runJson(10),
                'pull_requests': [
                  {'number': 7},
                ],
              }),
              200,
            );
          }
          if (path.endsWith('/pulls/7')) {
            return http.Response(
              jsonEncode({
                'number': 7,
                'title': 'Fix CI',
                'state': 'open',
                'head': {'sha': prSha},
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            bodies.add((jsonDecode(request.body) as Map)['body'] as String);
            posted = true;
            expect(request.headers['Content-Type'], 'application/json');
            return http.Response(jsonEncode(comment), 201);
          }
          if (path.endsWith('/comments')) {
            return http.Response(jsonEncode([if (posted) comment]), 200);
          }
          throw StateError('Unexpected request $path');
        }),
      );
    },
  );

  test(
    'Analysis stays visible if saving fails; duplicate AI requests are blocked',
    () async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github)
        ..saveError = StateError('permission denied');
      final model = WorkflowRunViewModel(
        github,
        repo: savedRepo,
        run: github.details.run,
        accessToken: 'fake',
        analysisRepository: ai,
      );
      addTearDown(model.dispose);
      await model.load();
      await Future<void>.delayed(Duration.zero);
      await model.prepareAnalysis();
      ai.analyzeGate = Completer<CiAnalysis>();
      final pending = model.analyze();
      await model.analyze();
      expect(ai.analyzeCalls, 1);
      ai.analyzeGate!.complete(
        CiAnalysisRepository.validateOutput(inputFor(model.run), validOutput()),
      );
      await pending;
      expect(model.analysis, isNotNull);
      expect(model.analysisWarning, contains('chưa lưu'));
      expect(ai.saveCalls, 1);
      await model.load();
      expect(model.analysis, isNotNull);
    },
  );

  test('A rerun switches attempt and clears old analysis and logs', () async {
    final github = FakeActionsRepository();
    final ai = FakeCiRepository(github)
      ..saved = CiAnalysisRepository.validateOutput(
        inputFor(github.details.run),
        validOutput(),
      );
    final model = WorkflowRunViewModel(
      github,
      repo: savedRepo,
      run: github.details.run,
      accessToken: 'fake',
      analysisRepository: ai,
    );
    addTearDown(model.dispose);
    await model.load();
    await Future<void>.delayed(Duration.zero);
    expect(model.analysis, isNotNull);
    final next = WorkflowRun.fromJson({
      ...runJson(10, attempt: 3),
      'status': 'queued',
      'conclusion': null,
    });
    github.latestRun = next;
    github.details = WorkflowRunDetails(run: next, jobs: []);
    await model.rerun(failedOnly: true);
    expect(github.rerunCalls, 1);
    expect(model.run.attempt, 3);
    expect(model.analysis, isNull);
    expect(model.logs, isEmpty);
    expect(model.canAnalyze, isFalse);
  });

  test(
    'An uncertain comment only checks the result on subsequent taps',
    () async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github)
        ..saved = CiAnalysisRepository.validateOutput(
          inputFor(github.details.run),
          validOutput(),
        );
      final model = WorkflowRunViewModel(
        github,
        repo: savedRepo,
        run: github.details.run,
        accessToken: 'fake',
        analysisRepository: ai,
      );
      addTearDown(model.dispose);
      await model.load();
      await Future<void>.delayed(Duration.zero);
      await model.loadPullRequests();
      github.writeError = const GitHubException(
        'unknown result',
        outcomeUnknown: true,
      );
      await model.postComment('draft');
      await model.postComment('draft');
      expect(github.commentCalls, 1);
      github.foundComment = GitHubComment(
        id: 20,
        url: Uri.parse('https://github.com/linh/mobile/pull/7#issuecomment-20'),
      );
      await model.postComment('draft');
      expect(model.postedComments[7]?.id, 20);
      expect(github.commentCalls, 1);
    },
  );

  test(
    'Disposed view model ignores late AI output and never saves it',
    () async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github)
        ..analyzeGate = Completer<CiAnalysis>();
      final model = WorkflowRunViewModel(
        github,
        repo: savedRepo,
        run: github.details.run,
        accessToken: 'fake',
        analysisRepository: ai,
      );
      await model.load();
      await Future<void>.delayed(Duration.zero);
      await model.prepareAnalysis();
      final pending = model.analyze();
      model.dispose();
      ai.analyzeGate!.complete(
        CiAnalysisRepository.validateOutput(inputFor(model.run), validOutput()),
      );
      await pending;
      expect(model.analysis, isNull);
      expect(ai.saveCalls, 0);
    },
  );

  testWidgets(
    'AI requires preview confirmation, then reuses the result for an editable PR comment',
    (tester) async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WorkflowRunDetailView(
            repo: savedRepo,
            run: github.details.run,
            repository: github,
            accessToken: 'fake',
            analysisRepository: ai,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Phân tích lỗi với Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phân tích lỗi với Gemini'));
      await tester.pumpAndSettle();
      expect(find.text('Log sẽ gửi cho Gemini'), findsOneWidget);
      expect(ai.analyzeCalls, 0);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(ai.analyzeCalls, 0);
      await tester.ensureVisible(find.text('Phân tích lỗi với Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phân tích lỗi với Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi để phân tích'));
      await tester.pumpAndSettle();
      expect(find.text('Không kết nối được PostgreSQL.'), findsOneWidget);
      expect(find.byType(CiAnalysisView), findsOneWidget);
      await tester.tap(find.text('Comment PR'));
      await tester.pumpAndSettle();
      expect(find.byType(CiCommentView), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'User đã kiểm tra: database chưa sẵn sàng.',
      );
      await tester.tap(find.text('Gửi comment'));
      await tester.pumpAndSettle();
      expect(
        github.commentBodies.single,
        'User đã kiểm tra: database chưa sẵn sàng.',
      );
      expect(ai.analyzeCalls, 1);
      expect(find.text('Mở comment trên GitHub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Analysis preview and PR editor fit narrow screens, large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final github = FakeActionsRepository()
        ..relatedPulls = [
          const GitHubPullRequest(
            number: 7,
            title:
                'Sửa lỗi CI và kiểm tra triển khai ứng dụng Android của nhóm',
            headSha: '1234567890abcdef',
          ),
        ];
      final ai = FakeCiRepository(github);
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
            run: github.details.run,
            repository: github,
            accessToken: 'fake',
            analysisRepository: ai,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Phân tích lỗi với Gemini'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Phân tích lỗi với Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phân tích lỗi với Gemini'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Gửi để phân tích'));
      await tester.pumpAndSettle();
      expect(find.byType(CiAnalysisView), findsOneWidget);
      final evidence = find.text('Bằng chứng từ log (1)');
      await tester.scrollUntilVisible(
        evidence,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      expect(find.text('Build Android 1 · dòng 218'), findsOneWidget);
      expect(find.text('Comment PR').hitTestable(), findsOneWidget);
      expect(find.text('Chạy lại CI').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Comment PR'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextFormField),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Bản nháp kiểm tra CI.',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomRight(find.widgetWithText(FilledButton, 'Gửi comment'))
            .dy,
        lessThanOrEqualTo(400),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved analysis opens its own route with collapsible source evidence',
    (tester) async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github)
        ..saved = CiAnalysisRepository.validateOutput(
          inputFor(github.details.run),
          validOutput(),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WorkflowRunDetailView(
            repo: savedRepo,
            run: github.details.run,
            repository: github,
            accessToken: 'fake',
            analysisRepository: ai,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nguyên nhân có thể'), findsNothing);
      await tester.ensureVisible(find.text('Xem phân tích'));
      await tester.tap(find.text('Xem phân tích'));
      await tester.pumpAndSettle();
      expect(find.byType(CiAnalysisView), findsOneWidget);
      expect(find.text('Tóm tắt lỗi'), findsOneWidget);
      expect(find.text('Connection refused'), findsNothing);
      final evidence = find.text('Bằng chứng từ log (1)');
      await tester.ensureVisible(evidence);
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      expect(find.text('Build Android 1 · dòng 218'), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);
      // The actions stay reachable after scrolling to the source excerpts.
      expect(find.text('Comment PR').hitTestable(), findsOneWidget);
      expect(find.text('Chạy lại CI').hitTestable(), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CiAnalysisView), findsNothing);
      await tester.ensureVisible(find.text('Xem phân tích'));
      await tester.tap(find.text('Xem phân tích'));
      await tester.pumpAndSettle();
      expect(find.text('Tóm tắt lỗi'), findsOneWidget);
      expect(ai.analyzeCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failedOnly in [true, false]) {
    testWidgets(
      'Analysis rerun choice failedOnly=$failedOnly returns to the new attempt',
      (tester) async {
        final github = FakeActionsRepository();
        final oldRun = github.details.run;
        final ai = FakeCiRepository(github)
          ..saved = CiAnalysisRepository.validateOutput(
            inputFor(oldRun),
            validOutput(),
          );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: WorkflowRunDetailView(
              repo: savedRepo,
              run: oldRun,
              repository: github,
              accessToken: 'fake',
              analysisRepository: ai,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Xem phân tích'));
        await tester.tap(find.text('Xem phân tích'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chạy lại CI'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            failedOnly ? 'Chạy lại các job lỗi' : 'Chạy lại toàn bộ workflow',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Commit: ${oldRun.sha}'), findsOneWidget);
        expect(github.rerunCalls, 0);
        final nextRun = WorkflowRun.fromJson({
          ...runJson(oldRun.id, attempt: oldRun.attempt + 1),
          'status': 'in_progress',
          'conclusion': null,
        });
        github.latestRun = nextRun;
        github.details = WorkflowRunDetails(run: nextRun, jobs: []);
        await tester.tap(find.text('Chạy lại'));
        await tester.pumpAndSettle();
        expect(github.rerunModes, [failedOnly]);
        expect(find.byType(CiAnalysisView), findsNothing);
        expect(find.text('Tóm tắt lỗi'), findsNothing);
        expect(
          find.textContaining('Đang xem attempt ${nextRun.attempt}'),
          findsOneWidget,
        );
        expect(ai.analyzeCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('An uncertain rerun stays on analysis and cannot send twice', (
    tester,
  ) async {
    final github = FakeActionsRepository()
      ..writeError = const GitHubException(
        'Chưa xác định GitHub đã nhận yêu cầu. Kéo xuống để kiểm tra.',
        outcomeUnknown: true,
      );
    final ai = FakeCiRepository(github)
      ..saved = CiAnalysisRepository.validateOutput(
        inputFor(github.details.run),
        validOutput(),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkflowRunDetailView(
          repo: savedRepo,
          run: github.details.run,
          repository: github,
          accessToken: 'fake',
          analysisRepository: ai,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xem phân tích'));
    await tester.tap(find.text('Xem phân tích'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chạy lại CI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chạy lại các job lỗi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chạy lại'));
    await tester.pumpAndSettle();
    expect(find.byType(CiAnalysisView), findsOneWidget);
    expect(find.textContaining('Chưa xác định GitHub'), findsOneWidget);
    expect(find.text('Tóm tắt lỗi'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Chạy lại CI'),
    );
    expect(button.onPressed, isNull);
    expect(github.rerunCalls, 1);
    final nextRun = WorkflowRun.fromJson({
      ...runJson(
        github.details.run.id,
        attempt: github.details.run.attempt + 1,
      ),
      'status': 'in_progress',
      'conclusion': null,
    });
    github.latestRun = nextRun;
    github.details = WorkflowRunDetails(run: nextRun, jobs: []);
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(CiAnalysisView), findsNothing);
    expect(
      find.textContaining('Đang xem attempt ${nextRun.attempt}'),
      findsOneWidget,
    );
    expect(github.rerunCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Leaving analysis during log preparation does not open a late preview',
    (tester) async {
      final github = FakeActionsRepository();
      final ai = FakeCiRepository(github)
        ..prepareGate = Completer<CiAnalysisInput>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WorkflowRunDetailView(
            repo: savedRepo,
            run: github.details.run,
            repository: github,
            accessToken: 'fake',
            analysisRepository: ai,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Phân tích lỗi với Gemini'));
      await tester.tap(find.text('Phân tích lỗi với Gemini'));
      // Keep the preparation pending while opening and leaving the stack route.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CiAnalysisView), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(CiAnalysisView),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      ai.prepareGate!.complete(inputFor(github.details.run));
      await tester.pumpAndSettle();
      expect(find.byType(CiAnalysisView), findsNothing);
      expect(find.text('Log sẽ gửi cho Gemini'), findsNothing);
      expect(ai.analyzeCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Rerun menu requires confirmation and uses current commit', (
    tester,
  ) async {
    final github = FakeActionsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkflowRunDetailView(
          repo: savedRepo,
          run: github.details.run,
          repository: github,
          accessToken: 'fake',
          analysisRepository: FakeCiRepository(github),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thao tác CI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chạy lại các job lỗi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Commit: 1234567890abcdef'), findsOneWidget);
    expect(github.rerunCalls, 0);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(github.rerunCalls, 0);
    await tester.tap(find.byTooltip('Thao tác CI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chạy lại toàn bộ workflow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chạy lại'));
    await tester.pumpAndSettle();
    expect(github.rerunCalls, 1);
    expect(find.textContaining('Đã gửi yêu cầu chạy lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
