import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/project.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/workflow_status_badge.dart';
import '../widgets/workflow_run_summary.dart';
import 'project_detail_view_model.dart';
import 'project_form_view.dart';
import 'projects_view_model.dart';
import 'repository_runs_view.dart';

enum _ProjectAction { edit, delete }

class ProjectDetailView extends StatefulWidget {
  const ProjectDetailView({
    super.key,
    required this.projectId,
    required this.viewModel,
  });
  final String projectId;
  final ProjectsViewModel viewModel;

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  final GitHubActionsRepository repository = GitHubActionsRepository();
  late final ProjectDetailViewModel actions;
  bool _isDescriptionExpanded = false;

  Project? get project {
    final matches = widget.viewModel.projects.where(
      (item) => item.id == widget.projectId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  void initState() {
    super.initState();
    actions = ProjectDetailViewModel(
      repository,
      repositories: project?.repositories ?? [],
      accessToken: widget.viewModel.accessToken,
      telemetry: widget.viewModel.telemetry,
    );
    actions.load();
  }

  @override
  void dispose() {
    actions.dispose();
    super.dispose();
  }

  Future<void> _editProject(Project current) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProjectFormView(viewModel: widget.viewModel, project: current),
      ),
    );
    if (mounted) await actions.updateRepositories(project?.repositories ?? []);
  }

  Future<void> _refresh() async {
    if (widget.viewModel.saving ||
        widget.viewModel.loadingProjects ||
        actions.loading) {
      return;
    }
    await widget.viewModel.loadProjects();
    if (mounted) {
      await actions.updateRepositories(
        project?.repositories ?? [],
        refresh: true,
      );
    }
  }

  Future<void> _deleteProject(BuildContext context, Project project) async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
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
    final deleted = await widget.viewModel.deleteProject(project);
    if (deleted && context.mounted) Navigator.of(context).pop();
  }

  void _handleAction(_ProjectAction action) {
    final current = project;
    if (!mounted ||
        current == null ||
        widget.viewModel.saving ||
        widget.viewModel.loadingProjects) {
      return;
    }
    switch (action) {
      case _ProjectAction.edit:
        _editProject(current);
      case _ProjectAction.delete:
        _deleteProject(context, current);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.viewModel, actions]),
    builder: (context, _) {
      final project = this.project;
      return PopScope(
        canPop: !widget.viewModel.saving,
        child: Scaffold(
          appBar: AppStackHeader(
            title: project?.name ?? 'Chi tiết project',
            canGoBack: !widget.viewModel.saving,
            actions: [
              if (project != null)
                PopupMenuButton<_ProjectAction>(
                  tooltip: 'Thao tác project',
                  icon: const Icon(Icons.more_vert),
                  enabled:
                      !widget.viewModel.saving &&
                      !widget.viewModel.loadingProjects,
                  onSelected: _handleAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _ProjectAction.edit,
                      height: AppSpacing.touchTarget,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: AppSpacing.control),
                          Flexible(child: Text('Chỉnh sửa')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _ProjectAction.delete,
                      height: AppSpacing.touchTarget,
                      textStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppSpacing.control),
                          const Flexible(child: Text('Xóa project')),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: project == null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.page),
                      children: const [
                        AppEmptyState(
                          message: 'Project không còn trong danh sách.',
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.page),
                      children: [
                        if (widget.viewModel.saving) ...[
                          const AppLoading(
                            label: 'Đang xử lý project…',
                            compact: true,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                        ],
                        if (widget.viewModel.saveError.isNotEmpty) ...[
                          AppMessage(message: widget.viewModel.saveError),
                          const SizedBox(height: AppSpacing.medium),
                        ],
                        if (widget.viewModel.projectError.isNotEmpty) ...[
                          AppMessage(
                            message: widget.viewModel.projectError,
                            type: AppMessageType.warning,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.hub_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Repository đang theo dõi (${project.repositories.length})',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (project.repositories.isEmpty)
                          const AppEmptyState(
                            message: 'Project chưa có repo. Mở menu ba chấm và chọn “Chỉnh sửa” để thêm.',
                          ),
                        if (actions.loading && actions.visibleCount == 0)
                          const AppLoading(label: 'Đang tải lần chạy gần nhất…')
                        else ...[
                          for (final repo in actions.repositories.take(
                            actions.visibleCount,
                          ))
                            _repositoryCard(context, repo),
                          if (actions.loading)
                            const AppLoading(
                              label: 'Đang đồng bộ Actions…',
                              compact: true,
                            ),
                          if (actions.hasMore)
                            AppButton(
                              label: 'Xem thêm repository',
                              isLoading: actions.loading,
                              onPressed: () => actions.load(more: true),
                              variant: AppButtonVariant.secondary,
                            ),
                        ],
                        if (project.description.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.page),
                          _buildDescriptionCard(context, project),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildDescriptionCard(BuildContext context, Project project) {
    if (project.description.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isLong = project.description.contains('\n') || project.description.length > 120;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.page),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.7),
          width: 0.8,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notes_rounded, size: 16, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mô tả project',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            project.description,
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              height: 1.4,
            ),
          ),
          if (isLong) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isDescriptionExpanded ? 'Thu gọn' : 'Xem thêm',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isDescriptionExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _repositoryCard(BuildContext context, ProjectRepo repo) {
    final run = actions.latestRuns[repo.id];
    final error = actions.errors[repo.id];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final failed =
        run != null &&
        [
          WorkflowState.failure,
          WorkflowState.timedOut,
        ].contains(WorkflowState.fromGitHub(run.status, run.conclusion));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: failed
              ? colors.error.withValues(alpha: 0.5)
              : colors.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.7),
          width: 0.8,
        ),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RepositoryRunsView(
                  repo: repo,
                  projectName: project?.name ?? 'Project',
                  repository: repository,
                  accessToken: widget.viewModel.accessToken,
                  telemetry: widget.viewModel.telemetry,
                  configuration: widget.viewModel.configuration,
                  ownerUid: widget.viewModel.uid,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final heading = Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: failed
                                ? colors.errorContainer.withValues(alpha: 0.5)
                                : colors.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.source_outlined,
                            size: 18,
                            color: failed ? colors.error : colors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.small + 2),
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.small,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Tooltip(
                                message: repo.fullName,
                                child: Text(
                                  repo.fullName.split('/').last,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (run != null && run.branch.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: failed
                                        ? colors.errorContainer
                                        : colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    run.branch,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: failed
                                          ? colors.onErrorContainer
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                    if (run == null) return heading;
                    final badge = WorkflowStatusBadge(
                      status: run.status,
                      conclusion: run.conclusion,
                    );
                    if (constraints.maxWidth >= 280 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: AppSpacing.small),
                          badge,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: AppSpacing.small),
                        badge,
                      ],
                    );
                  },
                ),
                if (run != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    run.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: failed ? colors.error : colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.control),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (run.sha.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.commit,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              run.sha.length > 7
                                  ? run.sha.substring(0, 7)
                                  : run.sha,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      if (run.createdAt != null)
                        WorkflowRunTime(date: run.createdAt!),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  AppMessage(message: error),
                ],
                if (run == null && error == null)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.medium),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow.withValues(alpha: isDark ? 0.35 : 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                        width: 0.6,
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
                            Icons.history_toggle_off_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chưa có lần chạy GitHub Actions.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chạm để xem lịch sử hoặc chạy workflow trên GitHub.',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
