import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/data/models/github_repo.dart';
import 'package:vista_mobile/data/models/project.dart';
import 'package:vista_mobile/data/repositories/project_repository.dart';
import 'package:vista_mobile/data/services/github_service.dart';
import 'package:vista_mobile/ui/projects/project_form_view.dart';
import 'package:vista_mobile/ui/projects/projects_view.dart';
import 'package:vista_mobile/ui/projects/projects_view_model.dart';

import 'auth_ui_test.dart' show testProfile;

const publicRepo = GitHubRepo(
  id: 1,
  fullName: 'linh/mobile',
  isPrivate: false,
  description: 'Ứng dụng Flutter',
  language: 'Dart',
);
const privateRepo = GitHubRepo(id: 2, fullName: 'team/api', isPrivate: true);
const savedRepo = ProjectRepo(id: 1, fullName: 'linh/mobile');
const testProject = Project(
  id: 'project-a',
  name: 'Vista',
  description: 'Đồ án',
  repositories: [savedRepo],
);

class FakeProjectRepository implements ProjectRepository {
  List<Project> savedProjects = [];
  List<GitHubRepo> githubRepos = [publicRepo, privateRepo];
  Object? loadError;
  Object? githubError;
  Object? writeError;
  Completer<List<Project>>? pendingLoad;
  Completer<void>? pendingWrite;
  int loadCalls = 0;
  int githubCalls = 0;
  int writeCalls = 0;
  int nextId = 1;
  final List<String> requestedUids = [];

  @override
  Future<List<Project>> getProjects(String uid) async {
    requestedUids.add(uid);
    loadCalls++;
    if (loadError != null) throw loadError!;
    return pendingLoad == null ? [...savedProjects] : await pendingLoad!.future;
  }

  @override
  Future<List<GitHubRepo>> getGitHubRepositories(String accessToken) async {
    githubCalls++;
    if (githubError != null) throw githubError!;
    return githubRepos;
  }

  @override
  Future<void> createProject(
    String uid,
    String name,
    String description,
    List<ProjectRepo> repositories,
  ) async {
    requestedUids.add(uid);
    writeCalls++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (writeError != null) throw writeError!;
    savedProjects = [
      Project(
        id: 'created-${nextId++}',
        name: name.trim(),
        description: description.trim(),
        repositories: [...repositories],
      ),
      ...savedProjects,
    ];
  }

  @override
  Future<void> updateProject(
    String uid,
    String projectId,
    String name,
    String description,
    List<ProjectRepo> repositories,
  ) async {
    requestedUids.add(uid);
    writeCalls++;
    if (writeError != null) throw writeError!;
    savedProjects = savedProjects
        .map(
          (project) => project.id == projectId
              ? Project(
                  id: projectId,
                  name: name.trim(),
                  description: description.trim(),
                  repositories: [...repositories],
                )
              : project,
        )
        .toList();
  }

  @override
  Future<void> deleteProject(String uid, String projectId) async {
    requestedUids.add(uid);
    writeCalls++;
    if (writeError != null) throw writeError!;
    savedProjects.removeWhere((project) => project.id == projectId);
  }
}

void main() {
  late FakeProjectRepository repository;
  late ProjectsViewModel model;
  setUp(() {
    repository = FakeProjectRepository();
    model = ProjectsViewModel(
      repository,
      uid: testProfile.uid,
      accessToken: 'fake-token',
    );
  });
  tearDown(() => model.dispose());

  test(
    'Firestore models preserve repo IDs and server dates without credentials',
    () {
      final time = DateTime.utc(2026, 11, 4);
      final project = Project.fromFirestore('a', {
        'name': 'Vista',
        'description': '',
        'repositories': [savedRepo.toFirestore()],
        'createdAt': Timestamp.fromDate(time),
        'updatedAt': Timestamp.fromDate(time),
      });
      expect(project.createdAt?.toUtc(), time);
      expect(project.updatedAt?.toUtc(), time);
      expect(project.repositories.single.id, 1);
      expect(
        project.repositories.single.githubUrl.toString(),
        'https://github.com/linh/mobile',
      );
      expect(savedRepo.toFirestore(), {'id': 1, 'fullName': 'linh/mobile'});
    },
  );

  test('Repository rejects invalid input before contacting Firebase', () async {
    final realRepository = ProjectRepository();
    for (final invalidName in ['', '   ', 'a' * 101]) {
      await expectLater(
        realRepository.createProject('a', invalidName, '', []),
        throwsArgumentError,
      );
    }
    await expectLater(
      realRepository.createProject('a', 'Valid', 'x' * 1001, []),
      throwsArgumentError,
    );
    await expectLater(
      realRepository.createProject('a', 'Valid', '', [savedRepo, savedRepo]),
      throwsArgumentError,
    );
    await expectLater(
      realRepository.createProject('a', 'Valid', '', [
        const ProjectRepo(id: 0, fullName: 'bad'),
      ]),
      throwsArgumentError,
    );
    await expectLater(
      realRepository.createProject(
        'a',
        'Valid',
        '',
        List.generate(
          51,
          (id) => ProjectRepo(id: id + 1, fullName: 'team/repo-$id'),
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'Projects load without a GitHub token and use the signed-in UID',
    () async {
      repository.savedProjects = [testProject];
      final noTokenModel = ProjectsViewModel(
        repository,
        uid: 'another-user',
        accessToken: null,
      );
      addTearDown(noTokenModel.dispose);
      await noTokenModel.loadProjects();
      expect(noTokenModel.projects.single.id, testProject.id);
      expect(repository.requestedUids, ['another-user']);
      expect(repository.githubCalls, 0);
    },
  );

  test(
    'Create empty projects and reuse one repo across different projects',
    () async {
      model.startEditing(null);
      expect(await model.saveProject(name: 'Empty', description: ''), isTrue);
      expect(model.projects.single.repositories, isEmpty);
      await model.loadGitHubRepositories();
      model.toggleRepository(publicRepo);
      expect(await model.saveProject(name: 'One', description: ''), isTrue);
      model.startEditing(null);
      model.toggleRepository(publicRepo);
      expect(await model.saveProject(name: 'Two', description: ''), isTrue);
      expect(model.projects.length, 3);
      expect(
        model.projects.take(2).every((p) => p.repositories.single.id == 1),
        isTrue,
      );
      expect(repository.requestedUids.toSet(), {testProfile.uid});
    },
  );

  test(
    'GitHub failures keep selected repos and do not prevent project edits',
    () async {
      const missingRepo = ProjectRepo(id: 99, fullName: 'old/private');
      const project = Project(
        id: 'a',
        name: 'Old',
        description: '',
        repositories: [savedRepo, missingRepo],
      );
      repository.savedProjects = [project];
      await model.loadProjects();
      model.startEditing(project);
      repository.githubError = const GitHubException(
        'Sign in again',
        requiresSignIn: true,
      );
      await model.loadGitHubRepositories();
      expect(model.selectedRepositories.map((r) => r.id), [1, 99]);
      expect(model.repositoryError, isNotEmpty);
      model.removeRepository(99);
      expect(
        await model.saveProject(
          project: project,
          name: 'Renamed',
          description: '',
        ),
        isTrue,
      );
      expect(model.projects.single.name, 'Renamed');
      expect(model.projects.single.repositories.single.id, 1);
    },
  );

  test(
    'Failed load preserves the last list; failed write preserves draft',
    () async {
      repository.savedProjects = [testProject];
      await model.loadProjects();
      repository.loadError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await model.loadProjects();
      expect(model.projects, [testProject]);
      expect(model.projectError, contains('kiểm tra mạng'));
      repository.loadError = null;
      model.startEditing(testProject);
      repository.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(
        await model.saveProject(
          project: testProject,
          name: 'Changed',
          description: '',
        ),
        isFalse,
      );
      expect(model.selectedRepositories.single.id, 1);
      expect(model.projects.single.name, 'Vista');
      expect(model.saveError, contains('Chưa có quyền'));
    },
  );

  test(
    'Successful write remains successful when the following reload fails',
    () async {
      repository.loadError = StateError('Network lost after write');
      expect(await model.saveProject(name: 'Saved', description: ''), isTrue);
      expect(repository.savedProjects.single.name, 'Saved');
      expect(model.saveError, isEmpty);
      expect(model.projectError, contains('Project đã được lưu'));
      expect(repository.writeCalls, 1);
    },
  );

  test('Duplicate reads and late results after disposal are ignored', () async {
    repository.pendingLoad = Completer<List<Project>>();
    final pendingModel = ProjectsViewModel(
      repository,
      uid: 'a',
      accessToken: null,
    );
    final request = pendingModel.loadProjects();
    await pendingModel.loadProjects();
    expect(repository.loadCalls, 1);
    pendingModel.dispose();
    repository.pendingLoad!.complete([testProject]);
    await request;
    expect(pendingModel.projects, isEmpty);
  });

  test(
    'Repo selection is unique and bounded, and search does not change it',
    () async {
      repository.githubRepos = List.generate(
        51,
        (id) =>
            GitHubRepo(id: id + 1, fullName: 'team/repo-$id', isPrivate: false),
      );
      await model.loadGitHubRepositories();
      for (final repo in repository.githubRepos) {
        model.toggleRepository(repo);
      }
      expect(model.selectedRepositories, hasLength(Project.maxRepositories));
      model.setRepositorySearch('REPO-50');
      expect(model.visibleRepositories.single.id, 51);
      expect(model.selectedRepositories, hasLength(50));
      model.toggleRepository(repository.githubRepos.first);
      expect(model.selectedRepositories, hasLength(49));
      model.toggleRepository(repository.githubRepos.last);
      expect(model.selectedRepositories.last.id, 51);
    },
  );

  test(
    'Duplicate saves are ignored and disposal ignores late results',
    () async {
      repository.pendingWrite = Completer<void>();
      final savingModel = ProjectsViewModel(
        repository,
        uid: 'a',
        accessToken: null,
      );
      final request = savingModel.saveProject(name: 'One', description: '');
      expect(
        await savingModel.saveProject(name: 'Two', description: ''),
        isFalse,
      );
      expect(repository.writeCalls, 1);
      savingModel.dispose();
      repository.pendingWrite!.complete();
      expect(await request, isFalse);
      expect(savingModel.projects, isEmpty);
    },
  );

  test('Failed deletes keep the project; successful deletes only remove that project', () async {
    repository.savedProjects = [testProject];
    await model.loadProjects();
    repository.writeError = StateError('Denied');
    expect(await model.deleteProject(testProject), isFalse);
    expect(model.projects, [testProject]);
    repository.writeError = null;
    expect(await model.deleteProject(testProject), isTrue);
    expect(model.projects, isEmpty);
    expect(repository.githubCalls, 0);
  });

  testWidgets('Create, search, edit and delete a project through the UI', (
    tester,
  ) async {
    await model.loadProjects();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectsView(viewModel: model, profile: testProfile),
        ),
      ),
    );
    await tester.tap(find.text('Tạo project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu project'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên project.'), findsOneWidget);
    expect(repository.writeCalls, 0);
    await tester.enterText(find.byType(TextFormField).first, 'Đồ án Flutter');
    await tester.scrollUntilVisible(
      find.text('Tìm repo'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).last, 'TEAM');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(CheckboxListTile, 'team/api'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(CheckboxListTile, 'team/api'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lưu project'),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lưu project'));
    await tester.pumpAndSettle();
    expect(repository.savedProjects.single.repositories.single.id, 2);
    expect(find.text('Đồ án Flutter'), findsOneWidget);
    await tester.tap(find.text('Đồ án Flutter'));
    await tester.pumpAndSettle();
    expect(find.text('team/api'), findsOneWidget);
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Project mới');
    await tester.scrollUntilVisible(
      find.byTooltip('Bỏ team/api'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Bỏ team/api'));
    await tester.scrollUntilVisible(
      find.text('Lưu project'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lưu project'));
    await tester.pumpAndSettle();
    expect(find.text('Project mới'), findsOneWidget);
    expect(find.text('Repo trong project (0)'), findsOneWidget);
    await tester.tap(find.text('Xóa project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(repository.savedProjects, hasLength(1));
    await tester.tap(find.text('Xóa project'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Xóa project'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.savedProjects, isEmpty);
    expect(find.textContaining('Chưa có project.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Firestore failure keeps the form, text and selected repos for retry',
    (tester) async {
      repository.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectFormView(viewModel: model, project: testProject),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Giữ dữ liệu');
      await tester.tap(find.text('Lưu project'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có quyền'), findsOneWidget);
      expect(find.text('Giữ dữ liệu'), findsOneWidget);
      expect(model.selectedRepositories.single.id, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Form fits a narrow screen with large text and long repo names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository.githubRepos = [
      GitHubRepo(
        id: 3,
        fullName: 'organization-with-a-long-name/repository-with-a-long-name',
        isPrivate: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: ProjectFormView(viewModel: model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(InputChip),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
