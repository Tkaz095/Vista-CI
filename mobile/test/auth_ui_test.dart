import 'dart:ui' show PointerDeviceKind;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/features/auth/session_view_model.dart';
import 'package:vista_mobile/features/auth/session_views.dart';
import 'package:vista_mobile/main.dart';

class FakeAuthRepository implements AuthRepository {
  String? submittedEmail, submittedPassword;
  int calls = 0;
  @override
  Stream<User?> get sessions => Stream.value(null);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      const Stream.empty();
  @override
  Future<void> login(String email, String password) async {
    calls++;
    submittedEmail = email.trim();
    submittedPassword = password;
  }

  @override
  Future<void> logout() async {}
  @override
  Future<void> loginWithGitHub() async {}
  @override
  bool get githubLinked => false;
  @override
  Future<void> linkGitHub() async {}
  @override
  Future<void> ensureOwnProfile(User user, bool Function() isCurrent) async {}
}

void main() {
  testWidgets('A signed-out session opens login instead of the static Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SessionGate(repository: FakeAuthRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Vista'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Login scrolls above keyboard on a small screen and submits credentials',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = FakeAuthRepository();
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const VistaScrollBehavior(),
          home: LoginScreen(repository: repository),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, ' student@example.com ');
      await tester.enterText(fields.last, 'secret-test');
      final button = find.widgetWithText(OutlinedButton, 'Đăng nhập');
      await tester.scrollUntilVisible(
        button,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(repository.submittedEmail, 'student@example.com');
      expect(repository.submittedPassword, 'secret-test');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Mouse drag scrolls overflowing mobile content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const VistaScrollBehavior(),
        home: Scaffold(
          body: ScrollPage(
            children: List.generate(
              30,
              (index) => SizedBox(height: 80, child: Text('Row $index')),
            ),
          ),
        ),
      ),
    );
    final scrollable = find.byType(Scrollable).first;
    final state = tester.state<ScrollableState>(scrollable);
    expect(state.position.pixels, 0);
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -250),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(0));
  });

  testWidgets('Empty input does not call Firebase login', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(repository: repository)),
    );
    final button = find.widgetWithText(OutlinedButton, 'Đăng nhập');
    await tester.scrollUntilVisible(
      button,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu.'), findsOneWidget);
  });
}
