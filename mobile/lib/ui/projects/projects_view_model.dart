import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/github_repo.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/services/github_service.dart';

class ProjectsViewModel extends ChangeNotifier {
  ProjectsViewModel(
    this._repository, {
    required this.uid,
    required this.accessToken,
  });

  final ProjectRepository _repository;
  final String uid;
  final String? accessToken;

  List<Project> projects = [];
  List<GitHubRepo> githubRepositories = [];
  List<ProjectRepo> selectedRepositories = [];
  bool loadingProjects = false;
  bool loadingRepositories = false;
  bool saving = false;
  String projectError = '';
  String repositoryError = '';
  String saveError = '';
  String projectSearch = '';
  String repositorySearch = '';
  bool _disposed = false;

  List<Project> get visibleProjects {
    final search = projectSearch.trim().toLowerCase();
    return projects
        .where(
          (project) =>
              project.name.toLowerCase().contains(search) ||
              project.description.toLowerCase().contains(search),
        )
        .toList();
  }

  List<GitHubRepo> get visibleRepositories {
    final search = repositorySearch.trim().toLowerCase();
    return githubRepositories
        .where(
          (repo) =>
              repo.fullName.toLowerCase().contains(search) ||
              repo.description.toLowerCase().contains(search),
        )
        .toList();
  }

  Future<void> loadProjects() async {
    if (_disposed || loadingProjects) return;
    loadingProjects = true;
    projectError = '';
    notifyListeners();
    try {
      final result = await _repository.getProjects(uid);
      if (!_disposed) projects = result;
    } catch (error) {
      if (!_disposed) projectError = _errorMessage(error);
    } finally {
      if (!_disposed) {
        loadingProjects = false;
        notifyListeners();
      }
    }
  }

  // Opening a form never reads the old global follow preferences.
  void startEditing(Project? project) {
    selectedRepositories = [...?project?.repositories];
    repositorySearch = '';
    saveError = '';
  }

  Future<void> loadGitHubRepositories() async {
    if (_disposed || loadingRepositories) return;
    if (accessToken == null || accessToken!.isEmpty) {
      repositoryError = 'Chưa kết nối được GitHub. Bạn vẫn có thể lưu project; đăng nhập lại để thêm repo.';
      notifyListeners();
      return;
    }
    loadingRepositories = true;
    repositoryError = '';
    notifyListeners();
    try {
      final result = await _repository.getGitHubRepositories(accessToken!);
      if (!_disposed) githubRepositories = result;
    } on GitHubException catch (error) {
      if (!_disposed) {
        repositoryError = error.message;
        if (error.requiresSignIn) githubRepositories = [];
      }
    } catch (_) {
      if (!_disposed) {
        repositoryError = 'Chưa tải được repo GitHub. Hãy thử lại.';
      }
    } finally {
      if (!_disposed) {
        loadingRepositories = false;
        notifyListeners();
      }
    }
  }

  void toggleRepository(GitHubRepo repo) {
    if (_disposed || saving) return;
    if (selectedRepositories.any((item) => item.id == repo.id)) {
      removeRepository(repo.id);
      return;
    }
    if (selectedRepositories.length >= Project.maxRepositories ||
        !githubRepositories.any((item) => item.id == repo.id)) {
      return;
    }
    selectedRepositories = [
      ...selectedRepositories,
      ProjectRepo(id: repo.id, fullName: repo.fullName),
    ];
    notifyListeners();
  }

  void removeRepository(int id) {
    if (_disposed || saving) return;
    selectedRepositories = selectedRepositories
        .where((repo) => repo.id != id)
        .toList();
    notifyListeners();
  }

  Future<bool> saveProject({
    Project? project,
    required String name,
    required String description,
  }) async {
    if (_disposed || saving || loadingProjects) return false;
    saving = true;
    saveError = '';
    notifyListeners();
    try {
      final repos = [...selectedRepositories];
      if (project == null) {
        await _repository.createProject(uid, name, description, repos);
      } else {
        await _repository.updateProject(
          uid,
          project.id,
          name,
          description,
          repos,
        );
      }
      if (_disposed) return false;
      // A failed reload is shown on the list, not reported as a failed write.
      await loadProjects();
      if (!_disposed && projectError.isNotEmpty) {
        projectError = 'Project đã được lưu. $projectError';
      }
      return !_disposed;
    } catch (error) {
      if (!_disposed) saveError = _errorMessage(error);
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteProject(Project project) async {
    if (_disposed || saving || loadingProjects) return false;
    saving = true;
    saveError = '';
    notifyListeners();
    try {
      await _repository.deleteProject(uid, project.id);
      if (_disposed) return false;
      projects = projects.where((item) => item.id != project.id).toList();
      return true;
    } catch (error) {
      if (!_disposed) saveError = _errorMessage(error);
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void setProjectSearch(String value) {
    projectSearch = value;
    notifyListeners();
  }

  void setRepositorySearch(String value) {
    repositorySearch = value;
    notifyListeners();
  }

  String _errorMessage(Object error) {
    if (error is ArgumentError) return error.message.toString();
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'Chưa có quyền truy cập project. Hãy đăng nhập lại hoặc liên hệ người quản trị.',
        'unavailable' =>
          'Không kết nối được Firestore. Hãy kiểm tra mạng rồi thử lại.',
        'not-found' => 'Project không còn tồn tại. Hãy tải lại danh sách.',
        _ => 'Chưa hoàn tất thao tác với project. Hãy thử lại.',
      };
    }
    return 'Chưa hoàn tất thao tác với project. Hãy thử lại.';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
