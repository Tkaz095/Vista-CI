import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>> watchProfile(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) throw StateError('Profile no longer exists');
        return data;
      });

  /// Creates a new document, or returns the existing data without overwriting it.
  Future<Map<String, dynamic>> getOrCreateProfile(
    String uid,
    Map<String, dynamic> initialData, {
    required bool Function() isCurrent,
  }) {
    final reference = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
      if (!isCurrent()) throw StateError('Session changed');
      final snapshot = await transaction.get(reference);
      if (!isCurrent()) throw StateError('Session changed');
      final existingData = snapshot.data();
      if (existingData != null) return existingData;

      transaction.set(reference, initialData);
      return initialData;
    });
  }
}
