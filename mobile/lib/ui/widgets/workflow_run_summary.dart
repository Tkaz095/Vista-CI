import 'package:flutter/material.dart';

import '../../data/models/workflow_run.dart';
import '../theme/app_theme.dart';
import 'workflow_status_badge.dart';

class WorkflowRunSummary extends StatelessWidget {
  const WorkflowRunSummary({super.key, required this.run});
  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = run.createdAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(run.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            WorkflowStatusBadge(status: run.status, conclusion: run.conclusion),
            Text(
              '${run.workflowName} #${run.number} · lần ${run.attempt}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          [
            run.branch.isEmpty ? 'Không rõ nhánh' : run.branch,
            if (run.sha.isNotEmpty)
              run.sha.length > 7 ? run.sha.substring(0, 7) : run.sha,
            if (run.event.isNotEmpty) run.event,
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: 4),
          Text(
            '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Relative time in lists, with the complete local date available on long press.
class WorkflowRunTime extends StatelessWidget {
  const WorkflowRunTime({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final complete =
        '${localizations.formatFullDate(local)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    final elapsed = DateTime.now().difference(local);
    final label = switch (elapsed) {
      _ when elapsed.isNegative => complete,
      _ when elapsed.inMinutes < 1 => 'Vừa xong',
      _ when elapsed.inHours < 1 => '${elapsed.inMinutes} phút trước',
      _ when elapsed.inDays < 1 => '${elapsed.inHours} giờ trước',
      _ when elapsed.inDays < 7 => '${elapsed.inDays} ngày trước',
      _ =>
        '${localizations.formatMediumDate(local)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
    };
    return Tooltip(
      message: complete,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
