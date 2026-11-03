import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, danger, text }

/// Loading belongs to the caller; this button only displays it and blocks taps.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.loadingLabel = 'Đang xử lý…',
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final String loadingLabel;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final callback = isLoading ? null : onPressed;
    final text = Text(isLoading ? loadingLabel : label);
    Widget? leading;
    if (isLoading) {
      leading = ExcludeSemantics(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.disabledColor,
          ),
        ),
      );
    } else if (icon != null) {
      leading = Icon(icon);
    }

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton.icon(
        onPressed: callback,
        icon: leading,
        label: text,
      ),
      AppButtonVariant.secondary => OutlinedButton.icon(
        onPressed: callback,
        icon: leading,
        label: text,
      ),
      AppButtonVariant.text => TextButton.icon(
        onPressed: callback,
        icon: leading,
        label: text,
      ),
      AppButtonVariant.danger => FilledButton.icon(
        onPressed: callback,
        icon: leading,
        label: text,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
          disabledBackgroundColor: theme.colorScheme.surfaceContainerLow,
          disabledForegroundColor: theme.disabledColor,
        ),
      ),
    };
    return Semantics(liveRegion: isLoading, child: button);
  }
}
