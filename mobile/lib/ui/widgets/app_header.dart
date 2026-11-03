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
    title: Image.asset(
      'assets/logo/logo.png',
      width: 96,
      height: 64,
      // The source has transparent margins. Cover keeps the logo readable here.
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.1),
      cacheWidth: 384,
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
