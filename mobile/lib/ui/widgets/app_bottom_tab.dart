import 'package:flutter/material.dart';

enum AppTab { projects, action, profile }

/// Only reports the selected tab. The parent screen owns its content and state.
class AppBottomTab extends StatelessWidget {
  const AppBottomTab({
    super.key,
    required this.selectedTab,
    required this.onSelected,
  });

  final AppTab selectedTab;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Let the bar grow with accessibility text instead of limiting text scaling.
    final extraHeight = MediaQuery.textScalerOf(context).scale(12) - 12;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => theme.textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      child: NavigationBar(
        height: 64 + extraHeight.clamp(0, double.infinity) * 2,
        selectedIndex: selectedTab.index,
        onDestinationSelected: (index) => onSelected(AppTab.values[index]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Action',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
