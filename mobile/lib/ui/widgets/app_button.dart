import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, danger, text }

/// Loading belongs to the caller; this button only displays it and blocks taps.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.style,
    this.isLoading = false,
    this.loadingLabel = 'Đang xử lý…',
    this.variant = AppButtonVariant.primary,
  }) : assert(icon == null || iconWidget == null, 'Use icon or iconWidget.');

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? iconWidget;
  final ButtonStyle? style;
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
          child: MediaQuery.disableAnimationsOf(context)
              ? Icon(
                  Icons.hourglass_empty,
                  size: 20,
                  color: theme.disabledColor,
                )
              : CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.disabledColor,
                ),
        ),
      );
    } else if (icon != null) {
      leading = Icon(icon);
    } else {
      leading = iconWidget;
    }

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton.icon(
        style: style,
        onPressed: callback,
        icon: leading,
        label: text,
      ),
      AppButtonVariant.secondary => OutlinedButton.icon(
        style: style,
        onPressed: callback,
        icon: leading,
        label: text,
      ),
      AppButtonVariant.text => TextButton.icon(
        style: style,
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
        ).merge(style),
      ),
    };
    return Semantics(liveRegion: isLoading, child: button);
  }
}
