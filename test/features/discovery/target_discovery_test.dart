import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/seven_night_weather_widget.dart';
import 'package:astromanager/features/discovery/application/discovery_evaluator.dart';
import 'package:astromanager/features/discovery/data/discovery_repositories.dart';
import 'package:astromanager/features/discovery/domain/discovery_results.dart';
import 'package:astromanager/features/discovery/presentation/target_discovery_panel.dart';
import 'package:astromanager/features/equipment/application/equipment_controller.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/light_pollution/application/light_pollution_providers.dart';
import 'package:astromanager/features/light_pollution/data/light_pollution_repository.dart';
import 'package:astromanager/features/light_pollution/domain/light_pollution.dart';
import 'package:astromanager/features/light_pollution/presentation/light_pollution_location_panel.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/application/celestial_catalog_controller.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/targets_screen.dart';
import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';
import 'package:astromanager/features/weather/data/mock_weather_provider.dart';

import '../../support/weather_fakes.dart';

const north = CelestialObject(
  id: 'polar',
  designation: 'Polar reference target',
  category: CelestialCategory.nebula,
  sourceType: 'Test',
  raDegrees: 80,
  decDegrees: 89,
  constellation: 'UMi',
  commonNames: 'Northern sky object',
  aliases: 'POLAR',
);
const galaxy = CelestialObject(
  id: 'other',
  designation: 'Other reference target',
  category: CelestialCategory.galaxy,
  sourceType: 'Test',
  raDegrees: 90,
  decDegrees: 85,
  constellation: 'UMi',
  commonNames: 'Small galaxy',
  aliases: '',
);
const siteA = ObservingLocation(
  id: 'a',
  name: 'Site A',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
const siteB = ObservingLocation(
  id: 'b',
  name: 'Site B',
  latitude: 48,
  longitude: 9,
  elevationMeters: 350,
  timeZone: 'Europe/Zurich',
  isDefault: false,
);
const camera = EquipmentItem(
  id: 'c',
  name: 'Test camera',
  kind: EquipmentKind.camera,
  sensorWidthMm: 36,
  sensorHeightMm: 24,
  resolutionX: 6000,
  resolutionY: 4000,
);
const optic = EquipmentItem(
  id: 'o',
  name: 'Test telescope',
  kind: EquipmentKind.telescope,
  focalLengthMm: 600,
  apertureMm: 120,
);
const profile = OpticalProfile(
  id: 'p',
  name: 'Test optical setup',
  cameraId: 'c',
  opticId: 'o',
  focalMultiplier: 1,
);

class FakeCandidates implements DiscoveryCandidateSource {
  final searches = <String>[];
  final categories = <CelestialCategory?>[];

  @override
  Future<List<CelestialObject>> load({
    required String query,
    required CelestialCategory? category,
    required Set<String> favoriteIds,
    required bool favoritesOnly,
    int limit = 24,
  }) async {
    searches.add(query);
    categories.add(category);
    return [north, galaxy]
        .where((item) => category == null || item.category == category)
        .where(
          (item) =>
              query.isEmpty ||
              item.displayTitle.toLowerCase().contains(query.toLowerCase()) ||
              item.commonNames.toLowerCase().contains(query.toLowerCase()),
        )
        .where((item) => !favoritesOnly || favoriteIds.contains(item.id))
        .take(limit)
        .toList();
  }
}

class FakeFavorites implements TargetFavoritesStore {
  Set<String> ids = {};
  @override
  Future<Set<String>> load() async => Set.of(ids);
  @override
  Future<void> save(Set<String> identifiers) async {
    ids = Set.of(identifiers);
  }
}

class FakeEvaluator implements DiscoveryEvaluator {
  final siteIds = <String>[];
  final dates = <DateTime>[];
  final opticalSelections = <bool>[];
  final forecasts = <WeatherForecastSnapshot?>[];

  @override
  Future<List<RankedDiscoveryTarget>> evaluate({
    required List<CelestialObject> targets,
    required ObservingLocation location,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    required int minimumDurationMinutes,
    required double minimumAltitudeDegrees,
    required WeatherForecastSnapshot? weather,
    LightPollutionSnapshot? nightLights,
    required OpticalMetrics? optics,
    required bool Function() isCurrent,
  }) async {
    siteIds.add(location.id);
    dates.add(localDate);
    opticalSelections.add(optics != null);
    forecasts.add(weather);
    final start = DateTime.utc(2026, 11, 1, 20);
    final end = start.add(Duration(minutes: minimumDurationMinutes));
    return rankDiscoveryTargets([
      for (final target in targets)
        RankedDiscoveryTarget(
          object: target,
          window: ObservationWindow(
            targetId: target.id,
            targetDesignation: target.displayTitle,
            startUtc: start,
            endUtc: end,
            bestAltitudeDegrees: 46,
            bestAltitudeAtUtc: start,
            weatherStatus: WindowWeatherStatus.missing,
            weatherTimeCoverage: 0,
            weatherParameterCoverage: 0,
            explanation: 'Weather not available for this test window.',
            score: TargetSuitabilityScore(
              targetId: target.id,
              startUtc: start,
              endUtc: end,
              score: optics == null ? 40 : 45,
              dataCoverage: 0.5,
              isProvisional: true,
              visibleDuration: end.difference(start),
              astronomicalDarkDuration: end.difference(start),
              usableDuration: end.difference(start),
              bestUsableAltitudeDegrees: 46,
              factors: const {},
              constraints: const [],
            ),
          ),
        ),
    ]);
  }
}

class MemoryNightLightCache implements LightPollutionCacheStore {
  final entries = <String, String>{};

  @override
  Future<String?> getString(String key) async => entries[key];

  @override
  Future<void> setString(String key, String value) async {
    entries[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    entries.remove(key);
  }
}

class TestNightLightProvider implements LightPollutionProvider {
  int calls = 0;

  @override
  String get id => 'test-viirs-v1';

  @override
  Future<LightPollutionReading?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    return LightPollutionReading(
      kind: NightLightKind.satelliteRadiance,
      value: 5,
      sourceId: id,
      sourceName: 'Test VIIRS satellite composite',
      datasetDate: DateTime.utc(2025, 12, 31),
      latitude: latitude,
      longitude: longitude,
      description: 'Test monthly radiance',
    );
  }
}

void main() {
  late FakeCandidates candidates;
  late FakeFavorites favorites;
  late FakeEvaluator evaluator;

  setUp(() {
    candidates = FakeCandidates();
    favorites = FakeFavorites();
    evaluator = FakeEvaluator();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    bool viaTargets = false,
    bool showDashboardForecast = false,
    WeatherProvider weatherProvider = const UnconfiguredWeatherProvider(),
    LightPollutionRepository? nightLightsRepository,
    DiscoveryEvaluator? rankingEvaluator,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          celestialCatalogProvider.overrideWithBuild(
            (ref, notifier) => CelestialCatalogViewState(
              totalObjects: 2,
              query: '',
              category: null,
              results: const [north, galaxy],
            ),
          ),
          observingLocationsProvider.overrideWithBuild(
            (ref, notifier) => [siteA, siteB],
          ),
          equipmentProvider.overrideWithBuild(
            (ref, notifier) =>
                EquipmentInventory(items: [camera, optic], profiles: [profile]),
          ),
          discoveryCandidateSourceProvider.overrideWithValue(candidates),
          targetFavoritesStoreProvider.overrideWithValue(favorites),
          discoveryEvaluatorProvider.overrideWithValue(
            rankingEvaluator ?? evaluator,
          ),
          if (nightLightsRepository != null)
            lightPollutionRepositoryProvider.overrideWithValue(
              nightLightsRepository,
            )
          else
            cachedNightLightsProvider.overrideWith((ref, location) => null),
          weatherProviderProvider.overrideWithValue(weatherProvider),
          weatherCacheRepositoryProvider.overrideWithValue(
            MemoryWeatherCache(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                if (nightLightsRepository != null)
                  const LightPollutionLocationPanel(site: siteA),
                if (showDashboardForecast)
                  const SizedBox(
                    height: 220,
                    child: SevenNightWeatherWidget(
                      location: siteA,
                      instance: DashboardWidgetInstance(
                        id: 'forecast',
                        typeId: 'seven-night-weather',
                      ),
                    ),
                  ),
                Expanded(
                  child: viaTargets
                      ? const TargetsScreen()
                      : const SingleChildScrollView(
                          child: TargetDiscoveryPanel(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (viaTargets) {
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-discovery')));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a Settings fetch fills the matching ranking factor from cache', (
    tester,
  ) async {
    final provider = TestNightLightProvider();
    var now = DateTime.now().toUtc();
    final checkedDate = now.toIso8601String().split('T').first;
    final repository = LightPollutionRepository(
      provider: provider,
      cache: MemoryNightLightCache(),
      now: () => now,
    );
    addTearDown(repository.dispose);
    await pumpPanel(
      tester,
      nightLightsRepository: repository,
      rankingEvaluator: const DefaultDiscoveryEvaluator(),
    );

    Future<void> expandFactors() async {
      final card = find.byKey(const ValueKey('recommendation-polar'));
      final factor = find.descendant(
        of: card,
        matching: find.textContaining('Local satellite night-light indicator:'),
      );
      if (factor.evaluate().isNotEmpty) return;
      final details = find.descendant(
        of: card,
        matching: find.textContaining('Why '),
      );
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
    }

    Future<void> chooseSite(String name) async {
      final selector = find.byKey(const ValueKey('discovery-location'));
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    final missing = find.text(
      'No satellite night-light reading available for this observing site.',
    );
    await expandFactors();
    expect(missing, findsOneWidget);
    expect(provider.calls, 0);

    await tester.tap(find.byKey(const ValueKey('night-lights-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('light-pollution-value')), findsOneWidget);
    await expandFactors();
    expect(
      find.text('Local satellite night-light indicator: 50/100'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Test VIIRS satellite composite · dataset 2025-12-31',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Retrieved $checkedDate UTC. Current cached reading'),
      findsOneWidget,
    );

    await chooseSite('Site B');
    await expandFactors();
    expect(missing, findsOneWidget);
    expect(find.textContaining('Current cached reading'), findsNothing);

    now = now.add(const Duration(days: 31));
    await chooseSite('Site A');
    await expandFactors();
    expect(find.textContaining('Stale reading · 0 points'), findsOneWidget);
    expect(find.textContaining('Retrieved $checkedDate UTC'), findsOneWidget);
    expect(missing, findsNothing);
    expect(provider.calls, 1);
  });

  testWidgets('Dashboard refresh recomputes a covered Targets recommendation', (
    tester,
  ) async {
    final fresh = DateTime.now().toUtc();
    final stale = fresh.subtract(const Duration(hours: 3));
    final provider = ControlledWeatherProvider(
      (request) async =>
          hourlyTestForecast(request, fetchedAt: stale, cloudCover: 90),
    );
    await pumpPanel(
      tester,
      showDashboardForecast: true,
      weatherProvider: provider,
    );
    expect(evaluator.forecasts.single!.forecast.fetchedAtUtc, stale);
    expect(find.textContaining('STALE weather cache'), findsOneWidget);
    final initialCalls = provider.calls;

    provider.respond = (request) async =>
        hourlyTestForecast(request, fetchedAt: fresh);
    final refresh = find.byTooltip('Refresh forecast');
    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(provider.calls, initialCalls + 1);
    expect(evaluator.forecasts, hasLength(2));
    final updated = evaluator.forecasts.last!;
    expect(updated.forecast.fetchedAtUtc, fresh);
    expect(updated.forecast.hours.first.totalCloudCoverPercent.value, 10);
    expect(find.textContaining('Forecast from network'), findsOneWidget);
    expect(find.textContaining('STALE weather cache'), findsNothing);

    provider.respond = (_) async => throw const WeatherException(
      type: WeatherErrorType.network,
      message: 'Offline',
    );
    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(provider.calls, initialCalls + 2);
    expect(evaluator.forecasts, hasLength(2));
    expect(evaluator.forecasts.last!.forecast.fetchedAtUtc, fresh);
    expect(find.textContaining('Forecast from network'), findsOneWidget);
    expect(
      find.text('Could not refresh. Showing the last forecast.'),
      findsOneWidget,
    );
  });

  test('equal scores produce stable ordering by target identifier', () async {
    final evaluated = await evaluator.evaluate(
      targets: [north, galaxy],
      location: siteA,
      localDate: DateTime(2026, 11, 1),
      evaluatedAtUtc: DateTime.utc(2026, 11, 1, 18),
      minimumDurationMinutes: 60,
      minimumAltitudeDegrees: 30,
      weather: null,
      optics: null,
      isCurrent: () => true,
    );
    expect(evaluated.map((value) => value.object.id).toList(), [
      'other',
      'polar',
    ]);
  });

  testWidgets('recommendations open from existing Targets screen', (
    tester,
  ) async {
    await pumpPanel(tester, viaTargets: true);
    expect(find.text('Recommended astrophotography targets'), findsOneWidget);
    expect(find.byKey(const ValueKey('recommendation-polar')), findsWidgets);
    expect(find.textContaining('Weather unavailable'), findsWidgets);
  });

  testWidgets('location, equipment and category trigger new evaluations', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(evaluator.siteIds.last, 'a');
    expect(evaluator.opticalSelections.last, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-location')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site B').last);
    await tester.pumpAndSettle();
    expect(evaluator.siteIds.last, 'b');

    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-equipment')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No setup selected').last);
    await tester.pumpAndSettle();
    expect(evaluator.opticalSelections.last, isFalse);

    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-category')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nebula').last);
    await tester.pumpAndSettle();
    expect(candidates.categories.last, CelestialCategory.nebula);
    expect(find.byKey(const ValueKey('recommendation-other')), findsNothing);
  });

  testWidgets('favorites persist and favorites-only filters results', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('favorite-polar')));
    await tester.tap(find.byKey(const ValueKey('favorite-polar')));
    await tester.pumpAndSettle();
    expect(favorites.ids, contains('polar'));

    await tester.ensureVisible(
      find.byKey(const ValueKey('discovery-favorites-only')),
    );
    await tester.tap(find.byKey(const ValueKey('discovery-favorites-only')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recommendation-polar')), findsOneWidget);
    expect(find.byKey(const ValueKey('recommendation-other')), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('score-details-polar')),
    );
    await tester.tap(find.byKey(const ValueKey('score-details-polar')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Weather not available for this test window'),
      findsWidgets,
    );
  });

  testWidgets('search and date trigger fresh discovery queries', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search')),
      'Northern',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(candidates.searches.last, 'Northern');
    expect(find.byKey(const ValueKey('recommendation-other')), findsNothing);
    // The date button opens the platform date picker.
    await tester.ensureVisible(find.byKey(const ValueKey('discovery-date')));
    await tester.tap(find.byKey(const ValueKey('discovery-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(evaluator.dates.length, greaterThan(1));
  });
}
