import 'package:flutter/material.dart';

import '../github/github_repository.dart';
import 'run_detail_view.dart';

import '../auth/session_views.dart';
import '../workspaces/workspace_view_model.dart';
import 'cicd_view_model.dart';

class CicdScreen extends StatefulWidget {
  const CicdScreen({
    super.key,
    required this.workspace,
    this.initialRepo = '',
    required this.onRepoChanged,
  });
  final WorkspaceViewModel workspace;
  final String initialRepo;
  final ValueChanged<String> onRepoChanged;
  @override
  State<CicdScreen> createState() => _CicdScreenState();
}

class _CicdScreenState extends State<CicdScreen> {
  final model = CicdViewModel(), branchInput = TextEditingController();
  String selectedRepo = '', branch = '', status = '', draftStatus = '';
  bool filters = false;
  WorkflowRun? selectedRun;
  @override
  void initState() {
    super.initState();
    selectedRepo = widget.initialRepo;
    widget.workspace.addListener(sync);
    sync();
  }

  void sync() {
    final workspace = widget.workspace;
    final names =
        workspace.repositories.map((repo) => repo.fullName).toSet().toList()
          ..sort();
    if (!workspace.repositoriesLoading &&
        workspace.repositoriesError.isEmpty &&
        !names.contains(selectedRepo)) {
      selectedRepo = '';
    }
    if (selectedRun != null &&
        (workspace.selected?.status != 'active' ||
            workspace.repositoriesError.isNotEmpty ||
            !workspace.repositoriesLoading &&
                !names.contains(selectedRun!.repo))) {
      selectedRun = null;
    }
    model.configure(
      workspace.selected?.status != 'active' ||
              workspace.repositoriesLoading ||
              workspace.repositoriesError.isNotEmpty
          ? []
          : selectedRepo.isEmpty
          ? names
          : [selectedRepo],
      branch,
      status,
    );
  }

  @override
  void dispose() {
    widget.workspace.removeListener(sync);
    model.dispose();
    branchInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (selectedRun != null) {
        return RunDetailView(
          key: ValueKey(
            '${selectedRun!.repo}/${selectedRun!.id}/${selectedRun!.attempt}',
          ),
          run: selectedRun!,
          onClose: () => setState(() => selectedRun = null),
        );
      }
      final workspace = widget.workspace;
      final names =
          workspace.repositories.map((repo) => repo.fullName).toSet().toList()
            ..sort();
      return ScrollPage(
        children: [
          Text('CI/CD', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Lịch sử GitHub Actions của các repo trong workspace.'),
          if (workspace.loading)
            const LinearProgressIndicator()
          else if (workspace.error.isNotEmpty)
            Text(workspace.error)
          else if (workspace.selected == null)
            const Text('Chọn workspace ở trên để xem CI/CD.')
          else if (workspace.selected!.status != 'active')
            const Text('Workspace đang xóa. Chọn workspace đang hoạt động.')
          else if (workspace.repositoriesLoading)
            const LinearProgressIndicator()
          else if (workspace.repositoriesError.isNotEmpty) ...[
            Text(workspace.repositoriesError),
            OutlinedButton(
              onPressed: () => workspace.select(workspace.selectedId!),
              child: const Text('Tải lại repo'),
            ),
          ] else if (names.isEmpty)
            const Text(
              'Workspace chưa có repo. Mở Workspace để thêm repository.',
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey('$selectedRepo/${names.join(',')}'),
              initialValue: selectedRepo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Repository'),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text('Tất cả repo (${names.length})'),
                ),
                ...names.map(
                  (name) => DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => selectedRepo = value ?? '');
                widget.onRepoChanged(selectedRepo);
                sync();
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  filters = !filters;
                  branchInput.text = branch;
                  draftStatus = status;
                }),
                icon: const Icon(Icons.filter_list),
                label: const Text('Bộ lọc'),
              ),
            ),
            if (filters) ...[
              TextField(
                controller: branchInput,
                decoration: const InputDecoration(
                  labelText: 'Branch chính xác',
                  hintText: 'Ví dụ: main',
                ),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('filter/$draftStatus'),
                initialValue: draftStatus,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái / kết quả',
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tất cả')),
                  ...[
                    'queued',
                    'in_progress',
                    'completed',
                    'success',
                    'failure',
                    'cancelled',
                    'timed_out',
                  ].map(
                    (s) =>
                        DropdownMenuItem(value: s, child: Text(runLabels[s]!)),
                  ),
                ],
                onChanged: (value) => draftStatus = value ?? '',
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    branch = branchInput.text.trim();
                    status = draftStatus;
                    filters = false;
                  });
                  sync();
                },
                child: const Text('Áp dụng'),
              ),
            ],
            if (branch.isNotEmpty || status.isNotEmpty) ...[
              Text(
                'Đang lọc: ${branch.isEmpty ? 'mọi branch' : branch} · ${runLabels[status] ?? 'mọi trạng thái'}',
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    branch = '';
                    status = '';
                    filters = false;
                  });
                  sync();
                },
                child: const Text('Xóa bộ lọc'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: model.busy ? null : () => model.load(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
            if (model.updated != null)
              Text(
                'Lần tải gần nhất: ${model.updated!.toLocal().toString().split('.').first}',
              ),
            const Text(
              'Mỗi lượt tải tối đa 20 lần chạy/repo. Sắp xếp kết quả đã tải theo thời gian; tải thêm để xem lịch sử cũ hơn.',
            ),
            ...model.pages.entries
                .where((entry) => entry.value.error.isNotEmpty)
                .map(
                  (entry) => Semantics(
                    liveRegion: true,
                    child: Text(
                      '${entry.key}: ${entry.value.error} Dữ liệu cũ nếu có được giữ lại.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            if (model.busy) const LinearProgressIndicator(),
            if (!model.busy &&
                model.runs.isEmpty &&
                model.pages.length == model.repos.length &&
                model.pages.values.every((p) => p.error.isEmpty))
              const Text(
                'Không có lần chạy phù hợp. Repo có thể chưa cấu hình GitHub Actions.',
              ),
            ...model.runs.map((run) {
              final result = run.conclusion ?? run.status;
              final color = result == 'success'
                  ? const Color(0xff166534)
                  : ['failure', 'timed_out'].contains(result)
                  ? const Color(0xff991b1b)
                  : result == 'in_progress'
                  ? const Color(0xff1e40af)
                  : const Color(0xff475569);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            result == 'success'
                                ? Icons.check_circle_outline
                                : ['failure', 'timed_out'].contains(result)
                                ? Icons.cancel_outlined
                                : result == 'in_progress'
                                ? Icons.autorenew
                                : Icons.schedule,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              runLabels[result] ?? result,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        run.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${run.repo} · ${run.workflow}'),
                      Text(
                        '${run.branch} · ${run.sha.length > 7 ? run.sha.substring(0, 7) : run.sha} · ${run.actor}',
                      ),
                      Text(
                        '${run.created.toLocal().toString().split('.').first} · Lần thử ${run.attempt}',
                      ),
                      Text(runLabels[run.status] ?? run.status),
                      FilledButton.icon(
                        onPressed: () => setState(() => selectedRun = run),
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('Chi tiết job và log'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (model.more)
              OutlinedButton(
                onPressed: model.busy ? null : () => model.load(),
                child: const Text('Tải thêm / thử lại repo lỗi'),
              ),
          ],
        ],
      );
    },
  );
}
