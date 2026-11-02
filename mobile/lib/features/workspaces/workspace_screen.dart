import 'package:shared_preferences/shared_preferences.dart';

import '../github/backend_panel.dart';
import '../cicd/cicd_screen.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/session_view_model.dart';
import '../auth/session_views.dart';
import '../github/github_panel.dart';
import '../github/github_view_model.dart';
import 'repository_card.dart';
import 'workspace_repository.dart';
import 'workspace_view_model.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.profile, required this.auth});
  final VistaProfile profile;
  final AuthRepository auth;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final repository = WorkspaceRepository();
  late final model = WorkspaceViewModel(widget.profile.uid, repository);
  final github = GitHubViewModel();
  final name = TextEditingController(), description = TextEditingController();
  final form = GlobalKey<FormState>();
  final picked = <String>{};
  int tab = 0;
  String ciRepo = '';
  bool addingRepository = false;
  Future<void> _saving = Future<void>.value();
  @override
  void initState() {
    super.initState();
    unawaited(restoreNavigation());
    model.addListener(persistNavigation);
  }

  Future<void> restoreNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final key = 'vista.navigation.${widget.profile.uid}';
    final savedTab = prefs.getInt('$key.tab') ?? 0;
    setState(() {
      tab = savedTab >= 0 && savedTab <= 2 ? savedTab : 0;
      ciRepo = prefs.getString('$key.repo') ?? '';
    });
    final workspace = prefs.getString('$key.workspace');
    if (workspace != null && workspace.isNotEmpty) {
      model.selectWhenAvailable(workspace);
    }
  }

  void persistNavigation() {
    final uid = widget.profile.uid,
        savedTab = tab,
        repo = ciRepo,
        workspace = model.selectedId;
    _saving = _saving.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance(),
          key = 'vista.navigation.$uid';
      await prefs.setInt('$key.tab', savedTab);
      await prefs.setString('$key.repo', repo);
      if (workspace != null) await prefs.setString('$key.workspace', workspace);
    });
  }

  void openRepo(String repo) {
    setState(() {
      ciRepo = repo;
      tab = 1;
    });
    persistNavigation();
  }

  void reloadGitHub() {
    github.reset();
    unawaited(github.load());
  }

  bool busy = false, creating = false, confirmingDelete = false;
  String? editingId;
  String message = '';
  bool get locked => busy || github.pending;
  @override
  void dispose() {
    model.removeListener(persistNavigation);
    model.dispose();
    github.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<bool> act(Future<void> Function() job) async {
    if (busy) return false;
    setState(() {
      busy = true;
      message = '';
    });
    final slow = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(
          () => message = 'Chưa nhận được xác nhận từ máy chủ. Vẫn đang chờ; giữ kết nối và không gửi lại.',
        );
      }
    });
    try {
      await job();
      if (mounted) setState(() => message = 'Đã hoàn tất thao tác.');
      return true;
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is FirebaseException
              ? error.code == 'permission-denied'
                    ? 'Chưa có quyền thao tác. Publish Rules ownerUid mới ở project vista-ci, database (default).'
                    : 'Không hoàn tất thao tác Firestore. Kiểm tra mạng rồi thử lại.'
              : error.toString().replaceFirst('Exception: ', ''),
        );
      }
      return false;
    } finally {
      slow.cancel();
      if (mounted) setState(() => busy = false);
    }
  }

  void startCreate() {
    setState(() {
      creating = true;
      editingId = null;
      name.clear();
      description.clear();
      picked.clear();
      tab = 0;
    });
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    String? id;
    final ok = await act(() async {
      if (creating) {
        id = await repository.create(
          widget.profile.uid,
          name.text,
          description.text,
          github.repos.where((repo) => picked.contains(repo.id)).toList(),
        );
      } else {
        await repository.edit(
          widget.profile.uid,
          editingId!,
          name.text,
          description.text,
        );
      }
    });
    if (mounted && ok) {
      setState(() {
        creating = false;
        editingId = null;
        picked.clear();
      });
      if (id != null) model.selectWhenAvailable(id!);
    }
  }

  Widget githubPanel({bool selecting = false}) => GitHubPanel(
    model: github,
    disabled: busy,
    picked: selecting ? picked : null,
    onToggle: (id) => setState(() {
      if (!picked.remove(id)) picked.add(id);
    }),
    onReset: () => setState(picked.clear),
    onAdd: model.selected == null || model.selected!.status != 'active'
        ? null
        : (repo) => act(
            () =>
                repository.addRepo(widget.profile.uid, model.selectedId!, repo),
          ),
  );
  List<Widget> editPage() => [
    Text(
      creating ? 'Tạo workspace' : 'Sửa workspace',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: name,
            enabled: !locked,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tên workspace'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên workspace.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: description,
            enabled: !locked,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Mô tả'),
          ),
          if (creating) ...[
            githubPanel(selecting: true),
            Text('Đã chọn ${picked.length} repo; tối đa 100 repo mỗi lần tạo.'),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: locked ? null : save,
            child: Text(busy ? 'Đang lưu…' : 'Lưu workspace'),
          ),
          OutlinedButton(
            onPressed: locked
                ? null
                : () => setState(() {
                    creating = false;
                    editingId = null;
                  }),
            child: const Text('Hủy'),
          ),
        ],
      ),
    ),
  ];
  List<Widget> account() => [
    Text('Tài khoản', style: Theme.of(context).textTheme.headlineMedium),
    Text(widget.profile.displayName),
    Text(widget.profile.email),
    const Text('Vai trò: user'),
    GitHubAccountActions(repository: widget.auth),
    BackendPanel(onChanged: reloadGitHub),
    githubPanel(),
  ];
  List<Widget> content() {
    if (tab == 2) return account();
    if (model.loading) {
      return [
        const LinearProgressIndicator(),
        const Text('Đang tải workspace…'),
      ];
    }
    if (model.error.isNotEmpty) {
      return [
        Text(model.error),
        OutlinedButton(
          onPressed: locked ? null : model.reload,
          child: const Text('Tải lại'),
        ),
      ];
    }
    if (model.selected == null) {
      return [
        Text(
          'Workspace của bạn',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (model.workspaces.isEmpty)
          const Text('Tự tạo workspace đầu tiên và chọn repo cần dùng.'),
        ...model.workspaces.map(
          (workspace) => Card(
            child: ListTile(
              title: Text(workspace.name),
              subtitle: Text(workspace.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: locked
                  ? null
                  : () {
                      confirmingDelete = false;
                      ciRepo = '';
                      addingRepository = false;
                      model.select(workspace.id);
                    },
            ),
          ),
        ),
      ];
    }
    final workspace = model.selected!,
        deleting = workspace.status == 'deleting';
    return [
      Text(workspace.name, style: Theme.of(context).textTheme.headlineMedium),
      Text(workspace.description),
      if (deleting)
        const Text(
          'Đang xóa workspace. Bấm Tiếp tục xóa nếu lần trước bị gián đoạn.',
        ),
      OutlinedButton(
        onPressed: locked || deleting
            ? null
            : () => setState(() {
                editingId = workspace.id;
                name.text = workspace.name;
                description.text = workspace.description;
              }),
        child: const Text('Sửa workspace'),
      ),
      if (confirmingDelete || deleting) ...[
        const Text(
          'Xóa workspace và toàn bộ liên kết repo bên trong? Repository trên GitHub được giữ nguyên.',
        ),
        FilledButton(
          onPressed: locked
              ? null
              : () async {
                  final ok = await act(
                    () => repository.remove(widget.profile.uid, workspace.id),
                  );
                  if (mounted && ok) setState(() => confirmingDelete = false);
                },
          child: Text(deleting ? 'Tiếp tục xóa' : 'Xác nhận xóa workspace'),
        ),
        if (!deleting)
          TextButton(
            onPressed: locked
                ? null
                : () => setState(() => confirmingDelete = false),
            child: const Text('Hủy xóa'),
          ),
      ] else
        TextButton(
          onPressed: locked
              ? null
              : () => setState(() => confirmingDelete = true),
          child: const Text('Xóa workspace'),
        ),
      Text(
        'Repo trong workspace',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      FilledButton.icon(
        onPressed: locked || deleting
            ? null
            : () => setState(() => addingRepository = !addingRepository),
        icon: const Icon(Icons.add),
        label: Text(
          addingRepository ? 'Đóng danh sách repo' : 'Thêm repository',
        ),
      ),
      if (addingRepository && !deleting) githubPanel(),
      if (model.repositoriesLoading)
        const LinearProgressIndicator()
      else if (model.repositoriesError.isNotEmpty) ...[
        Text(model.repositoriesError),
        OutlinedButton(
          onPressed: locked ? null : () => model.select(workspace.id),
          child: const Text('Tải lại repo'),
        ),
      ] else if (model.repositories.isEmpty)
        const Text('Chưa có repo. Bấm Thêm repository để chọn từ GitHub.'),
      ...model.repositories.map(
        (repo) => RepositoryCard(
          key: ValueKey('${workspace.id}/${repo.id}'),
          repo: repo,
          uid: widget.profile.uid,
          workspaceId: workspace.id,
          repository: repository,
          act: act,
          disabled: locked || deleting,
          onOpen: () => openRepo(repo.fullName),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, github]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Vista CI'),
        actions: [
          IconButton(
            tooltip: 'Tải lại workspace',
            onPressed: locked || creating || editingId != null
                ? null
                : model.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!creating && editingId == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (model.workspaces.isNotEmpty)
                      DropdownButton<String>(
                        isExpanded: true,
                        value: model.selectedId,
                        hint: const Text('Chọn workspace'),
                        items: model.workspaces
                            .map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  '${w.name}${w.status == 'deleting' ? ' (đang xóa)' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: locked
                            ? null
                            : (id) {
                                if (id != null) {
                                  confirmingDelete = false;
                                  ciRepo = '';
                                  addingRepository = false;
                                  model.select(id);
                                }
                              },
                      ),
                    if (tab == 0)
                      FilledButton.icon(
                        onPressed:
                            locked || model.loading || model.error.isNotEmpty
                            ? null
                            : startCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo workspace'),
                      ),
                  ],
                ),
              ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(liveRegion: true, child: Text(message)),
              ),
            Expanded(
              child: tab == 1 && !creating && editingId == null
                  ? CicdScreen(
                      key: ValueKey(model.selectedId),
                      workspace: model,
                      initialRepo: ciRepo,
                      onRepoChanged: (value) {
                        ciRepo = value;
                        persistNavigation();
                      },
                    )
                  : ScrollPage(
                      eager: creating || editingId != null,
                      children: creating || editingId != null
                          ? editPage()
                          : content(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: locked || creating || editingId != null
            ? null
            : (value) {
                setState(() => tab = value);
                persistNavigation();
              },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Workspace',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            label: 'CI/CD',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    ),
  );
}
