import 'package:vista_mobile/data/models/auth_identity.dart';
import 'package:vista_mobile/data/services/firebase_auth_service.dart';

class AuthRepository {
  AuthRepository(this._authService);

  final FirebaseAuthService _authService;

  Stream<AuthIdentity?> get identities {
    return _authService.watchAuthState().map((user) {
      if (user == null) return null;

      return AuthIdentity(
        uid: user.uid,
        email: user.email ?? ' ',
        displayName: user.displayName ?? ' ',
      );
    });
  }

  Future<void> signInWithGitHub() async {
    try {
      await _authService.signInWithGitHub();
    } catch (error) {
      throw Exception(error);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

