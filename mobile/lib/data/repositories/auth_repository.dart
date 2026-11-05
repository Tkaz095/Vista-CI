import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../models/auth_identity.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_profile_service.dart';

class AuthRepository {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final FirestoreProfileService _profiles = FirestoreProfileService();
  final FirebaseStorageService _storage = FirebaseStorageService();

  String? get githubAccessToken => _auth.githubAccessToken;

  Stream<AuthIdentity?> authStateChanges() => _auth.authStateChanges();

  Future<AuthIdentity> signInWithGitHub() => _auth.signInWithGitHub();

  Stream<UserProfile> watchProfile(AuthIdentity identity) async* {
    final name = identity.displayName.trim();
    final currentUser = FirebaseAuth.instance.currentUser;
    final authPhotoUrl = currentUser?.photoURL;

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
            authPhotoUrl: authPhotoUrl,
          ),
        );
  }

  /// Uploads avatar image to Firebase Storage, then synchronizes photoUrl with Firestore & Firebase Auth.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final downloadUrl = await _storage.uploadAvatar(
      uid: uid,
      bytes: bytes,
      fileExtension: fileExtension,
    );

    // Update Firebase Auth user
    try {
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(downloadUrl);
    } catch (_) {}

    // Update Firestore user document
    try {
      await _profiles.updateProfile(uid, {'photoUrl': downloadUrl});
    } catch (_) {}

    return downloadUrl;
  }

  /// Removes avatar from Firebase Storage, Firestore and Firebase Auth.
  Future<void> removeAvatar({
    required String uid,
    String? currentUrl,
  }) async {
    if (currentUrl != null && currentUrl.isNotEmpty) {
      await _storage.deleteAvatarByUrl(currentUrl);
    }

    try {
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
    } catch (_) {}

    try {
      await _profiles.updateProfile(uid, {'photoUrl': null});
    } catch (_) {}
  }

  /// Updates user display name in Firestore and Firebase Auth.
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tên hiển thị không được để trống');
    }

    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(trimmed);
    } catch (_) {}

    try {
      await _profiles.updateProfile(uid, {'displayName': trimmed});
    } catch (_) {}
  }

  Future<void> signOut() => _auth.signOut();
}
