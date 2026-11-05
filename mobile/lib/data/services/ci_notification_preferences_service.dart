import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/project.dart';
import '../models/ci_notification_mode.dart';

abstract interface class CiNotificationPreferences {
  Stream<CiNotificationMode> watch(String uid, ProjectRepo repo);
  Future<void> save(String uid, ProjectRepo repo, CiNotificationMode mode);
}

class CiNotificationPreferencesService implements CiNotificationPreferences {
  void _check(String uid) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Session changed');
    }
  }

  DocumentReference<Map<String, dynamic>> _document(
    String uid,
    ProjectRepo repo,
  ) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('ciSubscriptions')
      .doc('${repo.id}');
  @override
  Stream<CiNotificationMode> watch(String uid, ProjectRepo repo) {
    _check(uid);
    return _document(uid, repo)
        .snapshots(includeMetadataChanges: true)
        .where(
          (snapshot) =>
              !snapshot.metadata.hasPendingWrites &&
              (snapshot.exists || !snapshot.metadata.isFromCache),
        )
        .map((snapshot) {
          _check(uid);
          if (!snapshot.exists) return CiNotificationMode.failures;
          final data = snapshot.data()!;
          if (data['repoId'] != '${repo.id}') {
            throw StateError('Repository mismatch');
          }
          return CiNotificationMode.parse(data['mode'] as String);
        });
  }

  @override
  Future<void> save(
    String uid,
    ProjectRepo repo,
    CiNotificationMode mode,
  ) async {
    _check(uid);
    await _document(uid, repo)
        .set({
          'repoId': '${repo.id}',
          'repoFullName': repo.fullName,
          'mode': mode.value,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
    _check(uid);
  }
}
