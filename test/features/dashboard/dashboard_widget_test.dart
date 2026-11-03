import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:astromanager/features/dashboard/application/top_targets_provider.dart';
import 'package:astromanager/features/dashboard/domain/top_targets.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_grid.dart';
import 'package:astromanager/features/dashboard/presentation/dashboard_screen.dart';
import 'package:astromanager/features/dashboard/presentation/dashboard_widget_registry.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/dashboard_widget_state.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/features/settings/domain/models/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_preferences_repository.dart';

const _sites = [
  ObservingLocation(
    id: 'a',
    name: 'North Ridge',
    latitude: 47.2,
    longitude: 8.6,
    elevationMeters: 620,
    timeZone: 'Europe/Zurich',
    isDefault: true,
  ),
  ObservingLocation(
    id: 'b',
    name: 'South Ridge',
    latitude: 46.9,
    longitude: 9.2,
    elevationMeters: 900,
    timeZone: 'Europe/Zurich',
    isDefault: false,
  ),
];

Future<void> _pumpDashboard(
  WidgetTester tester,
  MemoryDashboardLayoutRepository store, {
  DashboardWidgetRegistry? registry,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topTargetsProvider.overrideWith(
          (ref, query) async => TopTargetsResult(
            nightDate: DateTime.parse(query.nightDate),
            considered: 0,
            candidates: const [],
            ranked: const [],
          ),
        ),
        dashboardLayoutRepositoryProvider.overrideWithValue(store),
        appPreferencesRepositoryProvider.overrideWithValue(
          FakeAppPreferencesRepository()
            ..preferences = const AppPreferences(
              units: MeasurementUnits.metric,
              clockFormat: ClockFormat.system,
              language: LanguagePreference.system,
              onboardingCompleted: true,
            ),
        ),
        observingLocationsProvider.overrideWithBuild((ref, notifier) => _sites),
        if (registry != null)
          dashboardWidgetRegistryProvider.overrideWithValue(registry),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('registry validates unique types and compatible sizes', () {
    final defaultRegistry = DashboardWidgetRegistry([]);
    expect(defaultRegistry.entries, isEmpty);
    final def = DashboardWidgetDefinition(
      typeId: 'custom',
      title: 'Custom',
      description: 'Custom widget',
      icon: Icons.star,
      defaultSize: const DashboardWidgetSize(1, 1),
      supportedSizes: const [DashboardWidgetSize(1, 1)],
      builder: (_, ref, environment, instance) => const Text('Custom'),
    );
    expect(() => DashboardWidgetRegistry([def, def]), throwsArgumentError);
    expect(DashboardWidgetRegistry([def]).byType('custom'), same(def));
  });

  testWidgets('default dashboard shows its four widgets and can add a fifth', (
    tester,
  ) async {
    final store = MemoryDashboardLayoutRepository();
    await _pumpDashboard(tester, store);
    for (final name in [
      '7-Night Forecast',
      'Top 3 Targets Tonight',
      'Tonight at a Glance',
      'Quick Actions',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('dashboard-tonight')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-manage')));
    await tester.pumpAndSettle();
    // Additional registered widgets can push this option outside the lazily
    // built portion of the dialog's ListView. Scroll inside the dialog before
    // interacting with the entry instead of assuming it is already built.
    final siteOption = find.byKey(
      const ValueKey('dashboard-add-observing-site'),
    );
    final dialogList = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    expect(dialogList, findsOneWidget);
    await tester.scrollUntilVisible(siteOption, 180, scrollable: dialogList);
    await tester.tap(siteOption);
    await tester.pumpAndSettle();
    expect(store.layout.widgets.length, 5);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    expect(find.text('Observing Site'), findsOneWidget);
  });

  testWidgets('selected dashboard location persists and is shared', (
    tester,
  ) async {
    final store = MemoryDashboardLayoutRepository(
      const DashboardLayout(
        widgets: [
          DashboardWidgetInstance(id: 'site', typeId: 'observing-site'),
        ],
      ),
    );
    await _pumpDashboard(tester, store);
    expect(find.text('North Ridge'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('dashboard-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('South Ridge').last);
    await tester.pumpAndSettle();
    expect(store.layout.selectedLocationId, 'b');
    expect(find.text('South Ridge'), findsWidgets);
  });

  testWidgets('hidden widget is not constructed or loaded', (tester) async {
    var builds = 0;
    final registry = DashboardWidgetRegistry([
      DashboardWidgetDefinition(
        typeId: 'spy',
        title: 'Spy',
        description: 'Tracks builds',
        icon: Icons.visibility,
        defaultSize: const DashboardWidgetSize(1, 1),
        supportedSizes: const [DashboardWidgetSize(1, 1)],
        builder: (_, ref, env, instance) {
          builds++;
          return const Text('Visible spy');
        },
      ),
    ]);
    final store = MemoryDashboardLayoutRepository(
      const DashboardLayout(
        widgets: [
          DashboardWidgetInstance(id: 'spy-1', typeId: 'spy', visible: false),
        ],
      ),
    );
    await _pumpDashboard(tester, store, registry: registry);
    expect(builds, 0);
    await tester.tap(find.byKey(const ValueKey('dashboard-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-toggle-spy-1')));
    await tester.pumpAndSettle();
    expect(store.layout.widgets.single.visible, true);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    expect(find.text('Visible spy'), findsOneWidget);
    expect(builds, greaterThan(0));
  });

  testWidgets(
    'data-state renderer differentiates empty, error and unavailable',
    (tester) async {
      Future<void> pump(DashboardLoadState<Object> state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardWidgetStateView<Object>(
              state: state,
              dataBuilder: (_, value) => Text('$value'),
            ),
          ),
        ),
      );
      await pump(const DashboardLoadState.empty('No data available.'));
      expect(find.text('No data available.'), findsOneWidget);
      await pump(const DashboardLoadState.error('Unable to load widget data.'));
      expect(find.text('Unable to load widget data.'), findsOneWidget);
      await pump(
        const DashboardLoadState.unavailable('Data unavailable offline.'),
      );
      expect(find.text('Data unavailable offline.'), findsOneWidget);
      await pump(const DashboardLoadState.data('Ready'));
      expect(find.text('Ready'), findsOneWidget);
    },
  );

  testWidgets(
    'edit mode offers touch handle and accessible move and resize controls',
    (tester) async {
      final store = MemoryDashboardLayoutRepository();
      await _pumpDashboard(tester, store);
      expect(
        find.byKey(const ValueKey('dashboard-drag-tonight-default')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-edit-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dashboard-drag-tonight-default')),
        findsOneWidget,
      );

      final down = find.byKey(
        const ValueKey('dashboard-move-down-tonight-default'),
      );
      await tester.ensureVisible(down);
      await tester.tap(down);
      await tester.pumpAndSettle();
      final tiles = store.layout.grids[DashboardViewport.tablet]!;
      expect(
        tiles.singleWhere((tile) => tile.widgetId == 'tonight-default').row,
        greaterThanOrEqualTo(3),
      );

      final sizeButton = find.byKey(
        const ValueKey('dashboard-size-tonight-default'),
      );
      // The move can push the resize control below the test viewport. Scroll
      // and flush the layout before sending a pointer event to that control.
      await tester.ensureVisible(sizeButton);
      await tester.pumpAndSettle();
      expect(sizeButton.hitTestable(), findsOneWidget);
      await tester.tap(sizeButton.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('1 × 2'), findsOneWidget);
      await tester.tap(find.text('1 × 2'));
      await tester.pumpAndSettle();
      expect(
        store.layout.grids[DashboardViewport.tablet]!
            .singleWhere((tile) => tile.widgetId == 'tonight-default')
            .rows,
        2,
      );
    },
  );

  testWidgets(
    'resetting current layout does not remove widgets or preferences',
    (tester) async {
      final store = MemoryDashboardLayoutRepository();
      await _pumpDashboard(tester, store);
      await tester.tap(find.byKey(const ValueKey('dashboard-edit-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dashboard-move-down-tonight-default')),
      );
      await tester.pumpAndSettle();
      expect(store.layout.grids.containsKey(DashboardViewport.tablet), isTrue);
      await tester.ensureVisible(
        find.byKey(const ValueKey('dashboard-reset-layout')),
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-reset-layout')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dashboard-confirm-reset-layout')),
      );
      await tester.pumpAndSettle();
      expect(store.layout.grids.containsKey(DashboardViewport.tablet), isFalse);
      expect(store.layout.widgets.length, 4);
    },
  );

  testWidgets('tablet layout does not replace the phone layout', (
    tester,
  ) async {
    final store = MemoryDashboardLayoutRepository();
    await _pumpDashboard(tester, store);
    await tester.tap(find.byKey(const ValueKey('dashboard-edit-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('dashboard-move-down-tonight-default')),
    );
    await tester.pumpAndSettle();
    expect(store.layout.grids.containsKey(DashboardViewport.tablet), isTrue);

    tester.view.physicalSize = const Size(390, 1200);
    await tester.pumpAndSettle();
    final visibleTile = find.byKey(
      const ValueKey('dashboard-widget-tonight-default'),
    );
    expect(visibleTile, findsOneWidget);
    expect(tester.getSize(visibleTile).width, greaterThan(300));
    expect(store.layout.grids.containsKey(DashboardViewport.phone), isFalse);
    expect(store.layout.grids.containsKey(DashboardViewport.tablet), isTrue);
  });
}
