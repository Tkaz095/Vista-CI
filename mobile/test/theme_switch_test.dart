import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vista_mobile/data/models/user_profile.dart';
import 'package:vista_mobile/data/models/auth_identity.dart';
import 'package:vista_mobile/data/repositories/auth_repository.dart';
import 'package:vista_mobile/ui/auth/auth_view.dart';
import 'package:vista_mobile/ui/auth/auth_view_model.dart';
import 'package:vista_mobile/ui/theme/app_theme.dart';
import 'package:vista_mobile/ui/theme/app_theme_controller.dart';

const testProfile = UserProfile(
  uid: 'user-a',
  email: 'linh@example.com',
  displayName: 'Linh',
  role: Role.user,
  isActive: true,
);

class FakeAuthRepository implements AuthRepository {
  @override
  String? githubAccessToken;
  final sessions = StreamController<AuthIdentity?>.broadcast();
  AuthIdentity? current;
  UserProfile savedProfile = testProfile;

  @override
  Stream<AuthIdentity?> authStateChanges() async* {
    yield current;
    yield* sessions.stream;
  }

  @override
  Stream<UserProfile> watchProfile(AuthIdentity identity) => Stream.value(savedProfile);

  @override
  Future<AuthIdentity> signInWithGitHub() async {
    const identity = AuthIdentity(uid: 'user-a', email: 'linh@example.com', displayName: 'Linh');
    githubAccessToken = null; // Reconnect button visible!
    current = identity;
    sessions.add(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    githubAccessToken = null;
    current = null;
    sessions.add(null);
  }

  @override
  Future<String> uploadAvatar({required String uid, required dynamic bytes, required String fileExtension}) async => '';

  @override
  Future<void> removeAvatar({required String uid, String? currentUrl}) async {}

  @override
  Future<void> updateDisplayName({required String uid, required String displayName}) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Switch from dark to light and back on ProfileView with Reconnect', (tester) async {
    final repo = FakeAuthRepository();
    final model = AuthViewModel(repo);
    await tester.pump();
    await model.signInWithGitHub();

    await AppThemeController.instance.setThemeMode(ThemeMode.dark);

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: AppThemeController.instance,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppThemeController.instance.themeMode,
          home: AuthView(viewModel: model),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Go to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Phiên Vista đã được khôi phục'), findsOneWidget);
    expect(find.text('Kết nối lại GitHub'), findsOneWidget);

    // Switch from dark to light
    await AppThemeController.instance.setThemeMode(ThemeMode.light);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Switch from light to dark
    await AppThemeController.instance.setThemeMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Switch back to light
    await AppThemeController.instance.setThemeMode(ThemeMode.light);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  });
}
