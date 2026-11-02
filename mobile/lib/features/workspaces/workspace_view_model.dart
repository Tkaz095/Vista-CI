import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'workspace_repository.dart';

class VistaWorkspace {
  VistaWorkspace(this.id, this.name, this.description, this.status);
  final String id, name, description, status;
}

class VistaRepository {
  VistaRepository(
    this.id,
    this.name,
    this.description,
    this.fullName,
    this.htmlUrl,
  );
  final String id, name, description, fullName, htmlUrl;
}

String _text(dynamic value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel(this.uid, this.repository) {
    reload();
  }
  final String uid;
  final WorkspaceRepository repository;
  List<VistaWorkspace> workspaces = [];
  List<VistaRepository> repositories = [];
  String? selectedId;
  String? _requestedId;
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
      ? 'Chưa có quyền đọc workspace. Hãy publish Firestore Rules ownerUid mới cho project vista-ci, database (default).'
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
    _requestedId = selectedId;
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
                    _text(doc.data()['status'], 'active'),
                  ),
                )
                .toList();
            if (!workspaces.any((w) => w.id == selectedId)) _clearSelection();
            final requested = _requestedId;
            if (requested != null && workspaces.any((w) => w.id == requested)) {
              _requestedId = null;
              select(requested);
            }
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

  void selectWhenAvailable(String id) {
    if (workspaces.any((w) => w.id == id)) {
      select(id);
    } else {
      _requestedId = id;
    }
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
                    _text(doc.data()['displayName'], doc.id),
                    _text(doc.data()['note'], ''),
                    _text(doc.data()['fullName'], ''),
                    _text(doc.data()['htmlUrl'], ''),
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
