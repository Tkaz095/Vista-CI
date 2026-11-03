import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/data/models/user_profile.dart';
import 'package:vista_mobile/data/repositories/auth_repository.dart';
import 'package:vista_mobile/main.dart';
import 'package:vista_mobile/ui/auth/auth_view.dart';
import 'package:vista_mobile/ui/auth/auth_view_model.dart';
import 'package:vista_mobile/ui/home/home_view.dart';

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
  String? get githubAccessToken => null;

  Completer<UserProfile>? result;
  Object? signOutError;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<UserProfile> signInWithGitHub() async {
    signInCalls++;
    return result == null ? testProfile : await result!.future;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
  }
}

void main() {
  late FakeAuthRepository repository;
  late AuthViewModel model;

  setUp(() {
    repository = FakeAuthRepository();
    model = AuthViewModel(repository);
  });

  tearDown(() => model.dispose());

  testWidgets('The app starts with a GitHub-only login', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    expect(find.text('Đăng nhập Vista'), findsOneWidget);
    expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(HomeView), findsNothing);
  });

  testWidgets('GitHub login opens Home and logout returns to login', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    await tester.tap(find.text('Tiếp tục với GitHub'));
    await tester.pumpAndSettle();
    expect(repository.signInCalls, 1);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text(testProfile.email), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repository.signOutCalls, 1);
    expect(find.byType(HomeView), findsNothing);
    expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
  });

  testWidgets(
    'Pending login cannot be submitted twice and cancellation is readable',
    (tester) async {
      repository.result = Completer<UserProfile>();
      await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
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
      repository.result = Completer<UserProfile>();
      await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
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
    await model.signInWithGitHub();
    repository.signOutError = FirebaseAuthException(
      code: 'network-request-failed',
    );
    await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: model)));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.textContaining('Kiểm tra mạng'), findsOneWidget);
  });

  testWidgets('Login scrolls on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
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
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await model.signInWithGitHub();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: AuthView(viewModel: model),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Vista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mouse drag scrolls overflowing content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
