import 'package:flutter/material.dart';

import '../../data/models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_message.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/app_text_field.dart';
import 'projects_view_model.dart';
import 'select_repositories_view.dart';

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
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseRepositories() async {
    FocusScope.of(context).unfocus();
    widget.viewModel.setRepositorySearch('');
    widget.viewModel.loadGitHubRepositories();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SelectRepositoriesView(viewModel: widget.viewModel),
      ),
    );
  }

  Future<void> _saveProject() async {
    FocusScope.of(context).unfocus();
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.control,
                    AppSpacing.page,
                    AppSpacing.medium,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (model.saveError.isNotEmpty) ...[
                        AppMessage(message: model.saveError),
                        const SizedBox(height: AppSpacing.control),
                      ],
                      AppButton(
                        label: 'Lưu project',
                        loadingLabel: 'Đang lưu…',
                        isLoading: model.saving,
                        onPressed: model.loadingProjects ? null : _saveProject,
                        icon: Icons.save_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Form(
              key: formKey,
              child: RefreshIndicator(
                onRefresh: model.loadGitHubRepositories,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/logo/logo.png',
                            height: 56,
                            cacheHeight: 224,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.page),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            widget.project == null
                                ? 'Đặt tên project'
                                : 'Chỉnh sửa project',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.control),
                        Text(
                          'Đặt tên và chọn các repository bạn muốn quản lý cùng nhau.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.section),
                        AppTextField(
                          label: 'Tên project',
                          hint: 'Ví dụ: Mobile CI Platform',
                          helperText: 'Dùng tên giúp bạn dễ nhận diện project.',
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
                          hint: 'Project này dành cho việc gì?',
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
                        const SizedBox(height: AppSpacing.page),
                        AppButton(
                          label: 'Chọn repository',
                          onPressed: model.saving ? null : _chooseRepositories,
                          icon: Icons.checklist_outlined,
                          variant: AppButtonVariant.secondary,
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (model.loadingRepositories)
                          const AppLoading(
                            label: 'Đang cập nhật repository…',
                            compact: true,
                          ),
                        if (model.repositoryError.isNotEmpty)
                          AppMessage(message: model.repositoryError),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
