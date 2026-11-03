import 'package:flutter/material.dart';

/// A stack screen has its own title and returns to the previous route.
class AppStackHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppStackHeader({super.key, required this.title, this.canGoBack = true});

  final String title;
  final bool canGoBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: false,
    toolbarHeight: preferredSize.height,
    backgroundColor: Theme.of(context).colorScheme.surface,
    leading: IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: canGoBack ? () => Navigator.of(context).maybePop() : null,
      icon: const Icon(Icons.arrow_back),
    ),
    title: Tooltip(
      message: title,
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
