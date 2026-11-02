import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'workspace_repository.dart';
import 'workspace_view_model.dart';

class RepositoryCard extends StatefulWidget {
  const RepositoryCard({
    super.key,
    required this.repo,
    required this.uid,
    required this.workspaceId,
    required this.repository,
    required this.act,
    required this.disabled,
    required this.onOpen,
  });
  final VistaRepository repo;
  final String uid, workspaceId;
  final WorkspaceRepository repository;
  final Future<bool> Function(Future<void> Function()) act;
  final bool disabled;
  final VoidCallback onOpen;
  @override
  State<RepositoryCard> createState() => _RepositoryCardState();
}

class _RepositoryCardState extends State<RepositoryCard> {
  bool editing = false, confirming = false;
  late final name = TextEditingController(text: widget.repo.name),
      note = TextEditingController(text: widget.repo.description);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final ok = await widget.act(
      () => widget.repository.editRepo(
        widget.uid,
        widget.workspaceId,
        widget.repo.id,
        name.text,
        note.text,
      ),
    );
    if (mounted && ok) setState(() => editing = false);
  }

  Future<void> open() async {
    final url = 'https://github.com/${widget.repo.fullName}';
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không mở được GitHub.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: widget.disabled ? null : widget.onOpen,
            child: Text(
              widget.repo.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FilledButton.icon(
            onPressed: widget.disabled ? null : widget.onOpen,
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('CI/CD và log'),
          ),
          Text(widget.repo.fullName),
          Text(widget.repo.description),
          TextButton(onPressed: open, child: const Text('Mở GitHub')),
          if (editing)
            Form(
              key: form,
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Nhãn hiển thị',
                    ),
                    enabled: !widget.disabled,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập nhãn hiển thị.'
                        : null,
                  ),
                  TextFormField(
                    controller: note,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                    enabled: !widget.disabled,
                  ),
                  FilledButton(
                    onPressed: widget.disabled ? null : save,
                    child: const Text('Lưu'),
                  ),
                  OutlinedButton(
                    onPressed: widget.disabled
                        ? null
                        : () => setState(() => editing = false),
                    child: const Text('Hủy'),
                  ),
                ],
              ),
            )
          else
            OutlinedButton(
              onPressed: widget.disabled
                  ? null
                  : () => setState(() {
                      name.text = widget.repo.name;
                      note.text = widget.repo.description;
                      editing = true;
                    }),
              child: const Text('Sửa repo'),
            ),
          if (confirming) ...[
            const Text(
              'Gỡ liên kết khỏi workspace? Repository trên GitHub được giữ nguyên.',
            ),
            FilledButton(
              onPressed: widget.disabled
                  ? null
                  : () => widget.act(
                      () => widget.repository.removeRepo(
                        widget.uid,
                        widget.workspaceId,
                        widget.repo.id,
                      ),
                    ),
              child: const Text('Xác nhận gỡ'),
            ),
            TextButton(
              onPressed: widget.disabled
                  ? null
                  : () => setState(() => confirming = false),
              child: const Text('Hủy gỡ'),
            ),
          ] else
            TextButton(
              onPressed: widget.disabled
                  ? null
                  : () => setState(() => confirming = true),
              child: const Text('Gỡ repo'),
            ),
        ],
      ),
    ),
  );
}
