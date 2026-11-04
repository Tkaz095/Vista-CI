import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Spinner plus stable placeholder cards, without adding an animation package.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, required this.label, this.compact = false});
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: MediaQuery.disableAnimationsOf(context)
                      ? const Icon(Icons.hourglass_empty, size: 20)
                      : const CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.control),
                Expanded(child: Text(label)),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.page),
              for (var card = 0; card < 3; card++)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.card),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final width in [0.7, 1.0, 0.45])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: FractionallySizedBox(
                              widthFactor: width,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
