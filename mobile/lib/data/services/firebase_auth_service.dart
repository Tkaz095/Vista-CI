import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_identity.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<AuthIdentity> signInWithGitHub() async {
    final result = await _auth.signInWithProvider(GithubAuthProvider());
    final user = result.user;
    if (user == null) throw StateError('Firebase returned no user');

    return AuthIdentity(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    );
  }

  Future<void> signOut() => _auth.signOut();
}
