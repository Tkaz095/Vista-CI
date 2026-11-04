import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new document, or returns the existing data without overwriting it.
  Future<Map<String, dynamic>> getOrCreateProfile(
    String uid,
    Map<String, dynamic> initialData,
  ) {
    final reference = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
      final snapshot = await transaction.get(reference);
      final existingData = snapshot.data();
      if (existingData != null) return existingData;

      transaction.set(reference, initialData);
      return initialData;
    });
  }

  /// Updates specific fields in user profile.
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final reference = _firestore.collection('users').doc(uid);
    await reference.set(data, SetOptions(merge: true));
  }

  /// Fetches the profile data from Firestore.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }
}
