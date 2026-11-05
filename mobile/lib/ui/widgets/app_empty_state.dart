import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

/// Modern empty state display with icon illustration and call-to-action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide actionLabel and onAction together.',
       );

  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final displayIcon = icon ?? Icons.inbox_outlined;

    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.section,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(displayIcon, size: 34, color: colors.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(height: AppSpacing.page),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
