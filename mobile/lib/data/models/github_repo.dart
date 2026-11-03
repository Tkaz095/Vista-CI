/// A source repository on GitHub, not the MVVM data repository class.
class GitHubRepo {
  const GitHubRepo({
    required this.id,
    required this.fullName,
    required this.isPrivate,
    this.description = '',
    this.language = '',
    this.defaultBranch = '',
    this.isArchived = false,
  });

  final int id;
  final String fullName;
  final bool isPrivate;
  final String description;
  final String language;
  final String defaultBranch;
  final bool isArchived;

  Uri get githubUrl => Uri.https('github.com', fullName);

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    isPrivate: json['private'] as bool,
    description: json['description'] as String? ?? '',
    language: json['language'] as String? ?? '',
    defaultBranch: json['default_branch'] as String? ?? '',
    isArchived: json['archived'] == true,
  );
}
