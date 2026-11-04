import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads avatar image bytes to Firebase Storage under `avatars/{uid}/avatar_{timestamp}.{ext}`
  /// and returns the public download URL.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final contentType = cleanExt == 'png' ? 'image/png' : 'image/jpeg';
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';
    final ref = _storage.ref().child('avatars').child(uid).child(fileName);

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedBy': uid,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final uploadTask = ref.putData(bytes, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Deletes an avatar file by URL if it belongs to Firebase Storage.
  Future<void> deleteAvatarByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Ignored for non-firebase or already removed avatars
    }
  }
}

