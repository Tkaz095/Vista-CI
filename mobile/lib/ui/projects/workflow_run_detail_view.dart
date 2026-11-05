import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/project.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../settings/app_config_view_model.dart';
import '../../data/repositories/ci_analysis_repository.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/workflow_run_summary.dart';
import '../widgets/workflow_log_panel.dart';
import 'workflow_run_view_model.dart';
import 'ci_comment_view.dart';
import 'ci_analysis_view.dart';

enum _RunAction { analyze, comment, rerunFailed, rerunAll, latest, github }

class WorkflowRunDetailView extends StatefulWidget {
  const WorkflowRunDetailView({
    super.key,
    required this.repo,
    required this.run,
    required this.repository,
    required this.accessToken,
    this.analysisRepository,
    this.telemetry,
    this.configuration,
    this.ownerUid,
  });
  final ProjectRepo repo;
  final WorkflowRun run;
  final GitHubActionsRepository repository;
  final String? accessToken;
  final CiAnalysisRepository? analysisRepository;
  final AppTelemetry? telemetry;
  final AppConfigViewModel? configuration;
  final String? ownerUid;

  @override
  State<WorkflowRunDetailView> createState() => _WorkflowRunDetailViewState();
}

class _WorkflowRunDetailViewState extends State<WorkflowRunDetailView> {
  late final WorkflowRunViewModel model;
  bool _analysisScreenOpen = false;

  @override
  void initState() {
    super.initState();
    model = WorkflowRunViewModel(
      widget.repository,
      repo: widget.repo,
      run: widget.run,
      accessToken: widget.accessToken,
      analysisRepository: widget.analysisRepository,
      telemetry: widget.telemetry,
      configuration: widget.configuration,
      ownerUid: widget.ownerUid,
    );
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> _openGitHub() async {
    final url = Uri.https(
      'github.com',
      '${widget.repo.fullName}/actions/runs/${model.run.id}/attempts/${model.run.attempt}',
    );
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Keep the failure readable without exposing provider details. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa mở được GitHub. Hãy thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.actionBusy,
      child: Scaffold(
        appBar: AppStackHeader(
          title: '${model.run.workflowName} #${model.run.number}',
          canGoBack: !model.actionBusy,
          actions: [
            PopupMenuButton<_RunAction>(
              tooltip: 'Thao tác CI',
              icon: const Icon(Icons.more_vert),
              enabled:
                  !model.actionBusy &&
                  !model.analyzing &&
                  !model.preparingAnalysis,
              onSelected: _handleAction,
              itemBuilder: (_) => [
                if (model.analysisEnabled &&
                    model.hasFailedJobs &&
                    model.analysis == null)
                  PopupMenuItem(
                    value: _RunAction.analyze,
                    enabled: model.canAnalyze,
                    child: const Text('Phân tích lỗi với Gemini'),
                  ),
                if (model.analysis != null)
                  const PopupMenuItem(
                    value: _RunAction.comment,
                    child: Text('Soạn comment PR'),
                  ),
                PopupMenuItem(
                  value: _RunAction.rerunFailed,
                  enabled:
                      model.canRerun &&
                      ['failure', 'timed_out'].contains(model.run.conclusion),
                  child: const Text('Chạy lại các job lỗi'),
                ),
                PopupMenuItem(
                  value: _RunAction.rerunAll,
                  enabled: model.canRerun,
                  child: const Text('Chạy lại toàn bộ workflow'),
                ),
                PopupMenuItem(
                  value: _RunAction.latest,
                  enabled: !model.loading,
                  child: const Text('Xem attempt mới nhất'),
                ),
                const PopupMenuItem(
                  value: _RunAction.github,
                  child: Text('Mở run trên GitHub'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Builder(
            builder: (context) {
              final details = model.details;
              return RefreshIndicator(
                onRefresh: model.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Text(
                      widget.repo.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    if (!model.analysisEnabled) ...[
                      const AppMessage(
                        message: 'Tính năng phân tích CI mới đang tạm tắt.',
                        type: AppMessageType.info,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (model.actionBusy) ...[
                      const AppLoading(
                        label: 'Đang gửi yêu cầu chạy lại…',
                        compact: true,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (model.actionError.isNotEmpty) ...[
                      AppMessage(message: model.actionError),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (model.actionMessage.isNotEmpty) ...[
                      AppMessage(
                        message: model.actionMessage,
                        type: AppMessageType.info,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (model.state.isLoading && details == null)
                      const AppLoading(label: 'Đang tải đầy đủ job và step…')
                    else ...[
                      if (model.loading) ...[
                        const AppLoading(
                          label: 'Đang cập nhật job và step…',
                          compact: true,
                        ),
                        const SizedBox(height: AppSpacing.medium),
                      ],
                      if (model.state.hasError) ...[
                        AppMessage(message: model.error),
                        const SizedBox(height: AppSpacing.medium),
                      ],
                      if (details != null) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.card),
                            child: WorkflowRunSummary(run: details.run),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.page),
                        if (model.hasFailedJobs &&
                            details.run.status == 'completed') ...[
                          _analysisSection(context),
                          const SizedBox(height: AppSpacing.page),
                        ],
                        if (details.jobs.isNotEmpty)
                          _logSection(context)
                        else
                          const AppEmptyState(
                            message: 'GitHub chưa trả về job cho lần thực thi này. Kéo xuống để cập nhật.',
                          ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  void _handleAction(_RunAction action) {
    switch (action) {
      case _RunAction.analyze:
        _openAnalysis(startAnalysis: true);
      case _RunAction.comment:
        _openComment();
      case _RunAction.rerunFailed:
        _confirmRerun(failedOnly: true);
      case _RunAction.rerunAll:
        _confirmRerun(failedOnly: false);
      case _RunAction.latest:
        model.showLatestAttempt();
      case _RunAction.github:
        _openGitHub();
    }
  }

  Future<bool> _confirmRerun({required bool failedOnly}) async {
    if (!model.canRerun) return false;
    final accepted = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          failedOnly ? 'Chạy lại các job lỗi?' : 'Chạy lại toàn bộ workflow?',
        ),
        content: SingleChildScrollView(
          child: Text(
            '${widget.repo.fullName}\n${model.run.workflowName} #${model.run.number} — attempt ${model.run.attempt}\n\nCommit: ${model.run.sha}\n\nGitHub dùng lại commit này. Các job phụ thuộc cũng có thể chạy lại.',
          ),
        ),
        actions: [
          AppButton(
            label: 'Hủy',
            onPressed: () => Navigator.pop(context, false),
            variant: AppButtonVariant.text,
          ),
          AppButton(
            label: 'Chạy lại',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return false;
    return model.rerun(failedOnly: failedOnly);
  }

  Future<void> _openAnalysis({bool startAnalysis = false}) async {
    if (_analysisScreenOpen) return;
    _analysisScreenOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CiAnalysisView(
            model: model,
            startAnalysis: startAnalysis,
            onRerun: (failedOnly) => _confirmRerun(failedOnly: failedOnly),
          ),
        ),
      );
    } finally {
      _analysisScreenOpen = false;
    }
  }

  void _openComment() {
    if (model.analysis == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CiCommentView(model: model)),
    );
  }

  Widget _analysisSection(BuildContext context) {
    final theme = Theme.of(context);
    final result = model.analysis;
    final preparing = model.preparingAnalysis || model.analyzing;
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    'Phân tích lỗi CI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.control),
            if (model.readingAnalysis)
              const AppLoading(
                label: 'Đang đọc phân tích đã lưu…',
                compact: true,
              )
            else if (preparing)
              AppLoading(
                label: model.preparingAnalysis
                    ? 'Đang chuẩn bị log…'
                    : 'Gemini đang phân tích…',
                compact: true,
              )
            else
              Text(
                result?.summary ??
                    'Xem tóm tắt lỗi, bằng chứng và hướng xử lý.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.medium),
            AppButton(
              label: result != null
                  ? 'Xem phân tích'
                  : preparing
                  ? 'Xem tiến trình phân tích'
                  : 'Phân tích lỗi với Gemini',
              onPressed: model.actionBusy
                  ? null
                  : () => _openAnalysis(
                      startAnalysis: result == null && model.canAnalyze,
                    ),
              icon: result != null || preparing
                  ? Icons.arrow_forward
                  : Icons.auto_awesome_outlined,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.tertiary,
                foregroundColor: theme.colorScheme.onTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logSection(BuildContext context, {bool fullScreen = false}) =>
      WorkflowLogPanel(
        jobs: model.details?.jobs ?? [],
        logs: model.logs,
        errors: model.logErrors,
        loadingJobs: model.loadingJobs,
        onLoadJob: model.loadJobLog,
        initialJobId: model.initialJobId,
        fullScreen: fullScreen,
        onOpen: fullScreen ? null : _openLog,
      );

  void _openLog() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: const AppStackHeader(title: 'Log GitHub Actions'),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) => RefreshIndicator(
              onRefresh: model.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  if (model.error.isNotEmpty) AppMessage(message: model.error),
                  _logSection(context, fullScreen: true),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
