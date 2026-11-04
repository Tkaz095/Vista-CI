import '../models/github_repo.dart';
import '../models/project.dart';
import '../services/firestore_project_service.dart';
import '../services/github_service.dart';

class ProjectRepository {
  final GitHubService _github = GitHubService();
  final FirestoreProjectService _projects = FirestoreProjectService();

  Future<List<GitHubRepo>> getGitHubRepositories(String accessToken) =>
      _github.fetchRepositories(accessToken);

  Future<List<Project>> getProjects(String uid) async {
    final snapshot = await _projects.getProjects(uid);
    return snapshot.docs
        .map((doc) => Project.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<void> createProject(
    String uid,
    String name,
    String description,
    List<ProjectRepo> repositories,
  ) async {
    await _projects.createProject(
      uid,
      _projectData(name, description, repositories),
    );
  }

  Future<void> updateProject(
    String uid,
    String projectId,
    String name,
    String description,
    List<ProjectRepo> repositories,
  ) async {
    await _projects.updateProject(
      uid,
      projectId,
      _projectData(name, description, repositories),
    );
  }

  Future<void> deleteProject(String uid, String projectId) =>
      _projects.deleteProject(uid, projectId);

  Map<String, dynamic> _projectData(
    String name,
    String description,
    List<ProjectRepo> repositories,
  ) {
    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    if (trimmedName.isEmpty || trimmedName.length > Project.maxNameLength) {
      throw ArgumentError(
        'Tên project cần từ 1 đến ${Project.maxNameLength} ký tự.',
      );
    }
    if (trimmedDescription.length > Project.maxDescriptionLength) {
      throw ArgumentError(
        'Mô tả tối đa ${Project.maxDescriptionLength} ký tự.',
      );
    }
    if (repositories.length > Project.maxRepositories) {
      throw ArgumentError(
        'Mỗi project có tối đa ${Project.maxRepositories} repo.',
      );
    }
    final repoIds = <int>{};
    final fullNamePattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
    for (final repo in repositories) {
      if (repo.id <= 0 ||
          repo.fullName.length > 201 ||
          !fullNamePattern.hasMatch(repo.fullName)) {
        throw ArgumentError(
          'Thông tin repo chưa hợp lệ. Hãy đồng bộ GitHub lại.',
        );
      }
      if (!repoIds.add(repo.id)) {
        throw ArgumentError('Project có repo bị trùng.');
      }
    }
    return {
      'name': trimmedName,
      'description': trimmedDescription,
      'repositories': repositories.map((repo) => repo.toFirestore()).toList(),
    };
  }
}
