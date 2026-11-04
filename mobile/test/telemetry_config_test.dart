import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/core/state/async_state.dart';
import 'package:vista_mobile/core/telemetry/app_telemetry.dart';
import 'package:vista_mobile/data/models/auth_identity.dart';
import 'package:vista_mobile/data/models/feature_config.dart';
import 'package:vista_mobile/data/models/project.dart';
import 'package:vista_mobile/data/models/user_profile.dart';
import 'package:vista_mobile/data/services/remote_config_service.dart';
import 'package:vista_mobile/data/services/telemetry_service.dart';
import 'package:vista_mobile/ui/auth/auth_view_model.dart';
import 'package:vista_mobile/ui/projects/project_detail_view_model.dart';
import 'package:vista_mobile/ui/projects/projects_view_model.dart';
import 'package:vista_mobile/ui/projects/workflow_run_view_model.dart';
import 'package:vista_mobile/ui/projects/workflow_run_detail_view.dart';
import 'package:vista_mobile/ui/settings/app_config_view_model.dart';
import 'package:vista_mobile/ui/settings/app_settings_panel.dart';

import 'auth_ui_test.dart' show FakeAuthRepository, testProfile;
import 'projects_test.dart' show FakeProjectRepository, savedRepo;
import 'github_actions_test.dart' show FakeActionsRepository;
import 'ci_analysis_test.dart' show FakeCiRepository;

class RecordingTelemetry extends AppTelemetry {
  final ids = <String?>[];
  final events = <AppEvent>[];
  final errors = <AppOperation>[];
  @override
  void identify(String? uid) => ids.add(uid);
  @override
  void event(AppEvent event, {Map<String, Object> parameters = const {}}) =>
      events.add(event);
  @override
  void nonFatal(Object error, StackTrace stack, AppOperation operation) =>
      errors.add(operation);
}

class DeferredAuthRepository extends FakeAuthRepository {
  @override
  Future<AuthIdentity> signInWithGitHub() async =>
      const AuthIdentity(uid: 'user-a', email: '', displayName: 'A');
}

class FakeAnalytics implements AnalyticsSink {
  final calls = <String>[];
  final payloads = <Map<String, Object>>[];
  Completer<void>? gate;
  bool failIdentity = false;
  @override
  Future<void> identify(String? uid) async {
    if (gate != null) await gate!.future;
    if (failIdentity) throw StateError('sensitive identity error');
    calls.add('uid:$uid');
  }

  @override
  Future<void> event(String name, Map<String, Object> parameters) async {
    calls.add(name);
    payloads.add(parameters);
  }
}

class FakeCrashes implements CrashSink {
  final calls = <String>[];
  final fatalFlags = <bool>[];
  @override
  Future<void> identify(String? uid) async {
    calls.add('uid:$uid');
  }

  @override
  Future<void> record(
    String safeError,
    StackTrace stack,
    AppOperation operation, {
    required bool fatal,
  }) async {
    calls.add(safeError);
    fatalFlags.add(fatal);
  }
}

class FakeConfig implements RemoteConfigSource {
  FeatureConfig value = FeatureConfig.defaults;
  Object? error;
  Completer<FeatureConfig>? gate;
  @override
  Future<FeatureConfig> fetch() async {
    if (error != null) throw error!;
    return gate == null ? value : gate!.future;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('OAuth completion before the auth stream still records login rather than restore', () async {
    final repository = DeferredAuthRepository();
    final telemetry = RecordingTelemetry();
    final model = AuthViewModel(repository, telemetry: telemetry);
    addTearDown(model.dispose);
    await flush();
    await model.signInWithGitHub();
    expect(telemetry.events, isEmpty);
    repository.emit(
      const AuthIdentity(uid: 'user-a', email: '', displayName: 'A'),
    );
    await flush();
    expect(telemetry.events, [AppEvent.login]);
  });

  test(
    'Events wait for identity changes and unknown parameters never reach SDK',
    () async {
      final analytics = FakeAnalytics()..gate = Completer<void>();
      final crashes = FakeCrashes();
      final telemetry = TelemetryService(analytics, crashes);
      addTearDown(telemetry.dispose);
      telemetry.identify('uid-a');
      telemetry.event(
        AppEvent.projectCreate,
        parameters: {
          'repo_count': 2,
          'email': 'secret@example.com',
          'repo': 'private/repo',
        },
      );
      telemetry.identify(null);
      telemetry.event(AppEvent.logout);
      await flush();
      expect(analytics.calls, isEmpty);
      analytics.gate!.complete();
      await telemetry.settled;
      expect(analytics.calls, [
        'uid:uid-a',
        'project_create',
        'uid:null',
        'logout',
      ]);
      expect(analytics.payloads.first, {'repo_count': 2});
      expect(crashes.calls, ['uid:uid-a', 'uid:null']);
    },
  );

  test('Non-fatal and fatal reports exclude raw exception payloads', () async {
    final crashes = FakeCrashes();
    final telemetry = TelemetryService(FakeAnalytics(), crashes);
    addTearDown(telemetry.dispose);
    final error = StateError(
      'token=ghp_secret email=private@example.com log body',
    );
    telemetry.nonFatal(error, StackTrace.current, AppOperation.analysisRun);
    telemetry.record(
      error,
      StackTrace.current,
      AppOperation.flutterFramework,
      fatal: true,
    );
    await telemetry.settled;
    expect(crashes.calls, [
      'analysisRun:StateError',
      'flutterFramework:StateError',
    ]);
    expect(crashes.fatalFlags, [false, true]);
  });

  test('Failed identity update suppresses analytics until a later identity succeeds', () async {
    final analytics = FakeAnalytics()..failIdentity = true;
    final telemetry = TelemetryService(analytics, FakeCrashes());
    addTearDown(telemetry.dispose);
    telemetry.identify(null);
    telemetry.event(AppEvent.projectDelete);
    await telemetry.settled;
    expect(analytics.calls, isEmpty);
    expect(telemetry.analyticsError, isNotEmpty);
    analytics.failIdentity = false;
    telemetry.identify('uid-b');
    telemetry.event(AppEvent.projectDelete);
    await telemetry.settled;
    expect(analytics.calls, ['uid:uid-b', 'project_delete']);
    expect(telemetry.analyticsError, isEmpty);
  });

  test(
    'Event schema rejects invalid counts and forces the known login method',
    () {
      expect(analyticsParameters(AppEvent.login, {'method': 'private email'}), {
        'method': 'github',
      });
      expect(
        analyticsParameters(AppEvent.projectCreate, {'repo_count': '5'}),
        isEmpty,
      );
      expect(
        analyticsParameters(AppEvent.projectCreate, {'repo_count': -1}),
        isEmpty,
      );
      expect(
        analyticsParameters(AppEvent.rerunRequested, {'failed_only': 8}),
        isEmpty,
      );
      expect(
        analyticsParameters(AppEvent.logout, {'email': 'private'}),
        isEmpty,
      );
    },
  );

  test('GitHub login is tracked once only after profile verification; reconnect does not duplicate', () async {
    final repository = FakeAuthRepository();
    final telemetry = RecordingTelemetry();
    final model = AuthViewModel(repository, telemetry: telemetry);
    addTearDown(model.dispose);
    await flush();
    await model.signInWithGitHub();
    await flush();
    expect(telemetry.ids, [testProfile.uid]);
    expect(telemetry.events, [AppEvent.login]);
    await model.signInWithGitHub();
    await flush();
    expect(telemetry.events, [AppEvent.login]);
    await model.signOut();
    await flush();
    expect(telemetry.ids.last, isNull);
    expect(telemetry.events.last, AppEvent.logout);
  });

  test('Restore waits for profile and clears telemetry identity when access is removed', () async {
    final profiles = StreamController<UserProfile>.broadcast();
    final repository = FakeAuthRepository()
      ..current = const AuthIdentity(uid: 'user-a', email: '', displayName: '')
      ..profileStream = profiles.stream;
    final telemetry = RecordingTelemetry();
    final model = AuthViewModel(repository, telemetry: telemetry);
    addTearDown(model.dispose);
    await flush();
    expect(telemetry.ids, isEmpty);
    profiles.add(testProfile);
    await flush();
    expect(telemetry.events, [AppEvent.sessionRestored]);
    profiles.add(
      const UserProfile(
        uid: 'user-a',
        email: '',
        displayName: '',
        role: Role.user,
        isActive: false,
      ),
    );
    await flush();
    expect(telemetry.ids, ['user-a', null]);
    expect(model.profile, isNull);
    await profiles.close();
  });

  test('Project tracking follows accepted writes and catch handlers record non-fatal errors', () async {
    final repository = FakeProjectRepository();
    final telemetry = RecordingTelemetry();
    final model = ProjectsViewModel(
      repository,
      uid: 'uid-a',
      accessToken: null,
      telemetry: telemetry,
    );
    addTearDown(model.dispose);
    expect(
      await model.saveProject(name: 'Private project', description: 'Private'),
      isTrue,
    );
    final saved = model.projects.single;
    expect(
      await model.saveProject(project: saved, name: 'Updated', description: ''),
      isTrue,
    );
    expect(await model.deleteProject(model.projects.single), isTrue);
    repository.writeError = StateError('private network error');
    expect(await model.saveProject(name: 'Failed', description: ''), isFalse);
    expect(telemetry.events, [
      AppEvent.projectCreate,
      AppEvent.projectUpdate,
      AppEvent.projectDelete,
    ]);
    expect(telemetry.errors, [AppOperation.projectWrite]);
  });

  test('Remote Config values are validated and fetch errors restore local defaults', () async {
    final telemetry = RecordingTelemetry();
    final source = FakeConfig()
      ..value = const FeatureConfig(analysisEnabled: false, repoPageSize: 2);
    final config = AppConfigViewModel(source, telemetry: telemetry);
    addTearDown(config.dispose);
    await config.refresh();
    expect(config.config.analysisEnabled, isFalse);
    expect(config.config.repoPageSize, 2);
    source.error = StateError('offline');
    await config.refresh();
    expect(config.state.status, LoadStatus.error);
    expect(config.config.analysisEnabled, isTrue);
    expect(config.config.repoPageSize, 5);
    expect(telemetry.errors, [AppOperation.remoteConfig]);
    expect(
      FeatureConfig.fromStrings({
        'ci_analysis_enabled': 'wrong',
        'project_repo_page_size': 'wrong',
      }).repoPageSize,
      5,
    );
    expect(
      FeatureConfig.fromStrings({'project_repo_page_size': '100'}).repoPageSize,
      20,
    );
    expect(
      FeatureConfig.fromStrings({'project_repo_page_size': '0'}).repoPageSize,
      1,
    );
  });

  test(
    'Remote Config changes repo pagination and blocks a prepared AI request',
    () async {
      final source = FakeConfig()..value = const FeatureConfig(repoPageSize: 2);
      final config = AppConfigViewModel(source);
      addTearDown(config.dispose);
      await config.refresh();
      final github = FakeActionsRepository();
      final overview = ProjectDetailViewModel(
        github,
        repositories: List.generate(
          6,
          (i) => ProjectRepo(id: i + 1, fullName: 'team/repo$i'),
        ),
        accessToken: 'fake',
        configuration: config,
      );
      addTearDown(overview.dispose);
      await overview.load();
      expect(overview.visibleCount, 2);
      await overview.load(more: true);
      expect(overview.visibleCount, 4);
      final analyses = FakeCiRepository(github);
      final telemetry = RecordingTelemetry();
      final run = WorkflowRunViewModel(
        github,
        repo: savedRepo,
        run: github.details.run,
        accessToken: 'fake',
        analysisRepository: analyses,
        configuration: config,
        telemetry: telemetry,
      );
      addTearDown(run.dispose);
      await run.load();
      await flush();
      await run.prepareAnalysis();
      expect(run.preparedAnalysis, isNotNull);
      source.value = const FeatureConfig(
        analysisEnabled: false,
        repoPageSize: 3,
      );
      await config.refresh();
      expect(run.canAnalyze, isFalse);
      await run.analyze();
      expect(analyses.analyzeCalls, 0);
      await overview.load();
      expect(overview.visibleCount, 3);
      source.value = const FeatureConfig(
        analysisEnabled: true,
        repoPageSize: 3,
      );
      await config.refresh();
      await run.analyze();
      expect(analyses.analyzeCalls, 1);
      expect(
        telemetry.events,
        containsAllInOrder([
          AppEvent.workflowDetailView,
          AppEvent.analysisStart,
          AppEvent.analysisComplete,
        ]),
      );
    },
  );

  testWidgets(
    'Config values and fallback errors are observable in Profile settings',
    (tester) async {
      final source = FakeConfig();
      final config = AppConfigViewModel(source);
      addTearDown(config.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppSettingsPanel(configuration: config),
            ),
          ),
        ),
      );
      expect(find.text('Phân tích CI mới: Bật'), findsOneWidget);
      source.value = const FeatureConfig(
        analysisEnabled: false,
        repoPageSize: 2,
      );
      await tester.tap(find.text('Cập nhật cấu hình'));
      await tester.pumpAndSettle();
      expect(find.text('Phân tích CI mới: Tắt'), findsOneWidget);
      expect(find.text('Repo mỗi trang tổng quan: 2'), findsOneWidget);
      source.error = StateError('offline');
      await tester.tap(find.text('Cập nhật cấu hình'));
      await tester.pumpAndSettle();
      expect(find.textContaining('giá trị mặc định'), findsOneWidget);
      expect(find.text('Phân tích CI mới: Bật'), findsOneWidget);
    },
  );

  testWidgets('Disabled AI has a visible message on a real run screen', (
    tester,
  ) async {
    final source = FakeConfig()
      ..value = const FeatureConfig(analysisEnabled: false);
    final config = AppConfigViewModel(source);
    addTearDown(config.dispose);
    await config.refresh();
    final github = FakeActionsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkflowRunDetailView(
          repo: savedRepo,
          run: github.details.run,
          repository: github,
          accessToken: 'fake',
          analysisRepository: FakeCiRepository(github),
          configuration: config,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Tính năng phân tích CI mới đang tạm tắt.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Debug crash requires confirmation and non-fatal test keeps app open',
    (tester) async {
      var crashes = 0;
      final telemetry = RecordingTelemetry();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppSettingsPanel(
                telemetry: telemetry,
                onDebugCrash: () => crashes++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Gửi lỗi non-fatal thử nghiệm'));
      await tester.pumpAndSettle();
      expect(telemetry.errors, [AppOperation.debugTest]);
      expect(find.textContaining('Đã xếp hàng'), findsOneWidget);
      await tester.tap(find.text('Thử crash ứng dụng'));
      await tester.pumpAndSettle();
      expect(crashes, 0);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(crashes, 0);
      await tester.tap(find.text('Thử crash ứng dụng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử crash'));
      await tester.pumpAndSettle();
      expect(crashes, 1);
    },
  );
}
