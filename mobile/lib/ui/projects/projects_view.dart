import 'package:flutter/material.dart';

import '../../data/models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_message.dart';
import 'project_detail_view.dart';
import '../widgets/app_text_field.dart';
import 'project_form_view.dart';
import 'projects_view_model.dart';

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key, required this.viewModel});

  final ProjectsViewModel viewModel;

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
            return _ProjectCard(
              key: ValueKey(project.id),
              project: project,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProjectDetailView(
                    projectId: project.id,
                    viewModel: viewModel,
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _header(BuildContext context, bool empty) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Tìm project',
          hint: 'Tên hoặc mô tả project…',
          prefixIcon: Icons.search,
          initialValue: viewModel.projectSearch,
          onChanged: viewModel.setProjectSearch,
        ),
        const SizedBox(height: AppSpacing.page),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Project của bạn', style: theme.textTheme.headlineSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.control,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '${viewModel.visibleProjects.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            IconButton.filled(
              tooltip: 'Tạo project',
              onPressed: viewModel.saving || viewModel.loadingProjects
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectFormView(viewModel: viewModel),
                      ),
                    ),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          'Nhóm các repo GitHub theo từng project.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({super.key, required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(AppSpacing.medium),
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.small),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder_outlined, color: colors.primary),
              ),
              title: Text(project.name),
              subtitle: Text('${project.repositories.length} repositories'),
              trailing: IconButton(
                tooltip: expanded ? 'Ẩn repository' : 'Xem repository',
                onPressed: project.repositories.isEmpty
                    ? null
                    : () => setState(() => expanded = !expanded),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ),
            if (expanded)
              for (final repo in project.repositories) ...[
                const Divider(height: 1),
                _RepositoryRow(repo: repo),
              ],
          ],
        ),
      ),
    );
  }
}

class _RepositoryRow extends StatelessWidget {
  const _RepositoryRow({required this.repo});

  final ProjectRepo repo;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.card,
      vertical: AppSpacing.small,
    ),
    leading: const Icon(Icons.code, size: 20),
    title: Text(repo.fullName),
    titleTextStyle: Theme.of(context).textTheme.bodyMedium,
  );
}
