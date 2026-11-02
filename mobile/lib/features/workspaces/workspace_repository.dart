import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../github/github_repository.dart';

class WorkspaceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>> workspaces(String uid) => _db
      .collection('workspaces')
      .where('ownerUid', isEqualTo: uid)
      .snapshots(includeMetadataChanges: true);
  CollectionReference<Map<String, dynamic>> repoRef(String id) =>
      _db.collection('workspaces').doc(id).collection('repositories');
  Stream<QuerySnapshot<Map<String, dynamic>>> repositories(String id) =>
      repoRef(id).snapshots(includeMetadataChanges: true);
  void _identity(String uid) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw Exception('Phiên tài khoản đã thay đổi.');
    }
  }

  Map<String, dynamic> _fields(String name, String description) {
    name = name.trim();
    description = description.trim();
    if (name.isEmpty || name.length > 100 || description.length > 1000) {
      throw Exception('Tên cần 1–100 ký tự; mô tả tối đa 1000 ký tự.');
    }
    return {'name': name, 'description': description};
  }

  Map<String, dynamic> _repo(GitHubRepo repo) => {
    'githubRepositoryId': repo.id,
    'fullName': repo.fullName,
    'htmlUrl': repo.htmlUrl,
    'defaultBranch': repo.defaultBranch,
    'private': repo.isPrivate,
    'displayName': String.fromCharCodes(repo.fullName.runes.take(100)),
    'note': '',
    'addedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
  Future<String> create(
    String uid,
    String name,
    String description,
    List<GitHubRepo> repos,
  ) async {
    _identity(uid);
    if (repos.length > 100) {
      throw Exception('Chọn tối đa 100 repo mỗi lần; có thể thêm tiếp sau.');
    }
    final reference = _db.collection('workspaces').doc();
    final batch = _db.batch();
    batch.set(reference, {
      ..._fields(name, description),
      'ownerUid': uid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final repo in repos) {
      batch.set(reference.collection('repositories').doc(repo.id), _repo(repo));
    }
    await batch.commit();
    return reference.id;
  }

  Future<void> edit(
    String uid,
    String id,
    String name,
    String description,
  ) async {
    _identity(uid);
    await _db.doc('workspaces/$id').update({
      ..._fields(name, description),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addRepo(String uid, String id, GitHubRepo repo) async {
    _identity(uid);
    final reference = repoRef(id).doc(repo.id);
    await _db.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) transaction.set(reference, _repo(repo));
    });
  }

  Future<void> editRepo(
    String uid,
    String id,
    String repoId,
    String displayName,
    String note,
  ) async {
    _identity(uid);
    displayName = displayName.trim();
    note = note.trim();
    if (displayName.isEmpty || displayName.length > 100 || note.length > 1000) {
      throw Exception('Nhãn cần 1–100 ký tự; ghi chú tối đa 1000 ký tự.');
    }
    await repoRef(id).doc(repoId).update({
      'displayName': displayName,
      'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeRepo(String uid, String id, String repoId) async {
    _identity(uid);
    await repoRef(id).doc(repoId).delete();
  }

  Future<void> remove(String uid, String id) async {
    _identity(uid);
    final reference = _db.doc('workspaces/$id');
    await _db.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      if (snapshot.data()?['ownerUid'] != uid) {
        throw Exception('Bạn không sở hữu workspace này.');
      }
      transaction.update(reference, {
        'status': 'deleting',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    while (true) {
      _identity(uid);
      final children = await repoRef(id)
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (children.docs.isEmpty) break;
      final batch = _db.batch();
      for (final child in children.docs) {
        batch.delete(child.reference);
      }
      await batch.commit();
    }
    _identity(uid);
    await reference.delete();
  }
}
