import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
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
    expect(find.textContaining('not yet available'), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('dashboard-manage')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('dashboard-add-observing-site')),
    );
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
}
