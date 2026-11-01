import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/intelligence/domain/services/observation_window_recommendation.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';

const site = ObserverPosition(latitudeDegrees: 47.48, longitudeDegrees: 8.21);
const location = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

const polarTarget = CelestialObject(
  id: 'polar',
  designation: 'Polar test object',
  category: CelestialCategory.nebula,
  sourceType: 'Test',
  raDegrees: 80,
  decDegrees: 89.5,
  constellation: 'UMi',
  commonNames: '',
  aliases: '',
  majorAxisArcmin: 30,
  minorAxisArcmin: 20,
);
const secondTarget = CelestialObject(
  id: 'polar-2',
  designation: 'Second polar target',
  category: CelestialCategory.galaxy,
  sourceType: 'Test',
  raDegrees: 120,
  decDegrees: 85,
  constellation: 'UMi',
  commonNames: '',
  aliases: '',
  majorAxisArcmin: 30,
  minorAxisArcmin: 20,
);
const neverRises = CelestialObject(
  id: 'south',
  designation: 'Southern target',
  category: CelestialCategory.galaxy,
  sourceType: 'Test',
  raDegrees: 120,
  decDegrees: -80,
  constellation: 'Oct',
  commonNames: '',
  aliases: '',
);
const optics = OpticalMetrics(
  effectiveFocalLengthMm: 800,
  effectiveFocalRatio: 5,
  horizontalFovDegrees: 1,
  verticalFovDegrees: 1,
  pixelScaleXArcsec: 1.5,
  pixelScaleYArcsec: 1.5,
);

final utcStart = DateTime.utc(2026, 11, 1, 19);
final utcEnd = DateTime.utc(2026, 11, 2, 2);
final now = DateTime.utc(2026, 11, 1, 18, 30);

HourlyWeatherForecast hour(
  DateTime time, {
  double? cloud = 5,
  bool sparse = false,
}) {
  return HourlyWeatherForecast(
    timeUtc: time,
    totalCloudCoverPercent: cloud == null
        ? const WeatherValue<double>.missing()
        : WeatherValue<double>.available(cloud),
    lowCloudCoverPercent: sparse
        ? const WeatherValue<double>.unavailable()
        : const WeatherValue<double>.available(0),
    midCloudCoverPercent: const WeatherValue<double>.available(0),
    highCloudCoverPercent: const WeatherValue<double>.available(0),
    precipitationMillimeters: const WeatherValue<double>.available(0),
    precipitationProbabilityPercent: const WeatherValue<double>.available(0),
    windSpeedMetersPerSecond: const WeatherValue<double>.available(2),
    windGustMetersPerSecond: const WeatherValue<double>.available(3),
    relativeHumidityPercent: const WeatherValue<double>.available(40),
    visibilityMeters: const WeatherValue<double>.available(30000),
  );
}

WeatherForecastSnapshot weatherSnapshot({
  List<HourlyWeatherForecast>? hours,
  bool stale = false,
}) {
  final data =
      hours ??
      [
        for (
          var utc = DateTime.utc(2026, 11, 1, 18);
          utc.isBefore(DateTime.utc(2026, 11, 2, 7));
          utc = utc.add(const Duration(hours: 1))
        )
          hour(utc),
      ];
  return WeatherForecastSnapshot(
    forecast: WeatherForecast(
      provider: const WeatherProviderMetadata(id: 'mock', name: 'Mock'),
      latitudeDegrees: site.latitudeDegrees,
      longitudeDegrees: site.longitudeDegrees,
      issuedAtUtc: DateTime.utc(2026, 11, 1, 18),
      fetchedAtUtc: DateTime.utc(2026, 11, 1, 18, 10),
      hours: data,
    ),
    origin: stale
        ? WeatherForecastOrigin.staleFallback
        : WeatherForecastOrigin.network,
    checkedAtUtc: now,
    isStale: stale,
  );
}

ObservationWindowRecommendations recommend({
  List<CelestialObject> targets = const [polarTarget],
  DateTime? start,
  DateTime? end,
  WeatherForecastSnapshot? weather,
  ObservationWindowOptions options = const ObservationWindowOptions(),
  SuitabilityScoringProfile scoringProfile = const SuitabilityScoringProfile(),
}) => ObservationWindowRecommendation.forUtcPeriod(
  targets: targets,
  observer: site,
  startUtc: start ?? utcStart,
  endUtc: end ?? utcEnd,
  evaluatedAtUtc: now,
  weather: weather,
  optics: optics,
  options: options,
  scoringProfile: scoringProfile,
);

void main() {
  group('Observation window eligibility', () {
    test('all recommendations are dark, visible and meet minimum duration', () {
      const options = ObservationWindowOptions(
        minimumSessionDuration: Duration(hours: 1),
        maximumSessionDuration: Duration(hours: 3),
      );
      final result = recommend(weather: weatherSnapshot(), options: options);
      expect(result.rankedWindows, isNotEmpty);
      for (final window in result.rankedWindows) {
        expect(window.startUtc.isUtc, isTrue);
        expect(window.endUtc.isUtc, isTrue);
        expect(
          window.duration,
          greaterThanOrEqualTo(options.minimumSessionDuration),
        );
        expect(window.score.usableDuration, greaterThan(Duration.zero));
        expect(
          window.score.constraints.where(
            (c) => c.contains('No astronomical darkness'),
          ),
          isEmpty,
        );
        expect(
          window.score.factors.keys.toSet(),
          SuitabilityFactor.values.toSet(),
        );
        expect(window.bestAltitudeAtUtc, isNotNull);
        expect(window.bestAltitudeAtUtc!.isBefore(window.startUtc), isFalse);
        expect(window.bestAltitudeAtUtc!.isAfter(window.endUtc), isFalse);
        expect(window.bestAltitudeDegrees!, greaterThan(30));
        expect(
          result.astronomicalDarkness.any(
            (dark) =>
                !window.startUtc.isBefore(dark.startUtc) &&
                !window.endUtc.isAfter(dark.endUtc),
          ),
          isTrue,
        );
      }
    });

    test('custom minimum session length is enforced', () {
      final result = recommend(
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 3),
          maximumSessionDuration: Duration(hours: 3),
        ),
      );
      expect(result.rankedWindows, isNotEmpty);
      expect(
        result.rankedWindows.every(
          (w) => w.duration == const Duration(hours: 3),
        ),
        isTrue,
      );
    });

    test('daylight period produces no recommendation', () {
      final result = recommend(
        start: DateTime.utc(2026, 11, 1, 11),
        end: DateTime.utc(2026, 11, 1, 13),
      );
      expect(result.astronomicalDarkness, isEmpty);
      expect(result.rankedWindows, isEmpty);
      expect(result.excludedTargets['polar'], contains('darkness'));
    });

    test('never rising and too short periods are explained', () {
      final never = recommend(targets: const [neverRises]);
      expect(never.rankedWindows, isEmpty);
      expect(never.excludedTargets['south'], contains('minimum altitude'));

      final short = recommend(
        start: DateTime.utc(2026, 11, 1, 20),
        end: DateTime.utc(2026, 11, 1, 20, 20),
      );
      expect(short.rankedWindows, isEmpty);
      expect(
        short.excludedTargets['polar'],
        contains('minimum session duration'),
      );
    });

    test('local spring DST night is 23 elapsed hours', () {
      final result = ObservationWindowRecommendation.forObservingNight(
        targets: const [polarTarget],
        location: location,
        localDate: DateTime.utc(2026, 3, 28),
        evaluatedAtUtc: DateTime.utc(2026, 3, 28, 11),
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 1),
          maximumSessionDuration: Duration(hours: 2),
          candidateStep: Duration(hours: 1),
        ),
      );
      expect(
        result.periodEndUtc.difference(result.periodStartUtc),
        const Duration(hours: 23),
      );
      expect(result.rankedWindows, isNotEmpty);
    });

    test('absolute UTC windows can span midnight', () {
      final result = recommend(
        start: DateTime.utc(2026, 11, 1, 23, 30),
        end: DateTime.utc(2026, 11, 2, 1, 30),
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 2),
          maximumSessionDuration: Duration(hours: 2),
        ),
      );
      expect(result.rankedWindows, hasLength(1));
      expect(result.rankedWindows.first.startUtc.day, 1);
      expect(result.rankedWindows.first.endUtc.day, 2);
    });

    test('local night around autumn DST is 25 elapsed hours', () {
      final result = ObservationWindowRecommendation.forObservingNight(
        targets: const [polarTarget],
        location: location,
        localDate: DateTime.utc(2026, 10, 24),
        evaluatedAtUtc: DateTime.utc(2026, 10, 24, 10),
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 1),
          maximumSessionDuration: Duration(hours: 2),
          candidateStep: Duration(hours: 1),
        ),
      );
      expect(
        result.periodEndUtc.difference(result.periodStartUtc),
        const Duration(hours: 25),
      );
      expect(result.rankedWindows, isNotEmpty);
      expect(
        result.rankedWindows.every((w) => w.startUtc.isUtc && w.endUtc.isUtc),
        isTrue,
      );
    });
  });

  group('Ranking and weather coverage', () {
    test(
      'identical inputs and shuffled target lists produce identical ranking',
      () {
        final weather = weatherSnapshot();
        final first = recommend(
          targets: const [polarTarget, secondTarget],
          weather: weather,
        );
        final second = recommend(
          targets: const [secondTarget, polarTarget],
          weather: weather,
        );
        final a = first.rankedWindows
            .map((w) => (w.targetId, w.startUtc, w.endUtc, w.score.score))
            .toList();
        final b = second.rankedWindows
            .map((w) => (w.targetId, w.startUtc, w.endUtc, w.score.score))
            .toList();
        expect(a, b);
        for (var i = 1; i < first.rankedWindows.length; i++) {
          expect(
            first.rankedWindows[i - 1].score.score,
            greaterThanOrEqualTo(first.rankedWindows[i].score.score),
          );
        }
      },
    );

    test('missing forecast never becomes clear sky', () {
      final result = recommend();
      expect(result.rankedWindows, isNotEmpty);
      final best = result.rankedWindows.first;
      expect(best.weatherStatus, WindowWeatherStatus.missing);
      expect(best.weatherTimeCoverage, 0);
      expect(best.isProvisional, isTrue);
      expect(best.score.score, lessThanOrEqualTo(50));
      expect(best.explanation, contains('No weather forecast'));
    });

    test('stale forecast remains explicitly stale', () {
      final result = recommend(weather: weatherSnapshot(stale: true));
      expect(result.rankedWindows, isNotEmpty);
      expect(
        result.rankedWindows.first.weatherStatus,
        WindowWeatherStatus.stale,
      );
      expect(result.rankedWindows.first.isProvisional, isTrue);
      expect(result.rankedWindows.first.score.score, lessThanOrEqualTo(50));
    });

    test('a missing hourly forecast causes partial time coverage', () {
      final result = recommend(
        start: DateTime.utc(2026, 11, 1, 19),
        end: DateTime.utc(2026, 11, 1, 21),
        weather: weatherSnapshot(hours: [hour(DateTime.utc(2026, 11, 1, 19))]),
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 2),
          maximumSessionDuration: Duration(hours: 2),
        ),
      );
      expect(result.rankedWindows, hasLength(1));
      final window = result.rankedWindows.single;
      expect(window.weatherStatus, WindowWeatherStatus.partial);
      expect(window.weatherTimeCoverage, closeTo(0.5, 1e-8));
      expect(window.weatherParameterCoverage, closeTo(0.5, 1e-8));
      expect(window.isProvisional, isTrue);
    });

    test(
      'an explicitly unavailable cloud layer reduces parameter coverage',
      () {
        final result = recommend(
          weather: weatherSnapshot(
            hours: [
              for (
                var utc = DateTime.utc(2026, 11, 1, 18);
                utc.isBefore(DateTime.utc(2026, 11, 2, 7));
                utc = utc.add(const Duration(hours: 1))
              )
                hour(utc, sparse: true),
            ],
          ),
        );
        expect(
          result.rankedWindows.first.weatherStatus,
          WindowWeatherStatus.partial,
        );
        expect(
          result.rankedWindows.first.weatherTimeCoverage,
          closeTo(1, 1e-8),
        );
        expect(
          result.rankedWindows.first.weatherParameterCoverage,
          closeTo(0.9, 1e-8),
        );
      },
    );

    test('clear weather ranks higher than overcast for the same interval', () {
      final options = const ObservationWindowOptions(
        minimumSessionDuration: Duration(hours: 2),
        maximumSessionDuration: Duration(hours: 2),
      );
      final times = [
        for (
          var utc = DateTime.utc(2026, 11, 1, 18);
          utc.isBefore(DateTime.utc(2026, 11, 2, 7));
          utc = utc.add(const Duration(hours: 1))
        )
          utc,
      ];
      final clear = recommend(
        options: options,
        weather: weatherSnapshot(
          hours: [for (final utc in times) hour(utc, cloud: 0)],
        ),
      );
      final overcast = recommend(
        options: options,
        weather: weatherSnapshot(
          hours: [for (final utc in times) hour(utc, cloud: 100)],
        ),
      );
      expect(clear.rankedWindows, isNotEmpty);
      expect(overcast.rankedWindows, isNotEmpty);
      expect(
        clear.rankedWindows.first.score.score,
        greaterThan(overcast.rankedWindows.first.score.score),
      );
    });
  });

  group('Validation', () {
    test('invalid duration and overlap configuration is rejected', () {
      expect(
        () => const ObservationWindowOptions(
          minimumSessionDuration: Duration(minutes: 10),
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () =>
            const ObservationWindowOptions(maximumOverlapFraction: double.nan)
                .validate(),
        throwsArgumentError,
      );
    });

    test('non UTC instants are rejected', () {
      expect(
        () => ObservationWindowRecommendation.forUtcPeriod(
          targets: const [polarTarget],
          observer: site,
          startUtc: DateTime(2026, 11, 1, 19),
          endUtc: utcEnd,
          evaluatedAtUtc: now,
        ),
        throwsArgumentError,
      );
    });

    test('duplicate catalog IDs are rejected', () {
      expect(
        () => recommend(targets: const [polarTarget, polarTarget]),
        throwsArgumentError,
      );
    });
  });
}
