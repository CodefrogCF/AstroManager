import 'package:astromanager/app/router/app_router.dart';
import 'package:astromanager/features/dashboard/application/observing_site_conditions_provider.dart';
import 'package:astromanager/features/dashboard/domain/observing_site_conditions.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/observing_site_conditions_widget.dart';
import 'package:astromanager/features/light_pollution/data/light_pollution_repository.dart';
import 'package:astromanager/features/light_pollution/domain/light_pollution.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/terrain/domain/terrain_horizon.dart';
import 'package:astromanager/features/terrain/presentation/terrain_horizon_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _site = ObservingLocation(
  id: 's',
  name: 'Mountain Site',
  latitude: 47.4,
  longitude: 8.5,
  elevationMeters: 720,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

ObservingSiteConditions _fixture() => ObservingSiteConditions(
  site: _site,
  terrain: TerrainHorizonProfile(
    sourceId: 'opentopodata:fixture:eudem25m',
    createdAtUtc: DateTime.utc(2026, 11, 1),
    latitude: _site.latitude,
    longitude: _site.longitude,
    observerElevationMeters: _site.elevationMeters,
    options: const TerrainHorizonOptions(),
    bearings: [
      for (var i = 0; i < 36; i++)
        TerrainBearing(
          azimuthDegrees: i * 10.0,
          altitudeDegrees: i.isEven ? 4.0 : null,
        ),
    ],
  ),
  nightLights: LightPollutionSnapshot(
    reading: LightPollutionReading(
      kind: NightLightKind.satelliteRadiance,
      value: 2.25,
      sourceId: 'viirs-fixture',
      sourceName: 'EOG / NOAA via Esri',
      datasetDate: DateTime.utc(2025, 12, 31),
      latitude: _site.latitude,
      longitude: _site.longitude,
      description: 'Monthly raw radiance',
      sourceUrl: 'https://example.test/viirs',
      license: 'Source: EOG / NOAA / Esri',
    ),
    fromCache: true,
    isStale: false,
    checkedAtUtc: DateTime.utc(2026, 11, 2),
  ),
);

void main() {
  testWidgets('compact tile shows actual radiance units and stays scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingSiteConditionsProvider.overrideWith(
            (ref, site) async => _fixture(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 245,
                height: 190,
                child: ObservingSiteConditionsWidget(location: _site),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mountain Site'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-site-refresh-cache')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-site-light-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('nW/cm²/sr'), findsOneWidget);
    expect(find.textContaining('18/36'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-site-details')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('dashboard-site-details-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('dashboard-site-details-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-site-details')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded tile includes source, dataset date and limitations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingSiteConditionsProvider.overrideWith(
            (ref, site) async => _fixture(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 620,
              height: 640,
              child: ObservingSiteConditionsWidget(location: _site),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2025-12'), findsOneWidget);
    expect(find.textContaining('EOG / NOAA via Esri'), findsOneWidget);
    expect(find.textContaining('not measured sky brightness'), findsOneWidget);
    expect(find.byKey(const ValueKey('terrain-horizon-plot')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'site name and navigation remain visible if cache reading fails',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            observingSiteConditionsProvider.overrideWith(
              (ref, site) async => throw StateError('Cache unavailable'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: 220,
                child: ObservingSiteConditionsWidget(location: _site),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mountain Site'), findsOneWidget);
      expect(find.text('Europe/Zurich'), findsOneWidget);
      expect(
        find.text('Unable to read cached site conditions.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-site-compare')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('terrain compass labels fit narrow widths and enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 190,
              height: 340,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: TerrainHorizonChart(profile: _fixture().terrain!),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('terrain-horizon-plot')), findsOneWidget);
    final chartScroll = find.byKey(const ValueKey('terrain-horizon-scroll'));
    expect(chartScroll, findsOneWidget);
    final scrollable = find.descendant(
      of: chartScroll,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.ensureVisible(find.text('N · 360°'));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison action opens site comparison route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SizedBox(
              width: 500,
              height: 550,
              child: ObservingSiteConditionsWidget(location: _site),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.locations,
          builder: (_, state) => Scaffold(
            body: Text(state.uri.queryParameters['compare'] ?? 'locations'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingSiteConditionsProvider.overrideWith(
            (ref, site) async => _fixture(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('dashboard-site-compare')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-site-compare')));
    await tester.pumpAndSettle();
    expect(find.text('true'), findsOneWidget);
  });
}
