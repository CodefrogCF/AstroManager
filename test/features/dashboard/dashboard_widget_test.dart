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
import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
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
  Size surface = const Size(900, 1200),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
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
        weatherForecastSnapshotProvider.overrideWith((ref, request) async {
          final now = DateTime.now().toUtc();
          return WeatherForecastSnapshot(
            forecast: WeatherForecast(
              provider: const WeatherProviderMetadata(
                id: 'stub',
                name: 'Test Weather',
                attribution: 'Test forecast attribution',
              ),
              latitudeDegrees: request.latitudeDegrees,
              longitudeDegrees: request.longitudeDegrees,
              issuedAtUtc: now,
              fetchedAtUtc: now,
              hours: List.generate(
                170,
                (index) => HourlyWeatherForecast(
                  timeUtc: request.startUtc.add(Duration(hours: index)),
                  totalCloudCoverPercent: const WeatherValue.available(15),
                ),
              ),
            ),
            origin: WeatherForecastOrigin.network,
            checkedAtUtc: now,
            isStale: false,
          );
        }),
        if (registry != null)
          dashboardWidgetRegistryProvider.overrideWithValue(registry),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'an intermediate height fits the forecast and survives reopening',
    (tester) async {
      final store = MemoryDashboardLayoutRepository();
      const surface = Size(390, 900);
      await _pumpDashboard(tester, store, surface: surface);
      final weather = find.byKey(
        const ValueKey('dashboard-widget-weather-default'),
      );
      final next = find.byKey(
        const ValueKey('dashboard-widget-targets-default'),
      );
      final scrollable = find
          .descendant(of: weather, matching: find.byType(Scrollable))
          .first;
      double overflow() =>
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent;
      final originalHeight = tester.getSize(weather).height;
      expect(overflow(), greaterThan(0));

      final edit = find.byKey(const ValueKey('dashboard-edit-toggle'));
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dashboard-size-weather-default')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-widget-height')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();

      final resizedHeight = tester.getSize(weather).height;
      expect(
        resizedHeight,
        inExclusiveRange(originalHeight, 2 * originalHeight),
      );
      expect(overflow(), 0);
      expect(tester.getTopLeft(next).dy - tester.getBottomLeft(weather).dy, 12);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpDashboard(tester, store, surface: surface);
      expect(tester.getSize(weather).height, resizedHeight);
      expect(tester.getTopLeft(next).dy - tester.getBottomLeft(weather).dy, 12);

      await tester.tap(
        find.byKey(const ValueKey('dashboard-actions-weather-default')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-configure-save')));
      await tester.pumpAndSettle();
      expect(tester.getSize(weather).height, resizedHeight);
    },
  );

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
    // scrollUntilVisible stops when the item is built, even if its center is
    // still clipped by the dialog viewport. Center it before hit testing.
    await Scrollable.ensureVisible(
      tester.element(siteOption),
      alignment: 0.5,
      duration: const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(dialogList).contains(tester.getCenter(siteOption)),
      isTrue,
    );
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
      await tester.tap(find.byKey(const ValueKey('dashboard-widget-width')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-widget-height')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.75').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final resized = store.layout.grids[DashboardViewport.tablet]!.singleWhere(
        (tile) => tile.widgetId == 'tonight-default',
      );
      expect(resized.columns, 1.5);
      expect(resized.rows, 1.75);
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
