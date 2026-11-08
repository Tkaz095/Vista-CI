import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/data/models/user_profile.dart';
import 'package:vista_mobile/data/models/auth_identity.dart';
import 'package:vista_mobile/core/state/async_state.dart';
import 'package:vista_mobile/ui/projects/project_form_view.dart';
import 'package:vista_mobile/data/repositories/auth_repository.dart';
import 'package:vista_mobile/main.dart';
import 'package:vista_mobile/ui/auth/auth_view.dart';
import 'package:vista_mobile/ui/auth/auth_view_model.dart';
import 'package:vista_mobile/ui/home/home_view.dart';
import 'package:vista_mobile/ui/theme/app_theme.dart';
import 'package:vista_mobile/ui/widgets/app_bottom_tab.dart';
import 'package:vista_mobile/ui/widgets/app_header.dart';
import 'package:vista_mobile/ui/widgets/app_stack_header.dart';

const testProfile = UserProfile(
  uid: 'user-a',
  email: 'linh@example.com',
  displayName: 'Linh',
  role: Role.user,
  isActive: true,
);

// UI tests replace the repository, without adding test options to production services.
class FakeAuthRepository implements AuthRepository {
  @override
  String? githubAccessToken;
  final sessions = StreamController<AuthIdentity?>.broadcast();
  AuthIdentity? current;
  UserProfile savedProfile = testProfile;
  Stream<UserProfile>? profileStream;
  final profileStreams = <String, Stream<UserProfile>>{};

  @override
  Stream<AuthIdentity?> authStateChanges() async* {
    yield current;
    yield* sessions.stream;
  }

  @override
  Stream<UserProfile> watchProfile(AuthIdentity identity) {
    return profileStreams[identity.uid] ??
        profileStream ??
        Stream.value(savedProfile);
  }

  Completer<UserProfile>? result;
  Object? signOutError;
  int signInCalls = 0;
  int signOutCalls = 0;

  void emit(AuthIdentity? identity) {
    current = identity;
    sessions.add(identity);
  }

  @override
  Future<AuthIdentity> signInWithGitHub() async {
    signInCalls++;
    savedProfile = result == null ? testProfile : await result!.future;
    final identity = AuthIdentity(
      uid: savedProfile.uid,
      email: savedProfile.email,
      displayName: savedProfile.displayName,
    );
    githubAccessToken = 'fake-token';
    emit(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    githubAccessToken = null;
    emit(null);
  }

  @override
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileExtension,
  }) async => 'https://example.com/avatar.jpg';

  @override
  Future<void> removeAvatar({required String uid, String? currentUrl}) async {}

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {}
}

void main() {
  late FakeAuthRepository repository;
  late AuthViewModel model;

  setUp(() {
    repository = FakeAuthRepository();
  });

  var providerOwnsModel = false;
  tearDown(() {
    if (!providerOwnsModel) model.dispose();
    providerOwnsModel = false;
  });

  const identityA = AuthIdentity(
    uid: 'user-a',
    email: 'linh@example.com',
    displayName: 'Linh',
  );
  const identityB = AuthIdentity(uid: 'user-b', email: '', displayName: 'B');
  const profileB = UserProfile(
    uid: 'user-b',
    email: '',
    displayName: 'B',
    role: Role.user,
    isActive: true,
  );

  testWidgets(
    'Provider restores a session only after server profile verification',
    (tester) async {
      providerOwnsModel = true;
      repository.current = identityA;
      final profiles = StreamController<UserProfile>();
      repository.profileStream = profiles.stream;
      await tester.pumpWidget(
        MaterialApp(home: SessionGate(repository: repository)),
      );
      await tester.pump();
      expect(find.text('Đang xác minh phiên đăng nhập…'), findsOneWidget);
      expect(find.byType(HomeView), findsNothing);
      profiles.add(testProfile);
      await tester.pumpAndSettle();
      expect(find.byType(HomeView), findsOneWidget);
      expect(repository.signInCalls, 0);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Kết nối lại GitHub'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(profiles.hasListener, isFalse);
      unawaited(profiles.close());
      await tester.pump();
    },
  );

  testWidgets(
    'External logout removes the complete protected navigation stack',
    (tester) async {
      model = AuthViewModel(repository);
      await tester.pump();
      await model.signInWithGitHub();
      await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tạo project'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectFormView), findsOneWidget);
      repository.emit(null);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectFormView), findsNothing);
      expect(find.byType(HomeView), findsNothing);
      expect(find.text('Đăng nhập Vista'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProjectFormView), findsNothing);
    },
  );

  testWidgets('An inactive profile removes an open route immediately', (
    tester,
  ) async {
    final profiles = StreamController<UserProfile>.broadcast();
    repository.profileStream = profiles.stream;
    repository.current = identityA;
    model = AuthViewModel(repository);
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    profiles.add(testProfile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tạo project'));
    await tester.pumpAndSettle();
    profiles.add(
      const UserProfile(
        uid: 'user-a',
        email: '',
        displayName: 'A',
        role: Role.user,
        isActive: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProjectFormView), findsNothing);
    expect(find.byType(HomeView), findsNothing);
    expect(find.textContaining('vô hiệu hóa'), findsOneWidget);
    unawaited(profiles.close());
    await tester.pump();
  });

  testWidgets('Late data from user A cannot replace user B', (tester) async {
    final profilesA = StreamController<UserProfile>.broadcast();
    final profilesB = StreamController<UserProfile>.broadcast();
    repository.profileStreams['user-a'] = profilesA.stream;
    repository.profileStreams['user-b'] = profilesB.stream;
    repository.current = identityA;
    model = AuthViewModel(repository);
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    await tester.pump();
    repository.emit(identityB);
    await tester.pump();
    profilesB.add(profileB);
    await tester.pumpAndSettle();
    profilesA.add(testProfile);
    await tester.pumpAndSettle();
    expect(model.profile?.uid, 'user-b');
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsWidgets);
    expect(find.text(testProfile.email), findsNothing);
    unawaited(profilesA.close());
    await tester.pump();
    unawaited(profilesB.close());
    await tester.pump();
  });

  testWidgets('Profile read failure blocks Home and retry recovers', (
    tester,
  ) async {
    final profiles = StreamController<UserProfile>.broadcast();
    repository.current = identityA;
    repository.profileStream = profiles.stream;
    model = AuthViewModel(repository);
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    await tester.pump();
    profiles.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeView), findsNothing);
    expect(find.textContaining('Chưa có quyền'), findsOneWidget);
    await tester.tap(find.text('Kiểm tra lại'));
    await tester.pump();
    profiles.add(testProfile);
    await tester.pumpAndSettle();
    expect(find.byType(HomeView), findsOneWidget);
    unawaited(profiles.close());
    await tester.pump();
  });

  testWidgets('Unknown roles are blocked and profile timeout has a way out', (
    tester,
  ) async {
    final profiles = StreamController<UserProfile>.broadcast();
    repository.current = identityA;
    repository.profileStream = profiles.stream;
    model = AuthViewModel(
      repository,
      sessionTimeout: const Duration(seconds: 2),
    );
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa xác minh được hồ sơ'), findsOneWidget);
    expect(find.byType(HomeView), findsNothing);
    profiles.add(
      const UserProfile(
        uid: 'user-a',
        email: '',
        displayName: 'A',
        role: Role.unknown,
        isActive: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(model.state.status, LoadStatus.error);
    expect(find.textContaining('chưa được cấp quyền'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Vista'), findsOneWidget);
    unawaited(profiles.close());
    await tester.pump();
  });

  testWidgets(
    'Reconnecting GitHub preserves the Vista session when OAuth is cancelled',
    (tester) async {
      repository.current = identityA;
      model = AuthViewModel(repository);
      await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      repository.result = Completer<UserProfile>();
      await tester.tap(find.text('Kết nối lại GitHub'));
      await tester.pump();
      expect(model.busy, isTrue);
      repository.result!.completeError(
        FirebaseAuthException(code: 'web-context-cancelled'),
      );
      await tester.pumpAndSettle();
      expect(model.profile?.uid, identityA.uid);
      expect(find.byType(HomeView), findsOneWidget);
      expect(find.textContaining('Bạn đã hủy'), findsOneWidget);
      repository.result = null;
      await tester.scrollUntilVisible(find.text('Kết nối lại GitHub'), 100);
      await tester.tap(find.text('Kết nối lại GitHub'));
      await tester.pumpAndSettle();
      expect(model.githubAccessToken, isNotNull);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Kết nối lại GitHub'), findsNothing);
    },
  );

  testWidgets('The app starts with a GitHub-only login', (tester) async {
    model = AuthViewModel(repository);
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthView(viewModel: model),
      ),
    );
    expect(find.text('Đăng nhập Vista'), findsOneWidget);
    expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(HomeView), findsNothing);
  });

  testWidgets('GitHub login opens Home and logout returns to login', (
    tester,
  ) async {
    model = AuthViewModel(repository);
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthView(viewModel: model),
      ),
    );
    await tester.tap(find.text('Tiếp tục với GitHub'));
    await tester.pumpAndSettle();
    expect(repository.signInCalls, 1);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBottomTab), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 120);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repository.signOutCalls, 1);
    expect(find.byType(HomeView), findsNothing);
    expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
  });

  testWidgets(
    'Pending login cannot be submitted twice and cancellation is readable',
    (tester) async {
      model = AuthViewModel(repository);
      await tester.pump();
      repository.result = Completer<UserProfile>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthView(viewModel: model),
        ),
      );
      await tester.tap(find.text('Tiếp tục với GitHub'));
      await tester.pump();
      expect(find.text('Đang xác thực…'), findsOneWidget);
      await model.signInWithGitHub();
      expect(repository.signInCalls, 1);

      repository.result!.completeError(
        FirebaseAuthException(code: 'web-context-cancelled'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn đã hủy'), findsOneWidget);
      expect(find.byType(HomeView), findsNothing);
    },
  );

  testWidgets(
    'A Firestore failure keeps login open and allows another attempt',
    (tester) async {
      model = AuthViewModel(repository);
      await tester.pump();
      repository.result = Completer<UserProfile>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthView(viewModel: model),
        ),
      );
      await tester.tap(find.text('Tiếp tục với GitHub'));
      repository.result!.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có quyền'), findsOneWidget);
      expect(find.byType(HomeView), findsNothing);

      repository.result = null;
      await tester.tap(find.text('Tiếp tục với GitHub'));
      await tester.pumpAndSettle();
      expect(repository.signInCalls, 2);
      expect(find.byType(HomeView), findsOneWidget);
    },
  );

  testWidgets('Failed logout keeps the user on Home', (tester) async {
    model = AuthViewModel(repository);
    await tester.pump();
    await model.signInWithGitHub();
    repository.signOutError = FirebaseAuthException(
      code: 'network-request-failed',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthView(viewModel: model),
      ),
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 120);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.textContaining('Kiểm tra mạng'), findsOneWidget);
  });

  testWidgets('Login scrolls on a small screen with large text', (
    tester,
  ) async {
    model = AuthViewModel(repository);
    await tester.pump();
    tester.view.physicalSize = const Size(320, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: AuthView(viewModel: model),
      ),
    );
    await tester.scrollUntilVisible(find.text('Tiếp tục với GitHub'), 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A completed request cannot update a disposed ViewModel', (
    tester,
  ) async {
    model = AuthViewModel(repository);
    await tester.pump();
    repository.result = Completer<UserProfile>();
    final pendingModel = AuthViewModel(repository);
    final request = pendingModel.signInWithGitHub();
    pendingModel.dispose();
    repository.result!.complete(testProfile);
    await request;
    expect(pendingModel.profile, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home remains usable on a narrow screen with large text', (
    tester,
  ) async {
    model = AuthViewModel(repository);
    await tester.pump();
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await model.signInWithGitHub();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: AuthView(viewModel: model),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 120);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Vista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tabs preserve project search and stack screens return to Home', (
    tester,
  ) async {
    model = AuthViewModel(repository);
    await tester.pump();
    await model.signInWithGitHub();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthView(viewModel: model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'vista');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'vista',
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text(testProfile.email), findsOneWidget);
    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBottomTab), findsOneWidget);
    expect(find.byType(AppStackHeader), findsNothing);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'vista',
    );

    await tester.tap(find.byTooltip('Tạo project'));
    await tester.pumpAndSettle();
    expect(find.byType(AppStackHeader), findsOneWidget);
    expect(find.byType(AppBottomTab), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mouse drag scrolls overflowing content', (tester) async {
    model = AuthViewModel(repository);
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        scrollBehavior: const VistaScrollBehavior(),
        home: Scaffold(
          body: ListView(
            children: List.generate(
              30,
              (index) => SizedBox(height: 80, child: Text('Row $index')),
            ),
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -250),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
  });
}
