import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreProjectService {
  CollectionReference<Map<String, dynamic>> _projects(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('projects');

  Future<QuerySnapshot<Map<String, dynamic>>> getProjects(String uid) =>
      _projects(uid)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));

  Future<void> createProject(String uid, Map<String, dynamic> data) async {
    await _projects(uid).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProject(
    String uid,
    String projectId,
    Map<String, dynamic> data,
  ) =>
      _projects(uid)
          .doc(projectId)
          .update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> deleteProject(String uid, String projectId) =>
      _projects(uid).doc(projectId).delete();
}
