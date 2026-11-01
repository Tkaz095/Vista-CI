import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class VistaWorkspace {
  VistaWorkspace(this.id, this.name, this.description);
  final String id, name, description;
}

class VistaRepository {
  VistaRepository(this.id, this.name, this.description);
  final String id, name, description;
}

String _text(dynamic value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

class WorkspaceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>> workspaces(String uid) => _db
      .collection('workspaces')
      .where('memberUids', arrayContains: uid)
      .limit(50)
      .snapshots(includeMetadataChanges: true);
  Stream<QuerySnapshot<Map<String, dynamic>>> repositories(
    String workspaceId,
  ) => _db
      .collection('workspaces')
      .doc(workspaceId)
      .collection('repositories')
      .limit(50)
      .snapshots(includeMetadataChanges: true);
}

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel(this.uid, this.repository) {
    reload();
  }
  final String uid;
  final WorkspaceRepository repository;
  List<VistaWorkspace> workspaces = [];
  List<VistaRepository> repositories = [];
  String? selectedId;
  bool loading = true, repositoriesLoading = false;
  String error = '', repositoriesError = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _workspaces,
      _repositories;
  Timer? _workspaceDeadline, _repoDeadline;
  bool _disposed = false;
  int _generation = 0, _repoGeneration = 0;
  VistaWorkspace? get selected {
    for (final workspace in workspaces) {
      if (workspace.id == selectedId) return workspace;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _failure(Object cause) =>
      cause is FirebaseException && cause.code == 'permission-denied'
      ? 'Chưa có quyền đọc workspace. Hãy cập nhật Firestore Rules theo tài liệu bước 12.'
      : 'Không tải được dữ liệu. Kiểm tra mạng và thử lại.';
  void _clearSelection() {
    _repoGeneration++;
    _repositories?.cancel();
    _repoDeadline?.cancel();
    selectedId = null;
    repositories = [];
    repositoriesError = '';
    repositoriesLoading = false;
  }

  void reload() {
    final generation = ++_generation;
    _workspaces?.cancel();
    _workspaceDeadline?.cancel();
    _clearSelection();
    workspaces = [];
    loading = true;
    error = '';
    _notify();
    _workspaceDeadline = Timer(const Duration(seconds: 15), () {
      if (_disposed || generation != _generation) return;
      loading = false;
      error = 'Chưa nhận được danh sách từ máy chủ. Kiểm tra mạng rồi thử lại.';
      _notify();
    });
    _workspaces = repository
        .workspaces(uid)
        .listen(
          (snapshot) {
            if (_disposed ||
                generation != _generation ||
                snapshot.metadata.isFromCache ||
                snapshot.metadata.hasPendingWrites) {
              return;
            }
            _workspaceDeadline?.cancel();
            loading = false;
            error = '';
            workspaces = snapshot.docs
                .map(
                  (doc) => VistaWorkspace(
                    doc.id,
                    _text(doc.data()['name'], doc.id),
                    _text(doc.data()['description'], ''),
                  ),
                )
                .toList();
            if (!workspaces.any((w) => w.id == selectedId)) _clearSelection();
            _notify();
          },
          onError: (Object cause) {
            if (_disposed || generation != _generation) return;
            _workspaceDeadline?.cancel();
            _clearSelection();
            workspaces = [];
            loading = false;
            error = _failure(cause);
            _notify();
          },
        );
  }

  void select(String id) {
    if (!workspaces.any((w) => w.id == id)) return;
    _clearSelection();
    selectedId = id;
    final generation = _repoGeneration;
    repositoriesLoading = true;
    _notify();
    _repoDeadline = Timer(const Duration(seconds: 15), () {
      if (_disposed || generation != _repoGeneration) return;
      repositoriesLoading = false;
      repositoriesError =
          'Chưa nhận được repository từ máy chủ. Kiểm tra mạng rồi thử lại.';
      _notify();
    });
    _repositories = repository
        .repositories(id)
        .listen(
          (snapshot) {
            if (_disposed ||
                generation != _repoGeneration ||
                snapshot.metadata.isFromCache ||
                snapshot.metadata.hasPendingWrites) {
              return;
            }
            _repoDeadline?.cancel();
            repositoriesLoading = false;
            repositoriesError = '';
            repositories = snapshot.docs
                .map(
                  (doc) => VistaRepository(
                    doc.id,
                    _text(doc.data()['name'], doc.id),
                    _text(doc.data()['description'], ''),
                  ),
                )
                .toList();
            _notify();
          },
          onError: (Object cause) {
            if (_disposed || generation != _repoGeneration) return;
            _repoDeadline?.cancel();
            repositories = [];
            repositoriesLoading = false;
            repositoriesError = _failure(cause);
            _notify();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _repoGeneration++;
    _workspaces?.cancel();
    _repositories?.cancel();
    _workspaceDeadline?.cancel();
    _repoDeadline?.cancel();
    super.dispose();
  }
}
