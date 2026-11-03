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
}
