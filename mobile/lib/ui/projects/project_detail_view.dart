import 'package:flutter/material.dart';

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
                        if (project.description.isNotEmpty) ...[
                          Text(
                            project.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.page),
                        ],
                        if (widget.viewModel.saving) ...[
                          const AppLoading(
                            label: 'Đang xử lý project…',
                            compact: true,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                        ],
                        if (widget.viewModel.saveError.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppMessage(message: widget.viewModel.saveError),
                        ],
                        if (widget.viewModel.projectError.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppMessage(
                            message: widget.viewModel.projectError,
                            type: AppMessageType.warning,
                          ),
                        ],
                        Text(
                          'Repository đang theo dõi (${project.repositories.length})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.page),
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
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );

  Widget _repositoryCard(BuildContext context, ProjectRepo repo) {
    final run = actions.latestRuns[repo.id];
    final error = actions.errors[repo.id];
    final theme = Theme.of(context);
    final failed =
        run != null &&
        [
          WorkflowState.failure,
          WorkflowState.timedOut,
        ].contains(WorkflowState.fromGitHub(run.status, run.conclusion));
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RepositoryRunsView(
              repo: repo,
              projectName: project?.name ?? 'Project',
              repository: repository,
              accessToken: widget.viewModel.accessToken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Row(
                    children: [
                      Icon(
                        Icons.source_outlined,
                        color: failed
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.small,
                          runSpacing: AppSpacing.small,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Tooltip(
                              message: repo.fullName,
                              child: Text(
                                repo.fullName.split('/').last,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            if (run != null && run.branch.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: failed
                                      ? theme.colorScheme.errorContainer
                                      : theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  run.branch,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'GeistMono',
                                    color: failed
                                        ? theme.colorScheme.onErrorContainer
                                        : theme.colorScheme.onSurfaceVariant,
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
                    color: failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
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
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            run.sha.length > 7
                                ? run.sha.substring(0, 7)
                                : run.sha,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'GeistMono',
                              color: theme.colorScheme.onSurfaceVariant,
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
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.medium),
                  child: AppEmptyState(
                    message: 'Chưa có lần chạy GitHub Actions.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
