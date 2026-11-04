import 'package:flutter/material.dart';

import '../../data/models/ci_analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import 'ci_comment_view.dart';
import 'workflow_run_view_model.dart';

/// The workflow screen owns the ViewModel; this route only presents its analysis.
class CiAnalysisView extends StatefulWidget {
  const CiAnalysisView({
    super.key,
    required this.model,
    required this.onRerun,
    this.startAnalysis = false,
  });

  final WorkflowRunViewModel model;
  final Future<bool> Function(bool failedOnly) onRerun;
  final bool startAnalysis;

  @override
  State<CiAnalysisView> createState() => _CiAnalysisViewState();
}

class _CiAnalysisViewState extends State<CiAnalysisView> {
  WorkflowRunViewModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    if (widget.startAnalysis) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _analyze();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final theme = Theme.of(context);
      final result = model.analysis;
      final busy = model.actionBusy || model.postingComment;
      final preparing = model.preparingAnalysis || model.analyzing;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppStackHeader(title: 'Phân tích CI', canGoBack: !busy),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  Text(model.repo.fullName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '${model.run.workflowName} #${model.run.number} · attempt ${model.run.attempt}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Tooltip(
                    message: model.run.sha,
                    child: Text(
                      '${model.run.branch} · ${model.run.sha.length > 7 ? model.run.sha.substring(0, 7) : model.run.sha}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'GeistMono',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  if (!model.analysisEnabled) ...[
                    const AppMessage(
                      message: 'Tính năng phân tích CI mới đang tạm tắt.',
                      type: AppMessageType.info,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                  if (model.actionBusy)
                    const AppLoading(
                      label: 'Đang gửi yêu cầu chạy lại…',
                      compact: true,
                    ),
                  if (model.actionError.isNotEmpty) ...[
                    AppMessage(message: model.actionError),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                  if (model.error.isNotEmpty) ...[
                    AppMessage(message: model.error),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                  if (result != null)
                    _result(context, result)
                  else if (preparing || model.readingAnalysis || model.loading)
                    AppLoading(
                      label: model.preparingAnalysis
                          ? 'Đang chuẩn bị log…'
                          : model.analyzing
                          ? 'Gemini đang phân tích…'
                          : 'Đang đọc thông tin phân tích…',
                    )
                  else ...[
                    Text(
                      'Hiểu lỗi từ log CI',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    const Text(
                      'Gemini sẽ tóm tắt lỗi, trích dẫn log và đề xuất hướng xử lý. Bạn được xem trước log trước khi gửi.',
                    ),
                    const SizedBox(height: AppSpacing.page),
                    AppButton(
                      label: 'Phân tích lỗi với Gemini',
                      icon: Icons.auto_awesome_outlined,
                      onPressed: model.canAnalyze ? _analyze : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.tertiary,
                        foregroundColor: theme.colorScheme.onTertiary,
                      ),
                    ),
                  ],
                  if (model.analysisWarning.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.medium),
                    AppMessage(
                      message: model.analysisWarning,
                      type: AppMessageType.warning,
                    ),
                  ],
                  if (model.analysisError.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.medium),
                    AppMessage(message: model.analysisError),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: _actions(
            context,
            canComment: result != null && !busy && !preparing && !model.loading,
          ),
        ),
      );
    },
  );

  Widget _result(BuildContext context, CiAnalysis result) {
    final theme = Theme.of(context);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tóm tắt lỗi', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.control),
          Text(result.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.section),
          Text('Nguyên nhân có thể', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.small),
          Text(result.probableCause),
          if (result.suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            Text('Hướng xử lý', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.control),
            for (var i = 0; i < result.suggestions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.medium),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}.', style: theme.textTheme.titleSmall),
                    const SizedBox(width: AppSpacing.control),
                    Expanded(child: Text(result.suggestions[i])),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.medium),
          const Divider(),
          if (result.evidence.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.medium),
              title: Text('Bằng chứng từ log (${result.evidence.length})'),
              children: [
                for (final item in result.evidence) _evidence(context, item),
              ],
            ),
          if (result.missingContext.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.medium),
              title: const Text('Cần kiểm tra thêm'),
              children: [
                for (final text in result.missingContext)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.small),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(text),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.page),
          Text(
            'AI đề xuất, cần kiểm chứng. ${result.incomplete ? 'Phân tích dựa trên trích đoạn log và có thể thiếu ngữ cảnh.' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            '${result.model} · ${MaterialLocalizations.of(context).formatShortDate(result.createdAt.toLocal())}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _evidence(BuildContext context, CiEvidence item) {
    var name = 'Job ${item.jobId}';
    for (final job in model.details?.jobs ?? []) {
      if (job.id == item.jobId) {
        name = job.name;
        break;
      }
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · dòng ${item.line}',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: const Color(0xFFE6EDF3)),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            item.quote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'GeistMono',
              color: const Color(0xFFE6EDF3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, {required bool canComment}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.medium),
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final comment = AppButton(
                label: 'Comment PR',
                icon: Icons.comment_outlined,
                onPressed: canComment ? _openComment : null,
              );
              final rerun = AppButton(
                label: 'Chạy lại CI',
                icon: Icons.replay,
                variant: AppButtonVariant.secondary,
                onPressed: model.canRerun ? _chooseRerun : null,
                isLoading: model.actionBusy,
              );
              if (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    comment,
                    const SizedBox(height: AppSpacing.small),
                    rerun,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: comment),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(child: rerun),
                ],
              );
            },
          ),
        ),
      );

  Future<void> _analyze() async {
    final input = await model.prepareAnalysis();
    if (input == null) return;
    if (!mounted) {
      model.cancelAnalysisPreview();
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .9,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log sẽ gửi cho Gemini',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.medium),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App đã che các mẫu token/mật khẩu phổ biến. Hãy kiểm tra trích đoạn trước khi gửi.',
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          'Đã chọn ${input.logs.length}/${input.failedJobCount} job lỗi. ${input.incomplete ? 'Đang dùng trích đoạn, có thể thiếu ngữ cảnh.' : ''}',
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        for (final log in input.logs) ...[
                          Text(
                            log.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.small),
                          Text(
                            log.lines.entries
                                .map((entry) => '${entry.key}: ${entry.value}')
                                .join('\n'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontFamily: 'GeistMono'),
                          ),
                          const SizedBox(height: AppSpacing.page),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  AppButton(
                    label: 'Hủy',
                    onPressed: () => Navigator.pop(context, false),
                    variant: AppButtonVariant.text,
                  ),
                  AppButton(
                    label: 'Gửi để phân tích',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      model.cancelAnalysisPreview();
      return;
    }
    if (confirmed == true) {
      await model.analyze();
    } else {
      model.cancelAnalysisPreview();
    }
  }

  void _openComment() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => CiCommentView(model: model)));

  Future<void> _refresh() async {
    final previousAttempt = model.run.attempt;
    await model.load();
    if (mounted && model.run.attempt != previousAttempt) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _chooseRerun() async {
    final failedOnly = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Text(
                'Chạy lại CI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (model.hasFailedJobs &&
                ['failure', 'timed_out'].contains(model.run.conclusion))
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Chạy lại các job lỗi'),
                subtitle: const Text('Các job phụ thuộc cũng có thể chạy lại.'),
                onTap: () => Navigator.pop(context, true),
              ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Chạy lại toàn bộ workflow'),
              subtitle: const Text('Chạy lại tất cả job trên cùng commit.'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (failedOnly == null || !mounted) return;
    final accepted = await widget.onRerun(failedOnly);
    // The old analysis belongs to the old attempt. Follow the new one on the run.
    if (accepted && mounted) Navigator.of(context).pop();
  }
}
