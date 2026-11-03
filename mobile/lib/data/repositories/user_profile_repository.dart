import 'package:vista_mobile/data/models/auth_identity.dart';
import 'package:vista_mobile/data/models/user_profile.dart';
import 'package:vista_mobile/data/services/firestore_profile_service.dart';

class UserProfileRepository {
  final FirestoreProfileService _userProfileService;
  UserProfileRepository(this._userProfileService);

  Stream<ProfileObservation> watchProject(AuthIdentity identity) {
    return _userProfileService.watchProfile(identity.uid).map((snapshot) {
      final profileData = snapshot.data();

      return ProfileObservation(
        profile: profileData == null
            ? null
            : UserProfile.fromFirestore(
                uid: identity.uid,
                email: identity.email,
                data: profileData,
              ),
        serverConfirmed:
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      );
    });
  }

  Future<bool> createProfile(String uid, CreateProfileData data) {
    return _userProfileService.createProfileIfMissing(uid, data.toFirestore());
  }
}
