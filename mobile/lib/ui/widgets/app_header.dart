import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The header for top-level screens. Notifications stay disabled until connected.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.showNotifications = true,
    this.onNotificationsPressed,
    this.actions = const [],
  });

  final bool showNotifications;
  final VoidCallback? onNotificationsPressed;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: false,
    titleSpacing: AppSpacing.page,
    toolbarHeight: preferredSize.height,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: Border(
      bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    title: Image.asset(
      'assets/logo/logo-on-header.png',
      width: 128,
      height: 40,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      cacheWidth: 512,
      semanticLabel: 'Vista',
    ),
    actions: [
      if (showNotifications)
        IconButton(
          tooltip: onNotificationsPressed == null
              ? 'Thông báo (chưa triển khai)'
              : 'Thông báo',
          onPressed: onNotificationsPressed,
          icon: const Icon(Icons.notifications_outlined),
        ),
      ...actions,
      const SizedBox(width: AppSpacing.medium),
    ],
  );
}
