import 'package:flutter/material.dart';

import '../../data/models/project.dart';
import 'projects_view_model.dart';

class ProjectFormView extends StatefulWidget {
  const ProjectFormView({super.key, required this.viewModel, this.project});
  final ProjectsViewModel viewModel;
  final Project? project;

  @override
  State<ProjectFormView> createState() => _ProjectFormViewState();
}

class _ProjectFormViewState extends State<ProjectFormView> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.project?.name ?? '');
    descriptionController = TextEditingController(
      text: widget.project?.description ?? '',
    );
    widget.viewModel.startEditing(widget.project);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.loadGitHubRepositories();
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!formKey.currentState!.validate()) return;
    final saved = await widget.viewModel.saveProject(
      project: widget.project,
      name: nameController.text,
      description: descriptionController.text,
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final model = widget.viewModel;
      final repos = model.visibleRepositories;
      final selectedIds = model.selectedRepositories
          .map((repo) => repo.id)
          .toSet();
      final theme = Theme.of(context);
      return PopScope(
        canPop: !model.saving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.project == null ? 'Tạo project' : 'Chỉnh sửa project',
            ),
          ),
          body: SafeArea(
            child: Form(
              key: formKey,
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: repos.length + 1,
                itemBuilder: (context, index) {
                  if (index > 0) {
                    final repo = repos[index - 1];
                    final selected = selectedIds.contains(repo.id);
                    final canSelect =
                        selected ||
                        selectedIds.length < Project.maxRepositories;
                    return CheckboxListTile(
                      key: ValueKey(repo.id),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(repo.fullName),
                      subtitle: Text(
                        [
                          repo.isPrivate ? 'Riêng tư' : 'Công khai',
                          if (repo.language.isNotEmpty) repo.language,
                        ].join(' · '),
                      ),
                      value: selected,
                      onChanged:
                          model.saving ||
                              model.loadingRepositories ||
                              !canSelect
                          ? null
                          : (_) => model.toggleRepository(repo),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        enabled: !model.saving,
                        maxLength: Project.maxNameLength,
                        decoration: const InputDecoration(
                          labelText: 'Tên project',
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) return 'Nhập tên project.';
                          if (name.length > Project.maxNameLength) {
                            return 'Tên project quá dài.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        enabled: !model.saving,
                        maxLength: Project.maxDescriptionLength,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả (không bắt buộc)',
                        ),
                        validator: (value) =>
                            (value?.trim().length ?? 0) >
                                Project.maxDescriptionLength
                            ? 'Mô tả quá dài.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: model.saving || model.loadingProjects
                            ? null
                            : _saveProject,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(model.saving ? 'Đang lưu…' : 'Lưu project'),
                      ),
                      if (model.saveError.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            model.saveError,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Repo đã chọn (${selectedIds.length}/${Project.maxRepositories})',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bạn có thể lưu project rỗng và thêm repo sau.',
                      ),
                      if (model.selectedRepositories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final repo in model.selectedRepositories)
                              InputChip(
                                label: Text(repo.fullName),
                                onDeleted: model.saving
                                    ? null
                                    : () => model.removeRepository(repo.id),
                                deleteButtonTooltipMessage:
                                    'Bỏ ${repo.fullName}',
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Chọn repo từ GitHub',
                            style: theme.textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: model.loadingRepositories || model.saving
                                ? null
                                : model.loadGitHubRepositories,
                            icon: const Icon(Icons.sync),
                            label: const Text('Đồng bộ repo'),
                          ),
                        ],
                      ),
                      TextFormField(
                        initialValue: model.repositorySearch,
                        onChanged: model.setRepositorySearch,
                        decoration: const InputDecoration(
                          labelText: 'Tìm repo',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (model.loadingRepositories)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Đang tải repo GitHub',
                        ),
                      if (model.repositoryError.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            model.repositoryError,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      if (!model.loadingRepositories &&
                          model.repositoryError.isEmpty &&
                          repos.isEmpty)
                        Text(
                          model.repositorySearch.trim().isEmpty
                              ? 'GitHub chưa trả về repo nào.'
                              : 'Không tìm thấy repo phù hợp.',
                        ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
