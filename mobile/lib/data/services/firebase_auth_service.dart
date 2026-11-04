import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_identity.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // GitHub's token is separate from the Firebase session. Keep it in memory only.
  String? _githubAccessToken;
  String? _tokenUid;
  bool isCurrent(String uid) => _auth.currentUser?.uid == uid;
  String? get githubAccessToken =>
      _tokenUid == _auth.currentUser?.uid ? _githubAccessToken : null;

  Stream<AuthIdentity?> authStateChanges() =>
      _auth.authStateChanges().map((user) {
        if (user?.uid != _tokenUid) {
          _githubAccessToken = null;
          _tokenUid = null;
        }
        return user == null ? null : _identity(user);
      });

  AuthIdentity _identity(User user) => AuthIdentity(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? '',
  );

  Future<AuthIdentity> signInWithGitHub() async {
    final provider = GithubAuthProvider()
      ..addScope('repo')
      ..setCustomParameters({'prompt': 'select_account'});
    final current = _auth.currentUser;
    final result = current == null
        ? await _auth.signInWithProvider(provider)
        : await current.reauthenticateWithProvider(provider);
    final user = result.user;
    if (user == null) throw StateError('Firebase returned no user');
    if (_auth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    _githubAccessToken = result.credential?.accessToken;
    _tokenUid = user.uid;
    return _identity(user);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _githubAccessToken = null;
    _tokenUid = null;
  }
}
