import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_shimmer.dart';

/// Shimmer placeholder cards plus accessible status indicator.
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
                      : CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(colors.primary),
                        ),
                ),
                const SizedBox(width: AppSpacing.control),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.page),
              AppShimmer(
                child: Column(
                  children: [
                    for (var card = 0; card < 3; card++)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                        padding: const EdgeInsets.all(AppSpacing.card),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.medium),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: 0.6,
                                        child: Container(
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: colors.surfaceContainerLow,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FractionallySizedBox(
                                        widthFactor: 0.35,
                                        child: Container(
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: colors.surfaceContainerLow,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
