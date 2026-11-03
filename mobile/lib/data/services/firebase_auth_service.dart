import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> watchAuthState() {
    return _auth.authStateChanges();
  }

  Future<User> signInWithGitHub() async {
    final githubProvider = GithubAuthProvider();

    final userCredential = await _auth.signInWithProvider(githubProvider);

    final user = userCredential.user;
    if (user == null) {
      throw StateError("Firebase returned no user");
    }

    return userCredential.user!;
  }

  Future<void> signOut() {
    return _auth.signOut();
  }
}
