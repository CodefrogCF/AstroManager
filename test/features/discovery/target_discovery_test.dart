import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/discovery/application/discovery_evaluator.dart';
import 'package:astromanager/features/discovery/data/discovery_repositories.dart';
import 'package:astromanager/features/discovery/domain/discovery_results.dart';
import 'package:astromanager/features/discovery/presentation/target_discovery_panel.dart';
import 'package:astromanager/features/equipment/application/equipment_controller.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/application/celestial_catalog_controller.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/targets_screen.dart';
import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/repositories/weather_cache_repository.dart';
import 'package:astromanager/features/weather/data/mock_weather_provider.dart';

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

  @override
  Future<List<RankedDiscoveryTarget>> evaluate({
    required List<CelestialObject> targets,
    required ObservingLocation location,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    required int minimumDurationMinutes,
    required double minimumAltitudeDegrees,
    required WeatherForecastSnapshot? weather,
    required OpticalMetrics? optics,
    required bool Function() isCurrent,
  }) async {
    siteIds.add(location.id);
    dates.add(localDate);
    opticalSelections.add(optics != null);
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

class EmptyWeatherCache implements WeatherCacheRepository {
  @override
  Future<WeatherForecast?> read(WeatherCacheKey key) async => null;
  @override
  Future<void> write(WeatherCacheKey key, WeatherForecast data) async {}
  @override
  Future<void> remove(WeatherCacheKey key) async {}
  @override
  Future<void> clear() async {}
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

  Future<void> pumpPanel(WidgetTester tester, {bool viaTargets = false}) async {
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
          discoveryEvaluatorProvider.overrideWithValue(evaluator),
          weatherProviderProvider.overrideWithValue(
            const UnconfiguredWeatherProvider(),
          ),
          weatherCacheRepositoryProvider.overrideWithValue(EmptyWeatherCache()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: viaTargets
                ? const TargetsScreen()
                : const SingleChildScrollView(child: TargetDiscoveryPanel()),
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
