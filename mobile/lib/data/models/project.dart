import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.repositories,
    this.createdAt,
    this.updatedAt,
  });

  static const maxNameLength = 100;
  static const maxDescriptionLength = 1000;
  static const maxRepositories = 50;

  final String id;
  final String name;
  final String description;
  final List<ProjectRepo> repositories;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromFirestore(String id, Map<String, dynamic> data) =>
      Project(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String,
        repositories: (data['repositories'] as List<dynamic>)
            .map(
              (item) => ProjectRepo.fromFirestore(item as Map<String, dynamic>),
            )
            .toList(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
}

/// A project's saved selection. Detailed repo data still comes from GitHub.
class ProjectRepo {
  const ProjectRepo({required this.id, required this.fullName});
  final int id;
  final String fullName;
  Uri get githubUrl => Uri.https('github.com', fullName);

  factory ProjectRepo.fromFirestore(Map<String, dynamic> data) =>
      ProjectRepo(id: data['id'] as int, fullName: data['fullName'] as String);

  Map<String, dynamic> toFirestore() => {'id': id, 'fullName': fullName};
}
