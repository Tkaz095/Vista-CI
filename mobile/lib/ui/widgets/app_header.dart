import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_theme_controller.dart';

/// The header for top-level screens.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.showNotifications = true,
    this.onNotificationsPressed,
    this.actions = const [],
    this.unreadCount = 0,
  });

  final bool showNotifications;
  final int unreadCount;
  final VoidCallback? onNotificationsPressed;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: AppSpacing.page,
      toolbarHeight: preferredSize.height,
      backgroundColor: theme.colorScheme.surface,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      title: Image.asset(
        isDark
            ? 'assets/logo/logo-on-header-dark.png'
            : 'assets/logo/logo-on-header.png',
        width: 128,
        height: 40,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        cacheWidth: 512,
        semanticLabel: 'Vista',
      ),
    actions: [
      ListenableBuilder(
        listenable: AppThemeController.instance,
        builder: (context, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return IconButton(
            tooltip:
                isDark ? 'Chuyển sang chế độ sáng' : 'Chuyển sang chế độ tối',
            onPressed: () {
              HapticFeedback.selectionClick();
              AppThemeController.instance.toggleTheme(isDark);
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 22,
            ),
          );
        },
      ),
      if (showNotifications)
        IconButton(
          tooltip: onNotificationsPressed == null
              ? 'Thông báo chưa sẵn sàng'
              : 'Thông báo',
          onPressed: onNotificationsPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onNotificationsPressed!();
                },
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            backgroundColor: Theme.of(context).colorScheme.error,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_outlined, size: 24),
          ),
        ),
      ...actions,
      const SizedBox(width: AppSpacing.medium),
    ],
  );
}
}
