import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AstroManagerShell extends StatefulWidget {
  const AstroManagerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AstroManagerShell> createState() => _AstroManagerShellState();
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _NavigationItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  _NavigationItem(
    label: 'Targets',
    icon: Icons.travel_explore_outlined,
    selectedIcon: Icons.travel_explore,
  ),
  _NavigationItem(
    label: 'Night Planner',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
  _NavigationItem(
    label: 'Equipment',
    icon: Icons.camera_alt_outlined,
    selectedIcon: Icons.camera_alt,
  ),
  _NavigationItem(
    label: 'Projects',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
  ),
  _NavigationItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

class _AstroManagerShellState extends State<AstroManagerShell> {
  static const _desktopBreakpoint = 840.0;
  static const _expandedBreakpoint = 1200.0;
  static const _settingsIndex = 5;

  int _lastMainIndex = 0;

  void _navigateTo(int index) {
    final current = widget.navigationShell.currentIndex;

    if (current < _settingsIndex) {
      _lastMainIndex = current;
    }

    widget.navigationShell.goBranch(index, initialLocation: index == current);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        final isExpanded = constraints.maxWidth >= _expandedBreakpoint;

        final selectedIndex = widget.navigationShell.currentIndex;

        final isSettings = selectedIndex == _settingsIndex;

        return Scaffold(
          appBar: AppBar(
            title: AppText(_destinations[selectedIndex].label),
            leading: !isDesktop && isSettings
                ? IconButton(
                    tooltip: appTranslate(context, 'Back to previous section'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _navigateTo(_lastMainIndex),
                  )
                : null,
            actions: [
              if (!isDesktop && !isSettings)
                IconButton(
                  tooltip: appTranslate(context, 'Open settings'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _navigateTo(_settingsIndex),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: isDesktop
              ? Row(
                  children: [
                    NavigationRail(
                      extended: isExpanded,
                      labelType: isExpanded
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: _navigateTo,
                      destinations: [
                        for (final item in _destinations)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: AppText(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: widget.navigationShell),
                  ],
                )
              : widget.navigationShell,
          bottomNavigationBar: isDesktop || isSettings
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: _navigateTo,
                  destinations: [
                    for (final item in _destinations.take(_settingsIndex))
                      NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: appTranslate(context, item.label),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
