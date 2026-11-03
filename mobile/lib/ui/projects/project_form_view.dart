import 'package:flutter/material.dart';

import '../../data/models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/app_text_field.dart';
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
          appBar: AppStackHeader(
            title: widget.project == null ? 'Tạo project' : 'Chỉnh sửa project',
            canGoBack: !model.saving,
          ),
          body: SafeArea(
            child: Form(
              key: formKey,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.page),
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
                      AppTextField(
                        label: 'Tên project',
                        controller: nameController,
                        enabled: !model.saving,
                        maxLength: Project.maxNameLength,
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
                      AppTextField(
                        label: 'Mô tả (không bắt buộc)',
                        controller: descriptionController,
                        enabled: !model.saving,
                        maxLength: Project.maxDescriptionLength,
                        minLines: 2,
                        maxLines: 4,
                        validator: (value) =>
                            (value?.trim().length ?? 0) >
                                Project.maxDescriptionLength
                            ? 'Mô tả quá dài.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Lưu project',
                        loadingLabel: 'Đang lưu…',
                        isLoading: model.saving,
                        onPressed: model.loadingProjects ? null : _saveProject,
                        icon: Icons.save_outlined,
                      ),
                      if (model.saveError.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        AppMessage(message: model.saveError),
                      ],
                      const SizedBox(height: AppSpacing.section),
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
                              AppChip(
                                label: repo.fullName,
                                onDeleted: model.saving
                                    ? null
                                    : () => model.removeRepository(repo.id),
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
                          AppButton(
                            label: 'Đồng bộ repo',
                            loadingLabel: 'Đang đồng bộ…',
                            variant: AppButtonVariant.text,
                            isLoading: model.loadingRepositories,
                            onPressed: model.saving
                                ? null
                                : model.loadGitHubRepositories,
                            icon: Icons.sync,
                          ),
                        ],
                      ),
                      AppTextField(
                        label: 'Tìm repo',
                        prefixIcon: Icons.search,
                        initialValue: model.repositorySearch,
                        onChanged: model.setRepositorySearch,
                      ),
                      const SizedBox(height: 12),
                      if (model.loadingRepositories)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Đang tải repo GitHub',
                        ),
                      if (model.repositoryError.isNotEmpty)
                        AppMessage(message: model.repositoryError),
                      if (!model.loadingRepositories &&
                          model.repositoryError.isEmpty &&
                          repos.isEmpty)
                        AppEmptyState(
                          message: model.repositorySearch.trim().isEmpty
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
