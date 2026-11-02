import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/light_pollution/data/light_pollution_repository.dart';
import 'package:astromanager/features/light_pollution/domain/light_pollution.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/site_comparison/domain/observing_site_comparison.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/terrain/domain/terrain_horizon.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';

const zurich = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
const bern = ObservingLocation(
  id: 'bern',
  name: 'Bern',
  latitude: 46.948,
  longitude: 7.4474,
  elevationMeters: 550,
  timeZone: 'Europe/Zurich',
  isDefault: false,
);
const london = ObservingLocation(
  id: 'london',
  name: 'London',
  latitude: 51.507,
  longitude: -0.128,
  elevationMeters: 20,
  timeZone: 'Europe/London',
  isDefault: false,
);

const poleTarget = CelestialObject(
  id: 'north-pole',
  designation: 'Synthetic polar target',
  category: CelestialCategory.nebula,
  sourceType: 'Test',
  raDegrees: 80,
  decDegrees: 85,
  constellation: 'UMi',
  commonNames: '',
  aliases: '',
);

final asOf = DateTime.utc(2026, 11, 2, 13);
final localDate = DateTime.utc(2026, 11, 2);

WeatherForecastSnapshot weather(ObservingLocation site, double cloud) {
  final hours = <HourlyWeatherForecast>[];
  for (
    var hour = DateTime.utc(2026, 11, 2, 0);
    hour.isBefore(DateTime.utc(2026, 11, 4, 0));
    hour = hour.add(const Duration(hours: 1))
  ) {
    hours.add(
      HourlyWeatherForecast(
        timeUtc: hour,
        totalCloudCoverPercent: WeatherValue.available(cloud),
        lowCloudCoverPercent: WeatherValue.available(cloud),
        midCloudCoverPercent: WeatherValue.available(cloud),
        highCloudCoverPercent: WeatherValue.available(cloud),
        precipitationMillimeters: const WeatherValue.available(0),
        precipitationProbabilityPercent: const WeatherValue.available(0),
        windSpeedMetersPerSecond: const WeatherValue.available(2),
        windGustMetersPerSecond: const WeatherValue.available(3),
        relativeHumidityPercent: const WeatherValue.available(40),
        visibilityMeters: const WeatherValue.available(30000),
      ),
    );
  }
  return WeatherForecastSnapshot(
    forecast: WeatherForecast(
      provider: const WeatherProviderMetadata(
        id: 'mock',
        name: 'Test forecast',
      ),
      latitudeDegrees: site.latitude,
      longitudeDegrees: site.longitude,
      issuedAtUtc: DateTime.utc(2026, 11, 2, 12),
      fetchedAtUtc: DateTime.utc(2026, 11, 2, 12, 30),
      hours: hours,
    ),
    origin: WeatherForecastOrigin.network,
    checkedAtUtc: asOf,
    isStale: false,
  );
}

TerrainHorizonProfile terrain(ObservingLocation site, double altitude) {
  const options = TerrainHorizonOptions(
    azimuthStepDegrees: 30,
    maximumDistanceMeters: 3000,
    distanceStepMeters: 1000,
  );
  return TerrainHorizonProfile(
    sourceId: 'synthetic',
    createdAtUtc: asOf,
    latitude: site.latitude,
    longitude: site.longitude,
    observerElevationMeters: site.elevationMeters,
    options: options,
    bearings: [
      for (var degree = 0; degree < 360; degree += 30)
        TerrainBearing(
          azimuthDegrees: degree.toDouble(),
          altitudeDegrees: altitude,
        ),
    ],
  );
}

LightPollutionSnapshot lights(ObservingLocation site, double radiance) =>
    LightPollutionSnapshot(
      reading: LightPollutionReading(
        kind: NightLightKind.satelliteRadiance,
        value: radiance,
        sourceId: 'test-viirs',
        sourceName: 'Test VIIRS',
        datasetDate: DateTime.utc(2025, 12, 1),
        latitude: site.latitude,
        longitude: site.longitude,
        description: 'Test only',
      ),
      fromCache: false,
      isStale: false,
    );

SiteComparisonReport compare(
  List<SiteComparisonInput> inputs, {
  SiteComparisonOptions options = const SiteComparisonOptions(),
  DateTime? date,
}) => ObservingSiteComparison.compare(
  target: poleTarget,
  localDate: date ?? localDate,
  evaluatedAtUtc: asOf,
  sites: inputs,
  options: options,
);

void main() {
  test('requires at least two distinct sites', () {
    expect(
      () => compare([const SiteComparisonInput(site: zurich)]),
      throwsArgumentError,
    );
    expect(
      () => compare([
        const SiteComparisonInput(site: zurich),
        const SiteComparisonInput(site: zurich),
      ]),
      throwsArgumentError,
    );
  });

  test('same target and local calendar day, with site-specific UTC nights', () {
    final report = compare(
      [
        const SiteComparisonInput(site: zurich),
        const SiteComparisonInput(site: london),
      ],
      options: const SiteComparisonOptions(
        compareTerrain: false,
        compareLightPollution: false,
      ),
    );
    expect(report.target.id, poleTarget.id);
    expect(report.localDate, localDate);
    final starts = report.rankedSites.map((item) => item.nightStartUtc).toSet();
    expect(starts.length, 2); // Local noon differs by one hour.
    expect(
      report.rankedSites.every(
        (item) => item.astronomicalDarkness > Duration.zero,
      ),
      isTrue,
    );
  });

  test('clear forecast improves the score; wrong-site forecast is missing', () {
    final report = compare(
      [
        SiteComparisonInput(site: zurich, weather: weather(zurich, 0)),
        SiteComparisonInput(site: bern, weather: weather(bern, 100)),
      ],
      options: const SiteComparisonOptions(
        compareTerrain: false,
        compareLightPollution: false,
      ),
    );
    expect(report.leader.site.id, 'zurich');
    expect(
      report.rankedSites.first.score,
      greaterThan(report.rankedSites.last.score),
    );
    final mismatch = compare(
      [
        SiteComparisonInput(site: zurich, weather: weather(bern, 0)),
        SiteComparisonInput(site: bern, weather: weather(bern, 100)),
      ],
      options: const SiteComparisonOptions(
        compareTerrain: false,
        compareLightPollution: false,
      ),
    );
    final zurichResult = mismatch.rankedSites.firstWhere(
      (r) => r.site.id == 'zurich',
    );
    expect(zurichResult.missingData.join(' '), contains('Weather unavailable'));
  });

  test('missing data is visible and never scored as clear weather', () {
    final report = compare([
      const SiteComparisonInput(site: zurich),
      const SiteComparisonInput(site: bern),
    ]);
    for (final item in report.rankedSites) {
      expect(item.isProvisional, isTrue);
      expect(item.missingData.join(' '), contains('Weather unavailable'));
      expect(
        item.missingData.join(' '),
        contains('Terrain horizon unavailable'),
      );
      expect(item.missingData.join(' '), contains('satellite night-light'));
      expect(item.score, lessThanOrEqualTo(50));
      expect(item.score, inInclusiveRange(0.0, 100.0));
    }
  });

  test(
    'terrain obstruction reduces dark target visibility and final score',
    () {
      final report = compare([
        SiteComparisonInput(
          site: zurich,
          weather: weather(zurich, 0),
          terrain: terrain(zurich, 85),
        ),
        SiteComparisonInput(
          site: bern,
          weather: weather(bern, 0),
          terrain: terrain(bern, -10),
        ),
      ], options: const SiteComparisonOptions(compareLightPollution: false));
      final obstructed = report.rankedSites.firstWhere(
        (r) => r.site.id == 'zurich',
      );
      final clear = report.rankedSites.firstWhere((r) => r.site.id == 'bern');
      expect(obstructed.geometricVisibleDuration, greaterThan(Duration.zero));
      expect(obstructed.visibleDuration, Duration.zero);
      expect(obstructed.terrainReductionFraction, 1);
      expect(obstructed.score, 0);
      expect(clear.visibleDuration, greaterThan(Duration.zero));
      expect(clear.score, greaterThan(obstructed.score));
    },
  );

  test(
    'lower VIIRS radiance is a preferred relative indicator, not Bortle',
    () {
      final report = compare([
        SiteComparisonInput(
          site: zurich,
          weather: weather(zurich, 0),
          lightPollution: lights(zurich, 0.2),
        ),
        SiteComparisonInput(
          site: bern,
          weather: weather(bern, 0),
          lightPollution: lights(bern, 35),
        ),
      ], options: const SiteComparisonOptions(compareTerrain: false));
      final a = report.rankedSites.firstWhere((r) => r.site.id == 'zurich');
      final b = report.rankedSites.firstWhere((r) => r.site.id == 'bern');
      expect(a.explanations.join(' '), contains('not Bortle/SQM'));
      expect(b.explanations.join(' '), contains('nW/cm²/sr'));
      expect(a.score, greaterThan(b.score));
    },
  );

  test('different radiance composite months cannot be scored together', () {
    final incompatible = LightPollutionSnapshot(
      reading: LightPollutionReading(
        kind: NightLightKind.satelliteRadiance,
        value: 0.1,
        sourceId: 'test-viirs',
        sourceName: 'Test VIIRS',
        datasetDate: DateTime.utc(2026, 1, 1),
        latitude: bern.latitude,
        longitude: bern.longitude,
        description: 'Test only',
      ),
      fromCache: false,
      isStale: false,
    );
    final result = compare([
      SiteComparisonInput(site: zurich, lightPollution: lights(zurich, 2)),
      SiteComparisonInput(site: bern, lightPollution: incompatible),
    ], options: const SiteComparisonOptions(compareTerrain: false));
    expect(
      result.rankedSites.every(
        (site) => site.missingData.join(' ').contains('datasets differ'),
      ),
      isTrue,
    );
  });

  test('spring DST observing nights are evaluated in UTC, not assumed 24h', () {
    final report = compare(
      [
        const SiteComparisonInput(site: zurich),
        const SiteComparisonInput(site: london),
      ],
      date: DateTime.utc(2026, 3, 28),
      options: const SiteComparisonOptions(
        compareTerrain: false,
        compareLightPollution: false,
      ),
    );
    // The observing night noon March 28 to noon March 29 crosses DST.
    expect(
      report.rankedSites.every(
        (r) =>
            r.nightEndUtc.difference(r.nightStartUtc) ==
            const Duration(hours: 23),
      ),
      isTrue,
    );
  });
}
