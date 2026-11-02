import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'github_repository.dart';
import 'github_view_model.dart';

class GitHubPanel extends StatefulWidget {
  const GitHubPanel({
    super.key,
    required this.model,
    required this.disabled,
    this.picked,
    this.onToggle,
    this.onReset,
    this.onAdd,
  });
  final GitHubViewModel model;
  final bool disabled;
  final Set<String>? picked;
  final ValueChanged<String>? onToggle;
  final VoidCallback? onReset;
  final ValueChanged<GitHubRepo>? onAdd;
  @override
  State<GitHubPanel> createState() => _GitHubPanelState();
}

class _GitHubPanelState extends State<GitHubPanel> {
  String filter = '';
  Future<void> open(GitHubRepo repo) async {
    try {
      if (!await launchUrl(
        Uri.parse(repo.htmlUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không mở được trình duyệt. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model,
        locked = widget.disabled || widget.model.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Repository GitHub',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Repo public thuộc tài khoản của bạn. Token được giữ và tự gia hạn ở backend. Khi cấp quyền xong trên trình duyệt, quay lại Vista.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: locked
              ? null
              : () {
                  widget.onReset?.call();
                  model.load(reconnect: true);
                },
          child: const Text('Kết nối GitHub'),
        ),
        OutlinedButton(
          onPressed: locked
              ? null
              : () {
                  widget.onReset?.call();
                  model.load();
                },
          child: const Text('Tải lại repo'),
        ),
        if (model.pending) const LinearProgressIndicator(),
        if (model.pending && GitHubRepository.instance.connecting)
          TextButton(
            onPressed: GitHubRepository.instance.cancelConnection,
            child: const Text('Hủy chờ kết nối'),
          ),
        if (model.error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              model.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: 'Tìm repo'),
          onChanged: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 12),
        ...model.repos
            .where(
              (repo) =>
                  repo.fullName.toLowerCase().contains(filter.toLowerCase()),
            )
            .map(
              (repo) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.picked != null)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(repo.fullName),
                          value: widget.picked!.contains(repo.id),
                          onChanged: locked
                              ? null
                              : (_) => widget.onToggle?.call(repo.id),
                        )
                      else
                        Text(
                          repo.fullName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      Text(repo.isPrivate ? 'Private' : 'Public'),
                      TextButton(
                        onPressed: () => open(repo),
                        child: const Text('Mở GitHub'),
                      ),
                      if (widget.picked == null)
                        OutlinedButton(
                          onPressed: locked || widget.onAdd == null
                              ? null
                              : () => widget.onAdd!(repo),
                          child: const Text('Thêm vào workspace đã chọn'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        if (!model.pending && model.error.isEmpty && model.repos.isEmpty)
          Text(
            model.loaded
                ? 'Chưa có repo public thuộc tài khoản GitHub trong danh sách này.'
                : 'Chưa tải repo. Bấm Kết nối GitHub hoặc Tải lại repo.',
          ),
        if (model.more)
          OutlinedButton(
            onPressed: locked ? null : () => model.load(next: true),
            child: const Text('Tải thêm repo'),
          ),
      ],
    );
  }
}
