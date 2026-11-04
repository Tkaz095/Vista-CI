import '../models/user_profile.dart';
import '../models/auth_identity.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_profile_service.dart';

class AuthRepository {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final FirestoreProfileService _profiles = FirestoreProfileService();

  String? get githubAccessToken => _auth.githubAccessToken;

  Stream<AuthIdentity?> authStateChanges() => _auth.authStateChanges();

  Future<AuthIdentity> signInWithGitHub() => _auth.signInWithGitHub();

  Stream<UserProfile> watchProfile(AuthIdentity identity) async* {
    final name = identity.displayName.trim();
    final initialData = CreateProfileData(
      displayName: name.isEmpty
          ? 'Vista User'
          : String.fromCharCodes(name.runes.take(100)),
    );

    await _profiles.getOrCreateProfile(
      identity.uid,
      initialData.toFirestore(),
      isCurrent: () => _auth.isCurrent(identity.uid),
    );

    yield* _profiles
        .watchProfile(identity.uid)
        .map(
          (data) => UserProfile.fromFirestore(
            uid: identity.uid,
            email: identity.email,
            data: data,
          ),
        );
  }

  Future<void> signOut() => _auth.signOut();
}
