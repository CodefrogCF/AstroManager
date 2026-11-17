import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  static const _dashboardIndex = 0;
  static const _settingsIndex = 5;

  int _lastMainIndex = _dashboardIndex;
  ({int pointer, Offset start, int direction})? _backSwipe;

  @override
  void didUpdateWidget(covariant AstroManagerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.navigationShell.currentIndex;
    final current = widget.navigationShell.currentIndex;
    if (previous == current) return;
    _backSwipe = null;

    // Includes Settings opened through links in other sections.
    if (current == _settingsIndex) {
      _lastMainIndex = previous;
    }
  }

  void _navigateTo(int index) => widget.navigationShell.goBranch(
    index,
    initialLocation: index == widget.navigationShell.currentIndex,
  );

  void _backFromSectionRoot() {
    final index = widget.navigationShell.currentIndex;
    if (index == _dashboardIndex) return;
    _navigateTo(index == _settingsIndex ? _lastMainIndex : _dashboardIndex);
  }

  // Cupertino handles swipes on nested routes. Branch roots have no route
  // underneath them, so their section-level swipe is handled here.
  Widget _withRootEdgeSwipe(Widget child, double width) {
    final router = GoRouter.of(context);
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    return Listener(
      onPointerDown: (event) {
        if (_backSwipe != null) {
          _backSwipe = null;
          return;
        }
        final fromEdge = direction == 1
            ? event.localPosition.dx
            : width - event.localPosition.dx;
        if (event.kind == PointerDeviceKind.touch &&
            fromEdge <= 20 &&
            !router.canPop()) {
          _backSwipe = (
            pointer: event.pointer,
            start: event.position,
            direction: direction,
          );
        }
      },
      onPointerCancel: (event) {
        if (_backSwipe?.pointer == event.pointer) _backSwipe = null;
      },
      onPointerUp: (event) {
        final swipe = _backSwipe;
        if (swipe == null || swipe.pointer != event.pointer) return;
        _backSwipe = null;
        final distance = event.position - swipe.start;
        final inward = distance.dx * swipe.direction;
        if (inward >= 60 && inward > distance.dy.abs() && !router.canPop()) {
          _backFromSectionRoot();
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        final isExpanded = constraints.maxWidth >= _expandedBreakpoint;

        final selectedIndex = widget.navigationShell.currentIndex;

        final isSettings = selectedIndex == _settingsIndex;

        final scaffold = Scaffold(
          appBar: AppBar(
            title: AppText(_destinations[selectedIndex].label),
            leading: !isDesktop && isSettings
                ? IconButton(
                    tooltip: appTranslate(context, 'Back to previous section'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () =>
                        GoRouter.of(context).routerDelegate.popRoute(),
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
        final isDashboard = selectedIndex == _dashboardIndex;
        return PopScope<Object?>(
          canPop: isDashboard,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _backFromSectionRoot();
          },
          child:
              !isDashboard &&
                  !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.iOS
              ? _withRootEdgeSwipe(scaffold, constraints.maxWidth)
              : scaffold,
        );
      },
    );
  }
}
