import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreProfileService {
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _fireStore.collection('users').doc(uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String uid) {
    return _profileRef(uid).snapshots(
      includeMetadataChanges: true,
    );
  }

  /// Returns true when created, or false if the profile already exists.
  Future<bool> createProfileIfMissing(
    String uid,
    Map<String, dynamic> initialData,
  ) {
    final reference = _profileRef(uid);

    return _fireStore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(reference);

      if (snapshot.exists) {
        return false;
      }

      transaction.set(reference, initialData);
      return true;
    });
  }
}
