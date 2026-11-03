import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_identity.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // GitHub's token is separate from the Firebase session. Keep it in memory only.
  String? _githubAccessToken;
  String? get githubAccessToken => _githubAccessToken;

  Future<AuthIdentity> signInWithGitHub() async {
    _githubAccessToken = null;
    final provider = GithubAuthProvider()..addScope('repo');
    final result = await _auth.signInWithProvider(provider);
    final user = result.user;
    if (user == null) throw StateError('Firebase returned no user');
    _githubAccessToken = result.credential?.accessToken;

    return AuthIdentity(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _githubAccessToken = null;
  }
}
