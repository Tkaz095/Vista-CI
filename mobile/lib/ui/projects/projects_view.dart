import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/project.dart';
import '../../data/models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/app_text_field.dart';
import 'project_form_view.dart';
import 'projects_view_model.dart';

class ProjectsView extends StatelessWidget {
  const ProjectsView({
    super.key,
    required this.viewModel,
    required this.profile,
  });

  final ProjectsViewModel viewModel;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final projects = viewModel.visibleProjects;
      return RefreshIndicator(
        onRefresh: viewModel.saving ? () async {} : viewModel.loadProjects,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.medium,
            AppSpacing.page,
            AppSpacing.section,
          ),
          itemCount: projects.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _header(context, projects.isEmpty);
            final project = projects[index - 1];
            return Column(
              children: [
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  title: Text(project.name),
                  subtitle: Text(
                    [
                      if (project.description.isNotEmpty) project.description,
                      '${project.repositories.length} repo',
                    ].join('\n'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ProjectDetailsView(
                        projectId: project.id,
                        viewModel: viewModel,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _header(BuildContext context, bool empty) {
    final theme = Theme.of(context);
    final name = profile.displayName.isEmpty
        ? 'Vista User'
        : profile.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Xin chào, $name', style: theme.textTheme.titleMedium),
        if (profile.email.isNotEmpty) Text(profile.email),
        const SizedBox(height: AppSpacing.section),
        Text('Project của bạn', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Nhóm các repo GitHub theo từng project.'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            AppButton(
              label: 'Tạo project',
              onPressed: viewModel.saving || viewModel.loadingProjects
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectFormView(viewModel: viewModel),
                      ),
                    ),
              icon: Icons.add,
            ),
            AppButton(
              label: 'Tải lại',
              loadingLabel: 'Đang tải…',
              variant: AppButtonVariant.secondary,
              isLoading: viewModel.loadingProjects,
              onPressed: viewModel.saving ? null : viewModel.loadProjects,
              icon: Icons.refresh,
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Tìm project',
          prefixIcon: Icons.search,
          initialValue: viewModel.projectSearch,
          onChanged: viewModel.setProjectSearch,
        ),
        if (viewModel.loadingProjects) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(semanticsLabel: 'Đang tải project'),
        ],
        if (viewModel.projectError.isNotEmpty) ...[
          const SizedBox(height: 20),
          AppMessage(message: viewModel.projectError),
        ],
        if (empty &&
            !viewModel.loadingProjects &&
            viewModel.projectError.isEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          AppEmptyState(
            message: viewModel.projectSearch.trim().isEmpty
                ? 'Chưa có project. Tạo project đầu tiên rồi chọn các repo của bạn.'
                : 'Không tìm thấy project phù hợp. Hãy thử từ khóa khác.',
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ProjectDetailsView extends StatelessWidget {
  const _ProjectDetailsView({required this.projectId, required this.viewModel});
  final String projectId;
  final ProjectsViewModel viewModel;

  Future<void> _deleteProject(BuildContext context, Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa project?'),
        content: Text(
          'Xóa “${project.name}” khỏi Vista? Các repo trên GitHub vẫn được giữ.',
        ),
        actions: [
          AppButton(
            label: 'Giữ lại',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Xóa project',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await viewModel.deleteProject(project);
    if (deleted && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _openRepo(BuildContext context, ProjectRepo repo) async {
    try {
      if (await launchUrl(
        repo.githubUrl,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Show one readable message whether the browser returns false or throws.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa mở được GitHub. Hãy thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final matches = viewModel.projects.where(
        (project) => project.id == projectId,
      );
      final project = matches.isEmpty ? null : matches.first;
      return PopScope(
        canPop: !viewModel.saving,
        child: Scaffold(
          appBar: AppStackHeader(
            title: 'Chi tiết project',
            canGoBack: !viewModel.saving,
          ),
          body: SafeArea(
            child: project == null
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.page),
                    child: AppEmptyState(
                      message: 'Project không còn trong danh sách.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (project.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(project.description),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          AppButton(
                            label: 'Chỉnh sửa',
                            onPressed:
                                viewModel.saving || viewModel.loadingProjects
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ProjectFormView(
                                        viewModel: viewModel,
                                        project: project,
                                      ),
                                    ),
                                  ),
                            icon: Icons.edit_outlined,
                          ),
                          AppButton(
                            label: 'Xóa project',
                            loadingLabel: 'Đang xóa…',
                            isLoading: viewModel.saving,
                            variant: AppButtonVariant.danger,
                            onPressed: viewModel.loadingProjects
                                ? null
                                : () => _deleteProject(context, project),
                            icon: Icons.delete_outline,
                          ),
                        ],
                      ),
                      if (viewModel.saveError.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        AppMessage(message: viewModel.saveError),
                      ],
                      if (viewModel.projectError.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        AppMessage(
                          message: viewModel.projectError,
                          type: AppMessageType.warning,
                        ),
                        AppButton(
                          label: 'Tải lại project',
                          loadingLabel: 'Đang tải…',
                          variant: AppButtonVariant.text,
                          isLoading: viewModel.loadingProjects,
                          onPressed: viewModel.saving
                              ? null
                              : viewModel.loadProjects,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        'Repo trong project (${project.repositories.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (project.repositories.isEmpty)
                        const AppEmptyState(
                          message:
                              'Project chưa có repo. Chọn “Chỉnh sửa” để thêm.',
                        ),
                      for (final repo in project.repositories) ...[
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(repo.fullName),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => _openRepo(context, repo),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
