import '../models/user_profile.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_profile_service.dart';

class AuthRepository {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final FirestoreProfileService _profiles = FirestoreProfileService();

  String? get githubAccessToken => _auth.githubAccessToken;

  Future<UserProfile> signInWithGitHub() async {
    final identity = await _auth.signInWithGitHub();
    final name = identity.displayName.trim();
    final initialData = CreateProfileData(
      displayName: name.isEmpty
          ? 'Vista User'
          : String.fromCharCodes(name.runes.take(100)),
    );

    final data = await _profiles.getOrCreateProfile(
      identity.uid,
      initialData.toFirestore(),
    );

    return UserProfile.fromFirestore(
      uid: identity.uid,
      email: identity.email,
      data: data,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
