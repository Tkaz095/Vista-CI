import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/project.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../settings/app_config_view_model.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/workflow_run_summary.dart';
import '../widgets/workflow_status_badge.dart';
import 'repository_runs_view_model.dart';
import 'workflow_run_detail_view.dart';

class RepositoryRunsView extends StatefulWidget {
  const RepositoryRunsView({
    super.key,
    required this.repo,
    required this.projectName,
    required this.repository,
    required this.accessToken,
    this.telemetry,
    this.configuration,
    this.ownerUid,
  });
  final ProjectRepo repo;
  final String projectName;
  final GitHubActionsRepository repository;
  final String? accessToken;
  final AppTelemetry? telemetry;
  final AppConfigViewModel? configuration;
  final String? ownerUid;

  @override
  State<RepositoryRunsView> createState() => _RepositoryRunsViewState();
}

class _RepositoryRunsViewState extends State<RepositoryRunsView> {
  late final RepositoryRunsViewModel model;

  @override
  void initState() {
    super.initState();
    model = RepositoryRunsViewModel(
      widget.repository,
      repo: widget.repo,
      accessToken: widget.accessToken,
    );
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> _openGitHub() async {
    try {
      if (await launchUrl(
        widget.repo.githubUrl,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Display the same message when the browser cannot open. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa mở được GitHub. Hãy thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppStackHeader(
        title: 'Lịch sử chạy',
        actions: [
          IconButton(
            tooltip: 'Mở repo GitHub',
            onPressed: _openGitHub,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: model,
          builder: (context, _) => RefreshIndicator(
            onRefresh: () => model.load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                _repositoryInfo(context),
                const SizedBox(height: AppSpacing.page),
                Text('Trạng thái', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.small),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final filter in RunFilter.values)
                      ChoiceChip(
                        label: Text(filter.label),
                        selected: model.filter == filter,
                        showCheckmark: false,
                        onSelected: (_) => model.selectFilter(filter),
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: model.filter == filter
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        selectedColor: theme.colorScheme.primaryContainer,
                        labelStyle: theme.textTheme.bodySmall?.copyWith(
                          color: model.filter == filter
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.page),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Các lần chạy gần đây',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Flexible(
                      child: Text(
                        'Mới nhất trước',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.medium),
                if (model.state.isLoading && model.runs.isEmpty)
                  const AppLoading(label: 'Đang tải lịch sử chạy…')
                else ...[
                  if (model.loading && !model.loadingMore) ...[
                    const AppLoading(
                      label: 'Đang cập nhật lịch sử…',
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                  for (var index = 0; index < model.runs.length; index++) ...[
                    if (index == 0 ||
                        _dayLabel(context, model.runs[index]) !=
                            _dayLabel(context, model.runs[index - 1]))
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.small,
                          bottom: AppSpacing.medium,
                        ),
                        child: Text(
                          _dayLabel(context, model.runs[index]),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    _runCard(context, model.runs[index]),
                  ],
                  if (model.state.hasError) ...[
                    AppMessage(message: model.error),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                  if (model.hasLoaded && model.state.isEmpty)
                    AppEmptyState(
                      message: model.filter == RunFilter.all
                          ? 'Repository chưa có lần chạy GitHub Actions.'
                          : 'Không có lần chạy ở trạng thái đã chọn.',
                    ),
                  if (model.hasMore)
                    AppButton(
                      label: 'Xem thêm lần chạy',
                      loadingLabel: 'Đang tải thêm…',
                      isLoading: model.loadingMore,
                      onPressed: model.loading
                          ? null
                          : () => model.load(more: true),
                      variant: AppButtonVariant.secondary,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _repositoryInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.source_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.small),
                Flexible(
                  child: Text(
                    'GitHub Actions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Tooltip(
              message: widget.repo.fullName,
              child: Text(
                widget.repo.fullName.split('/').last,
                style: theme.textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(widget.projectName)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(BuildContext context, WorkflowRun run) {
    final now = DateTime.now();
    final local = run.createdAt?.toLocal();
    if (local == null) return 'Không rõ ngày';
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Hôm nay';
    if (day == DateTime(now.year, now.month, now.day - 1)) return 'Hôm qua';
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }

  Widget _runCard(BuildContext context, WorkflowRun run) {
    final theme = Theme.of(context);
    final status = WorkflowStatusBadge(
      status: run.status,
      conclusion: run.conclusion,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkflowRunDetailView(
              repo: widget.repo,
              run: run,
              repository: widget.repository,
              accessToken: widget.accessToken,
              telemetry: widget.telemetry,
              configuration: widget.configuration,
              ownerUid: widget.ownerUid,
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
                  final title = Text(
                    run.workflowName,
                    style: theme.textTheme.titleMedium,
                  );
                  if (constraints.maxWidth >= 260 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18) {
                    return Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: AppSpacing.small),
                        status,
                      ],
                    );
                  }
                  return Wrap(
                    spacing: AppSpacing.small,
                    runSpacing: AppSpacing.small,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [title, status],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.control),
              Text(
                'Lần chạy #${run.number}${run.attempt > 1 ? ' · lần ${run.attempt}' : ''}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                run.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.control),
              Text(
                [
                  if (run.branch.isNotEmpty) run.branch,
                  if (run.sha.isNotEmpty)
                    run.sha.length > 7 ? run.sha.substring(0, 7) : run.sha,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'GeistMono',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (run.createdAt != null) ...[
                const SizedBox(height: AppSpacing.small),
                WorkflowRunTime(date: run.createdAt!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
