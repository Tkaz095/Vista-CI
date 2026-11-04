import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/workflow_run.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_loading.dart';
import 'app_message.dart';

class WorkflowLogColors {
  static const background = Color(0xFF0D1117);
  static const header = Color(0xFF292F38);
  static const border = Color(0xFF30363D);
  static const text = Color(0xFFE6EDF3);
  static const muted = Color(0xFF8B949E);
  static const link = Color(0xFF58A6FF);
  static const error = Color(0xFFFF7B72);
  static const errorBackground = Color(0xFF351C24);
  static const success = Color(0xFF3FB950);
}

/// Jobs and provider log groups are folded inside one dark, always-wrapped terminal.
class WorkflowLogPanel extends StatefulWidget {
  const WorkflowLogPanel({
    super.key,
    required this.jobs,
    required this.logs,
    required this.errors,
    required this.loadingJobs,
    required this.onLoadJob,
    this.initialJobId,
    this.fullScreen = false,
    this.onOpen,
  });
  final List<WorkflowJob> jobs;
  final Map<int, WorkflowLog> logs;
  final Map<int, String> errors;
  final Set<int> loadingJobs;
  final Future<void> Function(int jobId) onLoadJob;
  final int? initialJobId;
  final bool fullScreen;
  final VoidCallback? onOpen;

  @override
  State<WorkflowLogPanel> createState() => _WorkflowLogPanelState();
}

class _WorkflowLogPanelState extends State<WorkflowLogPanel> {
  final ScrollController verticalScroll = ScrollController();

  @override
  void dispose() {
    verticalScroll.dispose();
    super.dispose();
  }

  Future<void> _copy(WorkflowLog log) async {
    await Clipboard.setData(ClipboardData(text: log.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép phần log của job đang hiển thị.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: WorkflowLogColors.link,
        surface: WorkflowLogColors.background,
        onSurface: WorkflowLogColors.text,
        onSurfaceVariant: WorkflowLogColors.muted,
        error: WorkflowLogColors.error,
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: WorkflowLogColors.text,
        displayColor: WorkflowLogColors.text,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: WorkflowLogColors.text,
        iconColor: WorkflowLogColors.muted,
      ),
      dividerColor: Colors.transparent,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WorkflowLogColors.link,
      ),
    );
    return Theme(
      data: dark,
      child: Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.all(AppSpacing.small),
          decoration: BoxDecoration(
            color: WorkflowLogColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WorkflowLogColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.small),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Log GitHub Actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (widget.onOpen != null)
                      AppButton(
                        label: 'Mở log',
                        onPressed: widget.onOpen,
                        icon: Icons.open_in_full,
                        variant: AppButtonVariant.text,
                        style: TextButton.styleFrom(
                          foregroundColor: WorkflowLogColors.link,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: widget.fullScreen
                    ? MediaQuery.sizeOf(context).height * 0.7
                    : 440,
                child: Scrollbar(
                  controller: verticalScroll,
                  child: SingleChildScrollView(
                    controller: verticalScroll,
                    primary: false,
                    child: Column(
                      children: [
                        for (final job in widget.jobs) _job(context, job),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _job(BuildContext context, WorkflowJob job) {
    final state = WorkflowState.fromGitHub(job.status, job.conclusion);
    final success = state == WorkflowState.success;
    final failed =
        state == WorkflowState.failure || state == WorkflowState.timedOut;
    final icon = success
        ? Icons.check_circle
        : failed
        ? Icons.error
        : Icons.schedule;
    final color = success
        ? WorkflowLogColors.success
        : failed
        ? WorkflowLogColors.error
        : WorkflowLogColors.muted;
    final duration = job.startedAt != null && job.completedAt != null
        ? job.completedAt!.difference(job.startedAt!)
        : null;
    final log = widget.logs[job.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ExpansionTile(
        key: PageStorageKey('terminal-job-${job.id}'),
        initiallyExpanded: widget.initialJobId == job.id,
        maintainState: true,
        onExpansionChanged: (open) {
          if (open) widget.onLoadJob(job.id);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        collapsedBackgroundColor: WorkflowLogColors.header,
        backgroundColor: WorkflowLogColors.header,
        collapsedIconColor: WorkflowLogColors.text,
        iconColor: WorkflowLogColors.text,
        collapsedTextColor: WorkflowLogColors.text,
        textColor: WorkflowLogColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        leading: Icon(
          icon,
          color: color,
          size: 18,
          semanticLabel: job.conclusion ?? job.status,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                job.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (duration != null && !duration.isNegative) ...[
              const SizedBox(width: 8),
              Text(
                '${duration.inSeconds}s',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
        children: [
          Container(
            color: WorkflowLogColors.background,
            padding: const EdgeInsets.all(AppSpacing.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.loadingJobs.contains(job.id))
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: AppLoading(label: 'Đang tải log…', compact: true),
                  ),
                if (widget.errors[job.id] != null)
                  AppMessage(message: widget.errors[job.id]!),
                if (log != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: 'Sao chép',
                      onPressed: () => _copy(log),
                      icon: Icons.copy_outlined,
                      variant: AppButtonVariant.text,
                      style: TextButton.styleFrom(
                        foregroundColor: WorkflowLogColors.link,
                      ),
                    ),
                  ),
                  if (log.text.isEmpty) const Text('Job chưa có nội dung log.'),
                  for (final section in log.sections)
                    _section(context, section, job.id),
                  if (log.truncated)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Đang hiển thị tối đa 1.000 dòng đầu hoặc 256 KiB. Mở run trên GitHub để xem log đầy đủ.',
                        style: TextStyle(
                          color: WorkflowLogColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, WorkflowLogSection section, int jobId) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: _text(section),
    );
    if (section.title == null) return content;
    return Material(
      color: WorkflowLogColors.background,
      child: ExpansionTile(
        key: PageStorageKey('log-$jobId-${section.startLine}'),
        initiallyExpanded: _isError(section.text),
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        collapsedIconColor: WorkflowLogColors.muted,
        iconColor: WorkflowLogColors.text,
        title: Text(
          section.title!,
          style: const TextStyle(
            color: WorkflowLogColors.text,
            fontSize: 12,
            fontFamily: 'GeistMono',
          ),
        ),
        children: [content],
      ),
    );
  }

  bool _isError(String line) {
    final lower = line.toLowerCase();
    return lower.contains('##[error]') ||
        lower.contains('[error]') ||
        lower.contains('[fail]');
  }

  Widget _text(WorkflowLogSection section) {
    final lines = section.text.split('\n');
    final spans = <TextSpan>[];
    for (var index = 0; index < lines.length; index++) {
      spans.add(
        TextSpan(
          text: '${section.startLine + index}  ',
          style: const TextStyle(color: WorkflowLogColors.muted),
        ),
      );
      spans.add(
        TextSpan(
          text: '${lines[index]}${index == lines.length - 1 ? '' : '\n'}',
          style: _isError(lines[index])
              ? const TextStyle(
                  color: WorkflowLogColors.error,
                  backgroundColor: WorkflowLogColors.errorBackground,
                )
              : null,
        ),
      );
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontFamily: 'GeistMono',
        fontSize: 12,
        height: 1.65,
        color: WorkflowLogColors.text,
      ),
    );
  }
}
