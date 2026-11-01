import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/intelligence/domain/services/astrophotography_suitability_scoring.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';

const observer = ObserverPosition(
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
);

// Near the north celestial pole, always above 30 degrees at this site.
const target = CelestialObject(
  id: 'circumpolar',
  designation: 'Synthetic circumpolar target',
  category: CelestialCategory.nebula,
  sourceType: 'Test',
  raDegrees: 80,
  decDegrees: 85,
  constellation: 'UMi',
  commonNames: '',
  aliases: '',
  majorAxisArcmin: 30,
  minorAxisArcmin: 20,
);

const southernTarget = CelestialObject(
  id: 'never-rise',
  designation: 'Southern target',
  category: CelestialCategory.galaxy,
  sourceType: 'Test',
  raDegrees: 80,
  decDegrees: -80,
  constellation: 'Oct',
  commonNames: '',
  aliases: '',
  majorAxisArcmin: 30,
  minorAxisArcmin: 20,
);

const matchingOptics = OpticalMetrics(
  effectiveFocalLengthMm: 800,
  effectiveFocalRatio: 5,
  horizontalFovDegrees: 1,
  verticalFovDegrees: 1,
  pixelScaleXArcsec: 1.5,
  pixelScaleYArcsec: 1.5,
);

const narrowOptics = OpticalMetrics(
  effectiveFocalLengthMm: 2400,
  effectiveFocalRatio: 10,
  horizontalFovDegrees: 0.15,
  verticalFovDegrees: 0.15,
  pixelScaleXArcsec: 0.4,
  pixelScaleYArcsec: 0.4,
);

final start = DateTime.utc(2026, 11, 1, 18);
final end = DateTime.utc(2026, 11, 2, 4);
final evaluated = DateTime.utc(2026, 11, 1, 17, 20);

WeatherForecastSnapshot forecast({
  double clouds = 0,
  bool partial = false,
  bool stale = false,
  bool wrongLocation = false,
}) {
  final hours = <HourlyWeatherForecast>[];
  for (
    var time = start;
    time.isBefore(end);
    time = time.add(const Duration(hours: 1))
  ) {
    hours.add(
      HourlyWeatherForecast(
        timeUtc: time,
        totalCloudCoverPercent: WeatherValue.available(clouds),
        lowCloudCoverPercent: partial
            ? const WeatherValue.unavailable()
            : WeatherValue.available(clouds),
        midCloudCoverPercent: WeatherValue.available(clouds),
        highCloudCoverPercent: WeatherValue.available(clouds),
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
      provider: const WeatherProviderMetadata(id: 'mock', name: 'Mock'),
      latitudeDegrees: wrongLocation ? 0 : observer.latitudeDegrees,
      longitudeDegrees: observer.longitudeDegrees,
      issuedAtUtc: DateTime.utc(2026, 11, 1, 17),
      fetchedAtUtc: DateTime.utc(2026, 11, 1, 17, 10),
      hours: hours,
    ),
    origin: stale
        ? WeatherForecastOrigin.staleFallback
        : WeatherForecastOrigin.network,
    checkedAtUtc: evaluated,
    isStale: stale,
  );
}

TargetSuitabilityScore calculate({
  CelestialObject object = target,
  DateTime? from,
  DateTime? to,
  DateTime? asOf,
  WeatherForecastSnapshot? weather,
  OpticalMetrics? optics = matchingOptics,
  SuitabilityScoringProfile profile = const SuitabilityScoringProfile(),
}) {
  return AstrophotographySuitabilityScoring.score(
    target: object,
    observer: observer,
    startUtc: from ?? start,
    endUtc: to ?? end,
    evaluatedAtUtc: asOf ?? evaluated,
    weather: weather,
    optics: optics,
    profile: profile,
  );
}

void main() {
  group('Interval suitability scoring', () {
    test(
      'identical inputs produce identical results with inspectable factors',
      () {
        final weather = forecast();
        final one = calculate(weather: weather);
        final two = calculate(weather: weather);
        expect(one.score, two.score);
        expect(one.dataCoverage, two.dataCoverage);
        expect(one.score, inInclusiveRange(0.0, 100.0));
        expect(one.factors.keys.toSet(), SuitabilityFactor.values.toSet());
        for (final factor in SuitabilityFactor.values) {
          final a = one.factor(factor);
          final b = two.factor(factor);
          expect(a.rawScore, b.rawScore);
          expect(a.explanation, isNotEmpty);
          expect(a.contribution, inInclusiveRange(0.0, 100.0));
          expect(a.weight, inInclusiveRange(0.0, 1.0));
        }
      },
    );

    test('weather missing is provisional and capped, never clear skies', () {
      final missing = calculate();
      expect(missing.isProvisional, isTrue);
      expect(missing.score, lessThanOrEqualTo(50));
      expect(
        missing.factor(SuitabilityFactor.weather).status,
        SuitabilityDataStatus.missing,
      );
      expect(missing.factor(SuitabilityFactor.weather).rawScore, isNull);
      expect(missing.factor(SuitabilityFactor.weather).contribution, 0);
      expect(missing.constraints.join(' '), contains('weather'));
    });

    test('stale forecast cannot masquerade as newly retrieved forecast', () {
      final fresh = calculate(weather: forecast());
      final stale = calculate(weather: forecast(stale: true));
      expect(stale.score, lessThanOrEqualTo(50));
      expect(
        stale.factor(SuitabilityFactor.weather).status,
        SuitabilityDataStatus.missing,
      );
      expect(fresh.factor(SuitabilityFactor.weather).rawScore, isNotNull);
      expect(stale.score, lessThan(fresh.score));
    });

    test('forecast from a different site is not usable', () {
      final result = calculate(weather: forecast(wrongLocation: true));
      expect(
        result.factor(SuitabilityFactor.weather).status,
        SuitabilityDataStatus.missing,
      );
      expect(
        result.factor(SuitabilityFactor.weather).explanation,
        contains('does not match'),
      );
    });

    test('incomplete weather has lower quality and explicit coverage', () {
      final complete = calculate(weather: forecast());
      final partial = calculate(weather: forecast(partial: true));
      final factor = partial.factor(SuitabilityFactor.weather);
      expect(factor.status, SuitabilityDataStatus.partial);
      expect(factor.dataCoverage, lessThan(1));
      expect(factor.dataCoverage, greaterThan(0));
      expect(partial.score, lessThan(complete.score));
      expect(partial.isProvisional, isTrue);
    });

    test('clouds reduce interval suitability', () {
      final clear = calculate(weather: forecast());
      final overcast = calculate(weather: forecast(clouds: 100));
      expect(
        overcast.factor(SuitabilityFactor.weather).rawScore!,
        lessThan(clear.factor(SuitabilityFactor.weather).rawScore!),
      );
      expect(overcast.score, lessThan(clear.score));
    });

    test('bright daytime interval fails astronomical darkness gate', () {
      final result = calculate(
        from: DateTime.utc(2026, 11, 1, 11),
        to: DateTime.utc(2026, 11, 1, 12),
      );
      expect(result.astronomicalDarkDuration, Duration.zero);
      expect(result.score, 0);
      expect(result.constraints.join(' '), contains('darkness'));
    });

    test(
      'southern target never reaches northern observer minimum altitude',
      () {
        final result = calculate(object: southernTarget, weather: forecast());
        expect(result.visibleDuration, Duration.zero);
        expect(result.usableDuration, Duration.zero);
        expect(result.score, 0);
        expect(result.constraints.join(' '), contains('minimum altitude'));
      },
    );

    test('midnight-spanning interval remains absolute UTC and nonempty', () {
      final result = calculate(weather: forecast());
      expect(
        result.endUtc.difference(result.startUtc),
        const Duration(hours: 10),
      );
      expect(result.astronomicalDarkDuration, greaterThan(Duration.zero));
      expect(result.usableDuration, greaterThan(Duration.zero));
      expect(result.bestUsableAltitudeDegrees, isNotNull);
    });

    test(
      'optical framing penalizes a setup that cannot contain the target',
      () {
        final good = calculate(weather: forecast(), optics: matchingOptics);
        final narrow = calculate(weather: forecast(), optics: narrowOptics);
        expect(narrow.factor(SuitabilityFactor.fieldOfView).rawScore, 0);
        expect(
          good.factor(SuitabilityFactor.fieldOfView).rawScore!,
          greaterThan(0),
        );
        expect(narrow.score, lessThan(good.score));
      },
    );

    test('missing optics is explicit and has zero weighted contribution', () {
      final result = calculate(weather: forecast(), optics: null);
      final factor = result.factor(SuitabilityFactor.fieldOfView);
      expect(factor.status, SuitabilityDataStatus.missing);
      expect(factor.rawScore, isNull);
      expect(factor.contribution, 0);
    });

    test('factor weights are configurable', () {
      final weather = forecast(clouds: 100);
      final defaultScore = calculate(weather: weather);
      final weatherOnly = calculate(
        weather: weather,
        profile: const SuitabilityScoringProfile(
          weights: SuitabilityWeights(
            altitude: 0,
            visibleDuration: 0,
            astronomicalDarkness: 0,
            weather: 1,
            moonlight: 0,
            fieldOfView: 0,
          ),
        ),
      );
      expect(
        weatherOnly.score,
        weatherOnly.factor(SuitabilityFactor.weather).contribution,
      );
      expect(weatherOnly.score, lessThan(defaultScore.score));
    });
  });

  group('Validation and lunar reference geometry', () {
    test('invalid or entirely zero weights are rejected', () {
      expect(
        () => const SuitabilityWeights(altitude: -1).validate(),
        throwsArgumentError,
      );
      expect(
        () => const SuitabilityWeights(
          altitude: 0,
          visibleDuration: 0,
          astronomicalDarkness: 0,
          weather: 0,
          moonlight: 0,
          fieldOfView: 0,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const SuitabilityWeights(weather: double.nan).validate(),
        throwsArgumentError,
      );
    });

    test('reversed, non-UTC and excessively long intervals are rejected', () {
      expect(() => calculate(from: end, to: start), throwsArgumentError);
      expect(
        () => calculate(from: DateTime(2026, 11, 1), to: end),
        throwsArgumentError,
      );
      expect(
        () => calculate(to: start.add(const Duration(days: 3))),
        throwsArgumentError,
      );
    });

    test('Moon below horizon creates no direct moonlight interference', () {
      expect(
        AstrophotographySuitabilityScoring.lunarQuality(
          moonAltitudeDegrees: -1,
          illuminationFraction: 1,
          targetSeparationDegrees: 1,
        ),
        100,
      );
    });

    test('full Moon near target is worse than a dim Moon far away', () {
      final fullNear = AstrophotographySuitabilityScoring.lunarQuality(
        moonAltitudeDegrees: 40,
        illuminationFraction: 1,
        targetSeparationDegrees: 10,
      );
      final crescentFar = AstrophotographySuitabilityScoring.lunarQuality(
        moonAltitudeDegrees: 40,
        illuminationFraction: 0.1,
        targetSeparationDegrees: 80,
      );
      expect(fullNear, 0);
      expect(crescentFar, greaterThan(90));
    });

    test('Moon angular separation and illumination inputs are validated', () {
      expect(
        () => AstrophotographySuitabilityScoring.lunarQuality(
          moonAltitudeDegrees: 10,
          illuminationFraction: 1.5,
          targetSeparationDegrees: 25,
        ),
        throwsArgumentError,
      );
    });
  });
}
