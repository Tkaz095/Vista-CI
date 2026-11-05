import 'package:flutter/material.dart';

import '../../data/models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_message.dart';
import 'project_detail_view.dart';
import '../widgets/app_text_field.dart';
import 'project_form_view.dart';
import 'projects_view_model.dart';

import 'package:flutter/services.dart';

import '../widgets/app_shimmer.dart';

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
            AppSpacing.section + 40,
          ),
          itemCount: projects.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _header(context, projects.isEmpty);
            final project = projects[index - 1];
            return _ProjectCard(
              key: ValueKey(project.id),
              project: project,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProjectDetailView(
                      projectId: project.id,
                      viewModel: viewModel,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );

  Widget _header(BuildContext context, bool empty) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totalRepos = viewModel.projects.fold<int>(
      0,
      (acc, p) => acc + p.repositories.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Pill Search Bar
        AppTextField(
          label: 'Tìm project',
          hint: 'Tên hoặc mô tả project…',
          isSearch: true,
          prefixIcon: Icons.search_rounded,
          suffixIcon: viewModel.projectSearch.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    viewModel.setProjectSearch('');
                  },
                )
              : null,
          initialValue: viewModel.projectSearch,
          onChanged: viewModel.setProjectSearch,
        ),
        const SizedBox(height: AppSpacing.medium),

        // CI Pulse Overview Metric Banner
        if (viewModel.projects.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng quan hệ sinh thái CI',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                      Text(
                        '${viewModel.projects.length} project đang hoạt động • $totalRepos repo được giám sát',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.page),
        ],

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
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '${viewModel.visibleProjects.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
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
                  : () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProjectFormView(viewModel: viewModel),
                        ),
                      );
                    },
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
        if (viewModel.projectsState.isLoading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(semanticsLabel: 'Đang tải project'),
          const SizedBox(height: 16),
          AppShimmer(
            child: Column(
              children: [
                for (var i = 0; i < 2; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (viewModel.projectsState.hasError) ...[
          const SizedBox(height: 20),
          AppMessage(message: viewModel.projectError),
        ],
        if (empty &&
            !viewModel.projectsState.isLoading &&
            !viewModel.projectsState.hasError) ...[
          const SizedBox(height: AppSpacing.section),
          AppEmptyState(
            icon: Icons.folder_open_outlined,
            title: viewModel.projectSearch.trim().isEmpty
                ? 'Bắt đầu với Project đầu tiên'
                : 'Không có kết quả',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.7),
          width: 0.8,
        ),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.card,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_outlined,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  project.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${project.repositories.length} repositories',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                trailing: IconButton(
                  tooltip: expanded ? 'Ẩn repository' : 'Xem repository',
                  onPressed: project.repositories.isEmpty
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => expanded = !expanded);
                        },
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (expanded)
                Material(
                  color: colors.surfaceContainerLow.withValues(alpha: 0.4),
                  child: Column(
                    children: [
                      for (final repo in project.repositories) ...[
                        Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: 0.4),
                        ),
                        _RepositoryRow(repo: repo),
                      ],
                    ],
                  ),
                ),
            ],
          ),
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
    titleTextStyle: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w500),
  );
}
