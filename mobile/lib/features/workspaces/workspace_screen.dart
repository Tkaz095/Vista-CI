import 'package:flutter/material.dart';

import '../auth/session_view_model.dart';
import '../auth/session_views.dart';
import 'workspace_view_model.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.profile, required this.auth});
  final VistaProfile profile;
  final AuthRepository auth;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final WorkspaceViewModel model = WorkspaceViewModel(
    widget.profile.uid,
    WorkspaceRepository(),
  );
  int tab = 0;
  bool choosing = false;
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  void pickWorkspace() {
    setState(() {
      choosing = true;
      tab = 0;
    });
  }

  List<Widget> account() => [
    Text('Tài khoản', style: Theme.of(context).textTheme.headlineMedium),
    const Text('Tên hiển thị'),
    SelectableText(
      widget.profile.displayName.isEmpty
          ? 'Chưa đặt tên'
          : widget.profile.displayName,
    ),
    const Text('Email'),
    SelectableText(widget.profile.email),
    const Text('Vai trò Vista'),
    Text(widget.profile.role),
    const Text('UID'),
    SelectableText(widget.profile.uid),
    const Text('Vai trò Vista không tự cấp quyền vào mọi workspace.'),
    GitHubAccountActions(repository: widget.auth),
  ];
  List<Widget> workspaceContent() {
    if (model.loading) {
      return [
        const LinearProgressIndicator(),
        const Text('Đang tải workspace…'),
      ];
    }
    if (model.error.isNotEmpty) {
      return [
        Text(model.error),
        FilledButton(onPressed: model.reload, child: const Text('Thử lại')),
      ];
    }
    if (model.workspaces.isEmpty) {
      return [
        const Text('Bạn chưa được thêm vào workspace nào.'),
        const Text(
          'Bạn đã đăng nhập. Khi được thêm vào workspace, danh sách sẽ xuất hiện ở đây.',
        ),
        OutlinedButton(onPressed: model.reload, child: const Text('Tải lại')),
      ];
    }
    if (model.selected == null || choosing) {
      return [
        Text(
          'Workspace của bạn',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text('Chọn workspace để xem repository và tiến trình CI/CD.'),
        ...model.workspaces.map(
          (w) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              title: Text(w.name),
              subtitle: Text(w.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                model.select(w.id);
                setState(() => choosing = false);
              },
            ),
          ),
        ),
      ];
    }
    if (tab == 1) {
      return [
        Text('Repository', style: Theme.of(context).textTheme.headlineMedium),
        const Text(
          'Danh sách cấu hình trên Vista; chưa kết nối GitHub để đồng bộ workflow.',
        ),
        if (model.repositoriesLoading)
          const LinearProgressIndicator()
        else if (model.repositoriesError.isNotEmpty) ...[
          Text(model.repositoriesError),
          OutlinedButton(
            onPressed: () => model.select(model.selectedId!),
            child: const Text('Thử lại'),
          ),
        ] else if (model.repositories.isEmpty)
          const Text('Workspace chưa có repository.')
        else
          ...model.repositories.map(
            (repo) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const Icon(Icons.source_outlined),
                title: Text(repo.name),
                subtitle: Text('${repo.description}\nChưa đồng bộ GitHub'),
              ),
            ),
          ),
      ];
    }
    return [
      Text(
        tab == 0 ? 'Lần chạy CI/CD' : 'Lịch sử thao tác',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(model.selected!.description),
      const Icon(Icons.sync_outlined, size: 56, color: Color(0xFF2563EB)),
      Text(tab == 0 ? 'Chưa kết nối workflow' : 'Chưa có nguồn audit'),
      Text(
        tab == 0
            ? 'Bước tiếp theo sẽ kết nối GitHub để đồng bộ trạng thái, kết quả và log vào workspace này.'
            : 'Audit sẽ được ghi ở backend khi chức năng chạy lại, tạo issue và bình luận PR được triển khai.',
      ),
      OutlinedButton(
        onPressed: () => setState(() => tab = 1),
        child: const Text('Xem repository'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Vista CI'),
        actions: [
          IconButton(
            tooltip: 'Tải lại workspace',
            onPressed: model.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (model.selected != null && tab != 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedButton.icon(
                  onPressed: pickWorkspace,
                  icon: const Icon(Icons.unfold_more),
                  label: Text(
                    model.selected!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Expanded(
              child: ScrollPage(
                children: tab == 3 ? account() : workspaceContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            label: 'Run',
          ),
          NavigationDestination(
            icon: Icon(Icons.source_outlined),
            label: 'Repo',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Hoạt động'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    ),
  );
}
