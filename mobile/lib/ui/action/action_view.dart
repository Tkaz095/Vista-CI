import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Temporary tab content. Home supplies the header and bottom tabs.
class ActionView extends StatelessWidget {
  const ActionView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GitHub Actions',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Lịch sử workflow sẽ được bổ sung sau.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
