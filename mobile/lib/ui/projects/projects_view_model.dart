import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../settings/app_config_view_model.dart';
import '../../core/errors/project_error_message.dart';

import '../../data/models/github_repo.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/services/github_service.dart';

class ProjectsViewModel extends ChangeNotifier {
  ProjectsViewModel(
    this._repository, {
    required this.uid,
    required this.accessToken,
    this.telemetry,
    this.configuration,
  });

  AsyncState<List<Project>> get projectsState => AsyncState.resolve(
    data: List.unmodifiable(projects),
    loading: loadingProjects,
    empty: projects.isEmpty,
    error: projectError,
  );
  AsyncState<List<GitHubRepo>> get repositoriesState => AsyncState.resolve(
    data: List.unmodifiable(githubRepositories),
    loading: loadingRepositories,
    empty: githubRepositories.isEmpty,
    error: repositoryError,
  );

  final ProjectRepository _repository;
  final AppTelemetry? telemetry;
  final AppConfigViewModel? configuration;
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
    } catch (error, stack) {
      if (!_disposed) {
        telemetry?.nonFatal(error, stack, AppOperation.projectRead);
      }
      if (!_disposed) projectError = projectErrorMessage(error);
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
    } on GitHubException catch (error, stack) {
      if (!_disposed) {
        telemetry?.nonFatal(error, stack, AppOperation.repositoryRead);
      }
      if (!_disposed) {
        repositoryError = error.message;
        if (error.requiresSignIn) githubRepositories = [];
      }
    } catch (error, stack) {
      if (!_disposed) {
        telemetry?.nonFatal(error, stack, AppOperation.repositoryRead);
      }
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

  void restoreRepositorySelection(List<ProjectRepo> previous) {
    if (_disposed || saving) return;
    selectedRepositories = [...previous];
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
      telemetry?.event(
        project == null ? AppEvent.projectCreate : AppEvent.projectUpdate,
        parameters: {'repo_count': repos.length},
      );
      // A failed reload is shown on the list, not reported as a failed write.
      await loadProjects();
      if (!_disposed && projectError.isNotEmpty) {
        projectError = 'Project đã được lưu. $projectError';
      }
      return !_disposed;
    } catch (error, stack) {
      if (!_disposed) {
        telemetry?.nonFatal(error, stack, AppOperation.projectWrite);
      }
      if (!_disposed) saveError = projectErrorMessage(error);
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
      telemetry?.event(AppEvent.projectDelete);
      return true;
    } catch (error, stack) {
      if (!_disposed) {
        telemetry?.nonFatal(error, stack, AppOperation.projectWrite);
      }
      if (!_disposed) saveError = projectErrorMessage(error);
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
