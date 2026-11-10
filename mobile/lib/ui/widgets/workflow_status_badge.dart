import 'package:flutter/material.dart';

import '../../data/models/workflow_run.dart';
import '../theme/app_theme.dart';

class WorkflowStatusBadge extends StatelessWidget {
  const WorkflowStatusBadge({super.key, required this.status, this.conclusion});
  final String status;
  final String? conclusion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (
      label,
      icon,
      background,
      foreground,
    ) = switch (WorkflowState.fromGitHub(status, conclusion)) {
      WorkflowState.success => (
        'Thành công',
        Icons.check_circle_outline,
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      WorkflowState.failure => (
        'Thất bại',
        Icons.error_outline,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      WorkflowState.timedOut => (
        'Hết thời gian',
        Icons.timer_off_outlined,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      WorkflowState.running => (
        'Đang chạy',
        Icons.sync,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      WorkflowState.queued => (
        'Đang chờ',
        Icons.schedule,
        colors.surfaceContainerLow,
        colors.onSurfaceVariant,
      ),
      WorkflowState.waiting => (
        'Chờ tiếp tục',
        Icons.pause_circle_outline,
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      WorkflowState.actionRequired => (
        'Cần xử lý',
        Icons.warning_amber_outlined,
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      WorkflowState.cancelled => (
        'Đã hủy',
        Icons.cancel_outlined,
        colors.surfaceContainerLow,
        colors.onSurfaceVariant,
      ),
      WorkflowState.skipped => (
        'Bỏ qua',
        Icons.skip_next_outlined,
        colors.surfaceContainerLow,
        colors.onSurfaceVariant,
      ),
      WorkflowState.neutral => (
        'Trung tính',
        Icons.remove_circle_outline,
        colors.surfaceContainerLow,
        colors.onSurfaceVariant,
      ),
      WorkflowState.unknown => (
        'Chưa rõ',
        Icons.help_outline,
        colors.surfaceContainerLow,
        colors.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: foreground.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
