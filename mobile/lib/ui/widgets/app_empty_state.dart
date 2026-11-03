import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide actionLabel and onAction together.',
       );

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (onAction != null) ...[
          const SizedBox(height: AppSpacing.medium),
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: AppButtonVariant.secondary,
          ),
        ],
      ],
    ),
  );
}
