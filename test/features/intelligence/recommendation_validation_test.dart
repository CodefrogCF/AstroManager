import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/core/astronomy/lunar_ephemeris.dart';
import 'package:astromanager/core/astronomy/solar_events.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/intelligence/domain/services/astrophotography_suitability_scoring.dart';
import 'package:astromanager/features/intelligence/domain/services/observation_window_recommendation.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';

import 'fixtures/recommendation_scenarios.dart';

/// Cross-engine regression scenarios for milestone v0.3.0.
///
/// Individual formula tests already live next to the astronomical engines.
/// These tests check *combined* behavior and use no wall clock or network.
void main() {
  final start = RecommendationScenarios.startUtc;
  final end = RecommendationScenarios.endUtc;
  final evaluated = RecommendationScenarios.evaluatedAtUtc;
  const target = RecommendationScenarios.circumpolar;
  const observer = RecommendationScenarios.observer;

  TargetSuitabilityScore score({
    CelestialObject object = target,
    DateTime? from,
    DateTime? to,
    SuitabilityScoringProfile profile = const SuitabilityScoringProfile(),
    bool includeOptics = true,
    bool includeWeather = true,
    bool staleWeather = false,
    double cloudPercent = 0,
    bool missingAllWeatherParameters = false,
    bool unavailableLowClouds = false,
    bool missingTotalClouds = false,
    List<DateTime>? hoursUtc,
  }) => AstrophotographySuitabilityScoring.score(
    target: object,
    observer: observer,
    startUtc: from ?? start,
    endUtc: to ?? end,
    evaluatedAtUtc: evaluated,
    weather: includeWeather
        ? RecommendationScenarios.forecast(
            cloudPercent: cloudPercent,
            missingAll: missingAllWeatherParameters,
            unavailableLowClouds: unavailableLowClouds,
            missingTotalClouds: missingTotalClouds,
            stale: staleWeather,
            hoursUtc: hoursUtc,
          )
        : null,
    optics: includeOptics ? RecommendationScenarios.optics : null,
    profile: profile,
  );

  ObservationWindowRecommendations recommend({
    List<CelestialObject> targets = const [target],
    DateTime? from,
    DateTime? to,
    ObservationWindowOptions options = const ObservationWindowOptions(
      minimumSessionDuration: Duration(hours: 1),
      maximumSessionDuration: Duration(hours: 2),
      candidateStep: Duration(minutes: 30),
    ),
    bool includeWeather = true,
    bool staleWeather = false,
    double clouds = 0,
    bool missingAllWeatherParameters = false,
    bool unavailableLowClouds = false,
    List<DateTime>? hoursUtc,
  }) => ObservationWindowRecommendation.forUtcPeriod(
    targets: targets,
    observer: observer,
    startUtc: from ?? start,
    endUtc: to ?? end,
    evaluatedAtUtc: evaluated,
    weather: includeWeather
        ? RecommendationScenarios.forecast(
            cloudPercent: clouds,
            stale: staleWeather,
            missingAll: missingAllWeatherParameters,
            unavailableLowClouds: unavailableLowClouds,
            hoursUtc: hoursUtc,
          )
        : null,
    optics: RecommendationScenarios.optics,
    options: options,
  );

  group('Independent geometry references', () {
    test('J2000 meridian transit is the zenith at geographic equator', () {
      final utc = DateTime.utc(2000, 1, 1, 12);
      // Published J2000 GMST at 2000-01-01 12:00 UT1 is 280.46061837°.
      // UTC approximates UT1, as documented by the current engine.
      final pos = AstronomicalCoordinates.equatorialToHorizontal(
        equatorialOfDate: EquatorialPosition(
          raDegrees: 280.46061837,
          decDegrees: 0,
        ),
        observer: const ObserverPosition(
          latitudeDegrees: 0,
          longitudeDegrees: 0,
        ),
        time: utc,
      );
      expect(pos.altitudeDegrees, closeTo(90, 0.001));
      expect(pos.azimuthDegrees, isNull);
    });

    test('near-polar target stays above 45 degrees at Zurich site', () {
      for (var hour = 0; hour < 24; hour += 3) {
        final altitude = AstronomicalCoordinates.calculateJ2000(
          j2000: EquatorialPosition(
            raDegrees: target.raDegrees,
            decDegrees: target.decDegrees,
          ),
          observer: observer,
          time: DateTime.utc(2026, 11, 1, hour),
        ).horizontal.altitudeDegrees;
        expect(altitude, inInclusiveRange(45.0, 50.0));
      }
    });

    test('fixed night is dark; the corresponding daytime interval is not', () {
      for (final at in [start, end]) {
        expect(
          SolarEvents.sunAltitudeDegrees(
            at: at,
            latitudeDegrees: observer.latitudeDegrees,
            longitudeDegrees: observer.longitudeDegrees,
          ),
          lessThan(-18),
        );
      }
      final daytime = DateTime.utc(2026, 11, 1, 12);
      expect(
        SolarEvents.sunAltitudeDegrees(
          at: daytime,
          latitudeDegrees: observer.latitudeDegrees,
          longitudeDegrees: observer.longitudeDegrees,
        ),
        greaterThan(0),
      );
    });
  });

  group('Score integrity and monotonicity', () {
    test(
      'identical inputs reproduce scores, contributions and explanations',
      () {
        final a = score();
        final b = score();
        expect(a.score, b.score);
        expect(a.dataCoverage, b.dataCoverage);
        expect(a.isProvisional, b.isProvisional);
        expect(a.constraints, b.constraints);
        expect(a.factors.keys.toSet(), SuitabilityFactor.values.toSet());
        var sum = 0.0;
        var totalWeight = 0.0;
        for (final factor in SuitabilityFactor.values) {
          final x = a.factor(factor);
          final y = b.factor(factor);
          expect(x.rawScore, y.rawScore);
          expect(x.explanation, y.explanation);
          expect(x.status, y.status);
          expect(x.contribution, y.contribution);
          expect(x.explanation, isNotEmpty);
          expect(x.weight, inInclusiveRange(0, 1));
          expect(x.contribution, inInclusiveRange(0, 100));
          expect(x.dataCoverage, inInclusiveRange(0, 1));
          if (x.rawScore != null) {
            expect(x.rawScore!, inInclusiveRange(0, 100));
            expect(x.contribution, closeTo(x.rawScore! * x.weight, 1e-9));
          } else {
            expect(x.contribution, 0);
          }
          sum += x.contribution;
          totalWeight += x.weight;
        }
        expect(totalWeight, closeTo(1, 1e-12));
        expect(a.score, inInclusiveRange(0, 100));
        // Complete, non-gated conditions have no final score penalty.
        expect(a.constraints, isEmpty);
        expect(a.score, closeTo(sum, 1e-8));
      },
    );

    test('clear skies score above complete overcast for identical inputs', () {
      final clear = score();
      final overcast = score(cloudPercent: 100);
      expect(clear.score, greaterThan(overcast.score));
      expect(
        clear.factor(SuitabilityFactor.weather).rawScore!,
        greaterThan(overcast.factor(SuitabilityFactor.weather).rawScore!),
      );
      // Nothing astronomical or optical changes when only clouds change.
      for (final factor in SuitabilityFactor.values.where(
        (value) => value != SuitabilityFactor.weather,
      )) {
        expect(clear.factor(factor).rawScore, overcast.factor(factor).rawScore);
      }
    });

    test('heavy precipitation reduces quality even without extra clouds', () {
      final dry = score();
      final rain = AstrophotographySuitabilityScoring.score(
        target: target,
        observer: observer,
        startUtc: start,
        endUtc: end,
        evaluatedAtUtc: evaluated,
        optics: RecommendationScenarios.optics,
        weather: RecommendationScenarios.forecast(
          precipitationMm: 2,
          precipitationProbabilityPercent: 100,
        ),
      );
      expect(rain.score, lessThan(dry.score));
      expect(
        rain.factor(SuitabilityFactor.weather).rawScore!,
        lessThan(dry.factor(SuitabilityFactor.weather).rawScore!),
      );
    });

    test('missing and stale weather never become ideal weather', () {
      final clear = score();
      for (final incomplete in [
        score(includeWeather: false),
        score(staleWeather: true),
        score(missingAllWeatherParameters: true),
      ]) {
        final weatherFactor = incomplete.factor(SuitabilityFactor.weather);
        expect(incomplete.isProvisional, isTrue);
        expect(incomplete.score, inInclusiveRange(0, 50));
        expect(incomplete.score, lessThan(clear.score));
        expect(weatherFactor.rawScore, isNull);
        expect(weatherFactor.status, SuitabilityDataStatus.missing);
        expect(weatherFactor.contribution, 0);
        expect(weatherFactor.explanation, isNotEmpty);
      }
    });

    test('fresh download does not erase an old model publication time', () {
      final fresh = RecommendationScenarios.forecast();
      final oldModel = WeatherForecastSnapshot(
        forecast: WeatherForecast(
          provider: fresh.forecast.provider,
          latitudeDegrees: fresh.forecast.latitudeDegrees,
          longitudeDegrees: fresh.forecast.longitudeDegrees,
          issuedAtUtc: DateTime.utc(2026, 10, 31, 5),
          fetchedAtUtc: fresh.forecast.fetchedAtUtc,
          hours: fresh.forecast.hours,
        ),
        origin: WeatherForecastOrigin.network,
        checkedAtUtc: evaluated,
        isStale: false,
      );
      final result = AstrophotographySuitabilityScoring.score(
        target: target,
        observer: observer,
        startUtc: start,
        endUtc: end,
        evaluatedAtUtc: evaluated,
        weather: oldModel,
        optics: RecommendationScenarios.optics,
      );
      expect(result.score, lessThanOrEqualTo(50));
      expect(result.factor(SuitabilityFactor.weather).rawScore, isNull);
      expect(
        result.factor(SuitabilityFactor.weather).explanation,
        contains('stale'),
      );
    });

    test('missing one layer remains partial, not a fabricated clear value', () {
      final clear = score();
      final unavailable = score(unavailableLowClouds: true);
      final missingTotal = score(missingTotalClouds: true);
      for (final partial in [unavailable, missingTotal]) {
        final weatherFactor = partial.factor(SuitabilityFactor.weather);
        expect(partial.isProvisional, isTrue);
        expect(weatherFactor.status, SuitabilityDataStatus.partial);
        expect(weatherFactor.dataCoverage, greaterThan(0));
        expect(weatherFactor.dataCoverage, lessThan(1));
        expect(partial.score, lessThan(clear.score));
      }
    });

    test('fresh weather for another site is not used for scoring', () {
      final mismatch = AstrophotographySuitabilityScoring.score(
        target: target,
        observer: observer,
        startUtc: start,
        endUtc: end,
        evaluatedAtUtc: evaluated,
        optics: RecommendationScenarios.optics,
        weather: RecommendationScenarios.forecast(wrongLocation: true),
      );
      expect(mismatch.score, lessThanOrEqualTo(50));
      expect(mismatch.factor(SuitabilityFactor.weather).rawScore, isNull);
      expect(
        mismatch.factor(SuitabilityFactor.weather).explanation,
        contains('does not match'),
      );
    });

    test('one missing hour penalizes the score and is not interpolated', () {
      final complete = score();
      final partial = score(hoursUtc: [start]);
      expect(partial.score, lessThan(complete.score));
      final factor = partial.factor(SuitabilityFactor.weather);
      expect(factor.dataCoverage, closeTo(0.5, 1e-10));
      expect(factor.status, SuitabilityDataStatus.partial);
    });

    test('darkness and minimum altitude are hard astronomical gates', () {
      final noSun = score(
        from: DateTime.utc(2026, 11, 1, 11),
        to: DateTime.utc(2026, 11, 1, 12),
      );
      final tooLow = score(object: RecommendationScenarios.farSouth);
      expect(noSun.score, 0);
      expect(noSun.astronomicalDarkDuration, Duration.zero);
      expect(noSun.constraints.join(' '), contains('darkness'));
      expect(tooLow.score, 0);
      expect(tooLow.usableDuration, Duration.zero);
      expect(tooLow.constraints.join(' '), contains('minimum altitude'));
    });

    test('configurable weights change only the intended contribution', () {
      const weighted = SuitabilityScoringProfile(
        weights: SuitabilityWeights(
          altitude: 1,
          visibleDuration: 0,
          astronomicalDarkness: 0,
          weather: 3,
          moonlight: 0,
          fieldOfView: 0,
        ),
      );
      final a = score(profile: weighted, cloudPercent: 0);
      final b = score(profile: weighted, cloudPercent: 100);
      expect(a.factor(SuitabilityFactor.weather).weight, closeTo(0.75, 1e-12));
      expect(a.factor(SuitabilityFactor.altitude).weight, closeTo(0.25, 1e-12));
      expect(a.score, greaterThan(b.score));
      expect(
        a.factor(SuitabilityFactor.altitude).contribution,
        b.factor(SuitabilityFactor.altitude).contribution,
      );
    });

    test('lunar heuristic prefers Moon below horizon or far away', () {
      final fullNear = AstrophotographySuitabilityScoring.lunarQuality(
        moonAltitudeDegrees: 50,
        illuminationFraction: 1,
        targetSeparationDegrees: 5,
      );
      final dimFar = AstrophotographySuitabilityScoring.lunarQuality(
        moonAltitudeDegrees: 50,
        illuminationFraction: 0.1,
        targetSeparationDegrees: 80,
      );
      final belowHorizon = AstrophotographySuitabilityScoring.lunarQuality(
        moonAltitudeDegrees: -2,
        illuminationFraction: 1,
        targetSeparationDegrees: 5,
      );
      expect(fullNear, lessThan(dimFar));
      expect(fullNear, lessThan(15));
      expect(belowHorizon, 100);
    });

    test('real lunar ephemeris produces a poor score near a bright Moon', () {
      // Search a fixed interval around the November 2026 full Moon.
      // Never use the system clock or online phase data in the test.
      DateTime? selected;
      LunarPosition? moon;
      for (
        var at = DateTime.utc(2026, 11, 23, 18);
        at.isBefore(DateTime.utc(2026, 11, 27, 4));
        at = at.add(const Duration(minutes: 30))
      ) {
        final position = LunarEphemeris.positionAt(at: at, observer: observer);
        final sun = SolarEvents.sunAltitudeDegrees(
          at: at,
          latitudeDegrees: observer.latitudeDegrees,
          longitudeDegrees: observer.longitudeDegrees,
        );
        if (position.illuminationFraction >= 0.9 &&
            position.horizontal.altitudeDegrees > 40 &&
            sun < -25) {
          selected = at;
          moon = position;
          break;
        }
      }
      expect(
        selected,
        isNotNull,
        reason: 'Expected a bright, high Moon at night.',
      );
      final chosen = selected!;
      final chosenMoon = moon!;
      final nearMoon = CelestialObject(
        id: 'fixture-moon-neighbor',
        designation: 'Moon-adjacent synthetic target',
        category: CelestialCategory.nebula,
        sourceType: 'Fixture',
        raDegrees: chosenMoon.topocentricEquatorial.raDegrees,
        decDegrees: chosenMoon.topocentricEquatorial.decDegrees,
        constellation: 'Fixture',
        commonNames: '',
        aliases: '',
      );
      final condition = LunarEphemeris.conditionsForTarget(
        at: chosen,
        observer: observer,
        targetJ2000: EquatorialPosition(
          raDegrees: nearMoon.raDegrees,
          decDegrees: nearMoon.decDegrees,
        ),
      );
      expect(condition.targetSeparationDegrees, lessThan(5));
      final outcome = AstrophotographySuitabilityScoring.score(
        target: nearMoon,
        observer: observer,
        startUtc: chosen,
        endUtc: chosen.add(const Duration(minutes: 30)),
        evaluatedAtUtc: chosen,
        profile: const SuitabilityScoringProfile(minimumAltitudeDegrees: 30),
      );
      expect(outcome.usableDuration, greaterThan(Duration.zero));
      expect(
        outcome.factor(SuitabilityFactor.moonlight).rawScore!,
        lessThan(35),
      );
    });

    test('rejects impossible intervals and invalid weights', () {
      expect(() => score(from: end, to: start), throwsArgumentError);
      expect(() => score(from: start, to: start), throwsArgumentError);
      expect(() => score(from: DateTime(2026, 11, 1, 20)), throwsArgumentError);
      expect(
        () => score(
          profile: const SuitabilityScoringProfile(
            weights: SuitabilityWeights(weather: double.nan),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Ranked windows and boundary regressions', () {
    test('ranked windows are entirely within dark intervals', () {
      final result = recommend();
      expect(result.rankedWindows, isNotEmpty);
      for (final window in result.rankedWindows) {
        expect(window.startUtc.isUtc && window.endUtc.isUtc, isTrue);
        expect(window.duration, greaterThanOrEqualTo(const Duration(hours: 1)));
        expect(window.score.score, inInclusiveRange(0, 100));
        expect(
          window.score.factors.keys.toSet(),
          SuitabilityFactor.values.toSet(),
        );
        expect(window.explanation, isNotEmpty);
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

    test('identical and shuffled target sets produce identical rankings', () {
      const first = [target, RecommendationScenarios.secondNorthern];
      const second = [RecommendationScenarios.secondNorthern, target];
      final a = recommend(targets: first);
      final b = recommend(targets: second);
      final again = recommend(targets: first);
      List<(String, DateTime, DateTime, double)> signature(
        ObservationWindowRecommendations result,
      ) => [
        for (final w in result.rankedWindows)
          (w.targetId, w.startUtc, w.endUtc, w.score.score),
      ];
      expect(signature(a), signature(b));
      expect(signature(a), signature(again));
      for (var i = 1; i < a.rankedWindows.length; i++) {
        expect(
          a.rankedWindows[i - 1].score.score,
          greaterThanOrEqualTo(a.rankedWindows[i].score.score),
        );
      }
    });

    test('better cloud conditions improve comparable ranked window scores', () {
      final clear = recommend(clouds: 0);
      final overcast = recommend(clouds: 100);
      expect(clear.rankedWindows, isNotEmpty);
      expect(overcast.rankedWindows, isNotEmpty);
      expect(
        clear.rankedWindows.first.score.score,
        greaterThan(overcast.rankedWindows.first.score.score),
      );
    });

    test('weather coverage and explanations distinguish sparse from stale', () {
      final clear = recommend();
      final missing = recommend(includeWeather: false);
      final stale = recommend(staleWeather: true);
      // Force the candidate to cover both hours. With 1-hour candidates,
      // the engine could legitimately select the fully covered first hour.
      final sparse = recommend(
        hoursUtc: [start],
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 2),
          maximumSessionDuration: Duration(hours: 2),
        ),
      );
      final unavailable = recommend(unavailableLowClouds: true);
      expect(
        clear.rankedWindows.first.weatherStatus,
        WindowWeatherStatus.complete,
      );
      expect(
        missing.rankedWindows.first.weatherStatus,
        WindowWeatherStatus.missing,
      );
      expect(
        stale.rankedWindows.first.weatherStatus,
        WindowWeatherStatus.stale,
      );
      expect(
        sparse.rankedWindows.first.weatherStatus,
        WindowWeatherStatus.partial,
      );
      expect(
        unavailable.rankedWindows.first.weatherStatus,
        WindowWeatherStatus.partial,
      );
      expect(missing.rankedWindows.first.score.score, lessThanOrEqualTo(50));
      expect(stale.rankedWindows.first.score.score, lessThanOrEqualTo(50));
      expect(missing.rankedWindows.first.explanation, contains('No weather'));
      expect(stale.rankedWindows.first.explanation, contains('stale'));
      expect(sparse.rankedWindows.first.weatherTimeCoverage, greaterThan(0));
      expect(sparse.rankedWindows.first.weatherTimeCoverage, lessThan(1));
      expect(
        unavailable.rankedWindows.first.weatherParameterCoverage,
        lessThan(1),
      );
    });

    test('never-visible target and short interval are rejected explicitly', () {
      final south = recommend(
        targets: const [RecommendationScenarios.farSouth],
      );
      expect(south.rankedWindows, isEmpty);
      expect(south.excludedTargets.values.single, contains('minimum altitude'));
      final short = recommend(
        from: DateTime.utc(2026, 11, 1, 20),
        to: DateTime.utc(2026, 11, 1, 20, 40),
      );
      expect(short.rankedWindows, isEmpty);
      expect(
        short.excludedTargets.values.single,
        contains('minimum session duration'),
      );
    });

    test('separate nights are not connected through daylight', () {
      final a = DateTime.utc(2026, 11, 1, 12);
      final b = a.add(const Duration(hours: 48));
      final nights = recommend(
        from: a,
        to: b,
        includeWeather: false,
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 2),
          maximumSessionDuration: Duration(hours: 3),
          candidateStep: Duration(hours: 1),
        ),
      );
      expect(nights.astronomicalDarkness.length, greaterThanOrEqualTo(2));
      expect(nights.rankedWindows, isNotEmpty);
      for (final window in nights.rankedWindows) {
        expect(
          nights.astronomicalDarkness.any(
            (dark) =>
                !window.startUtc.isBefore(dark.startUtc) &&
                !window.endUtc.isAfter(dark.endUtc),
          ),
          isTrue,
        );
      }
    });

    test('midnight windows have ascending absolute UTC endpoints', () {
      final midnight = recommend(
        from: DateTime.utc(2026, 11, 1, 23, 30),
        to: DateTime.utc(2026, 11, 2, 1, 30),
        includeWeather: false,
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 2),
          maximumSessionDuration: Duration(hours: 2),
        ),
      );
      expect(midnight.rankedWindows, hasLength(1));
      final window = midnight.rankedWindows.single;
      expect(window.startUtc.day, 1);
      expect(window.endUtc.day, 2);
      expect(window.duration, const Duration(hours: 2));
    });

    test('DST transitions use 23- and 25-hour UTC observation nights', () {
      final spring = ObservationWindowRecommendation.forObservingNight(
        targets: const [target],
        location: RecommendationScenarios.location,
        localDate: DateTime.utc(2026, 3, 28),
        evaluatedAtUtc: DateTime.utc(2026, 3, 28, 11),
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 1),
          maximumSessionDuration: Duration(hours: 1),
          candidateStep: Duration(hours: 1),
        ),
      );
      final autumn = ObservationWindowRecommendation.forObservingNight(
        targets: const [target],
        location: RecommendationScenarios.location,
        localDate: DateTime.utc(2026, 10, 24),
        evaluatedAtUtc: DateTime.utc(2026, 10, 24, 10),
        options: const ObservationWindowOptions(
          minimumSessionDuration: Duration(hours: 1),
          maximumSessionDuration: Duration(hours: 1),
          candidateStep: Duration(hours: 1),
        ),
      );
      expect(
        spring.periodEndUtc.difference(spring.periodStartUtc),
        const Duration(hours: 23),
      );
      expect(
        autumn.periodEndUtc.difference(autumn.periodStartUtc),
        const Duration(hours: 25),
      );
      for (final night in [spring, autumn]) {
        expect(night.rankedWindows, isNotEmpty);
        expect(
          night.rankedWindows.every((w) => w.startUtc.isUtc && w.endUtc.isUtc),
          isTrue,
        );
      }
    });

    test(
      'invalid boundaries and duplicate targets never become recommendations',
      () {
        expect(() => recommend(from: end, to: start), throwsArgumentError);
        expect(
          () => recommend(targets: const [target, target]),
          throwsArgumentError,
        );
        expect(
          () => recommend(
            options: const ObservationWindowOptions(
              minimumSessionDuration: Duration(minutes: 10),
            ),
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
