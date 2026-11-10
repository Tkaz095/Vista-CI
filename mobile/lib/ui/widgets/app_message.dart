import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppMessageType { info, success, warning, error }

class AppMessage extends StatelessWidget {
  const AppMessage({
    super.key,
    required this.message,
    this.type = AppMessageType.error,
  });

  final String message;
  final AppMessageType type;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final (color, icon) = switch (type) {
      AppMessageType.info => (colors.primary, Icons.info_outline),
      AppMessageType.success => (AppColors.success, Icons.check_circle_outline),
      AppMessageType.warning => (
        AppColors.warning,
        Icons.warning_amber_outlined,
      ),
      AppMessageType.error => (colors.error, Icons.error_outline),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
