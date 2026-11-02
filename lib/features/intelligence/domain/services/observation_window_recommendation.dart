import 'dart:math' as math;

import '../../../../core/astronomy/astronomical_coordinates.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../core/astronomy/target_visibility.dart';
import '../../../equipment/domain/models/equipment_models.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../../light_pollution/domain/light_pollution.dart';
import '../../../targets/domain/models/celestial_object.dart';
import '../../../weather/domain/models/weather_cache.dart';
import '../../../weather/domain/models/weather_forecast.dart';
import '../../../weather/domain/models/weather_value.dart';
import '../models/observation_window.dart';
import '../models/suitability_score.dart';
import 'astrophotography_suitability_scoring.dart';

/// Offline, deterministic recommendation search. No providers, clock access,
/// network calls or UI dependencies are used. An explicit evaluation instant
/// makes weather freshness repeatable in tests and in the night planner.
abstract final class ObservationWindowRecommendation {
  static const Duration _darknessScanStep = Duration(minutes: 5);
  static const Duration _crossingPrecision = Duration(seconds: 1);

  /// A local observing night (noon to next noon, including DST changes).
  /// Only intervals with geometric Sun altitude < -18 degrees are candidates.
  static ObservationWindowRecommendations forObservingNight({
    required List<CelestialObject> targets,
    required ObservingLocation location,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    WeatherForecastSnapshot? weather,
    WeatherCachePolicy cachePolicy = const WeatherCachePolicy(),
    OpticalMetrics? optics,
    LightPollutionReading? lightPollution,
    SuitabilityScoringProfile scoringProfile =
        const SuitabilityScoringProfile(),
    ObservationWindowOptions options = const ObservationWindowOptions(),
  }) {
    location.validate();
    final night = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: localDate,
    );
    return _recommend(
      targets: targets,
      observer: ObserverPosition(
        latitudeDegrees: location.latitude,
        longitudeDegrees: location.longitude,
        elevationMeters: location.elevationMeters,
      ),
      startUtc: night.nightStartUtc,
      endUtc: night.nightEndUtc,
      darkness: [
        for (final interval in night.astronomicalDarkness)
          VisibilityInterval(
            startUtc: interval.startUtc,
            endUtc: interval.endUtc,
          ),
      ],
      evaluatedAtUtc: evaluatedAtUtc,
      weather: weather,
      cachePolicy: cachePolicy,
      optics: optics,
      lightPollution: lightPollution,
      scoringProfile: scoringProfile,
      options: options,
    );
  }

  /// Arbitrary UTC period, bounded to 48 hours. Darkness crossings are scanned
  /// and refined independently of local time zones (and independent of DST).
  static ObservationWindowRecommendations forUtcPeriod({
    required List<CelestialObject> targets,
    required ObserverPosition observer,
    required DateTime startUtc,
    required DateTime endUtc,
    required DateTime evaluatedAtUtc,
    WeatherForecastSnapshot? weather,
    WeatherCachePolicy cachePolicy = const WeatherCachePolicy(),
    OpticalMetrics? optics,
    LightPollutionReading? lightPollution,
    SuitabilityScoringProfile scoringProfile =
        const SuitabilityScoringProfile(),
    ObservationWindowOptions options = const ObservationWindowOptions(),
  }) {
    _validatePeriod(startUtc, endUtc, evaluatedAtUtc);
    observer.validate();
    return _recommend(
      targets: targets,
      observer: observer,
      startUtc: startUtc,
      endUtc: endUtc,
      darkness: _scanAstronomicalDarkness(observer, startUtc, endUtc),
      evaluatedAtUtc: evaluatedAtUtc,
      weather: weather,
      cachePolicy: cachePolicy,
      optics: optics,
      lightPollution: lightPollution,
      scoringProfile: scoringProfile,
      options: options,
    );
  }

  static ObservationWindowRecommendations _recommend({
    required List<CelestialObject> targets,
    required ObserverPosition observer,
    required DateTime startUtc,
    required DateTime endUtc,
    required List<VisibilityInterval> darkness,
    required DateTime evaluatedAtUtc,
    required WeatherForecastSnapshot? weather,
    required WeatherCachePolicy cachePolicy,
    required OpticalMetrics? optics,
    required LightPollutionReading? lightPollution,
    required SuitabilityScoringProfile scoringProfile,
    required ObservationWindowOptions options,
  }) {
    _validatePeriod(startUtc, endUtc, evaluatedAtUtc);
    observer.validate();
    scoringProfile.validate();
    options.validate();
    final seenIds = <String>{};
    for (final target in targets) {
      target.validate();
      if (!seenIds.add(target.id)) {
        throw ArgumentError.value(target.id, 'targets', 'Duplicate target ID.');
      }
    }

    final all = <ObservationWindow>[];
    final excluded = <String, String>{};
    final sortedTargets = [...targets]..sort((a, b) => a.id.compareTo(b.id));
    for (final target in sortedTargets) {
      if (darkness.isEmpty) {
        excluded[target.id] = 'No astronomical darkness in this period.';
        continue;
      }

      final position = EquatorialPosition(
        raDegrees: target.raDegrees,
        decDegrees: target.decDegrees,
      );
      final visibility = TargetVisibility.calculate(
        targetJ2000: position,
        observer: observer,
        startUtc: startUtc,
        endUtc: endUtc,
        minimumAltitudeDegrees: scoringProfile.minimumAltitudeDegrees,
        sampleStep: scoringProfile.sampleStep,
        allowedIntervals: darkness,
      );
      final candidatesBefore = all.length;
      for (final visible in visibility.visibleIntervals) {
        for (final duration in _candidateDurations(visible.duration, options)) {
          for (final candidateStart in _candidateStarts(
            visible,
            duration,
            options.candidateStep,
          )) {
            final candidateEnd = candidateStart.add(duration);
            final suitability = AstrophotographySuitabilityScoring.score(
              target: target,
              observer: observer,
              startUtc: candidateStart,
              endUtc: candidateEnd,
              evaluatedAtUtc: evaluatedAtUtc,
              weather: weather,
              cachePolicy: cachePolicy,
              optics: optics,
              lightPollution: lightPollution,
              profile: scoringProfile,
            );
            // Numerical sampling around a refined crossing may find a tiny
            // discrepancy. Never recommend a genuinely unusable interval.
            if (suitability.usableDuration == Duration.zero) continue;

            final coverage = _forecastCoverage(
              weather: weather,
              observer: observer,
              startUtc: candidateStart,
              endUtc: candidateEnd,
              evaluatedAtUtc: evaluatedAtUtc,
              cachePolicy: cachePolicy,
            );
            final best = _bestAt(
              position,
              observer,
              candidateStart,
              candidateEnd,
              scoringProfile.sampleStep,
            );
            final warning = coverage.warning;
            final issues = <String>[
              ?warning,
              for (final constraint in suitability.constraints) constraint,
            ];
            all.add(
              ObservationWindow(
                targetId: target.id,
                targetDesignation: target.displayTitle,
                startUtc: candidateStart,
                endUtc: candidateEnd,
                bestAltitudeDegrees: best.horizontal.altitudeDegrees,
                bestAltitudeAtUtc: best.utc,
                score: suitability,
                weatherStatus: coverage.status,
                weatherTimeCoverage: coverage.timeFraction,
                weatherParameterCoverage: coverage.parameterFraction,
                explanation: issues.isEmpty
                    ? 'Target is above the minimum altitude throughout astronomical darkness. '
                          'All scored factors are available in score.factors.'
                    : issues.join(' '),
              ),
            );
          }
        }
      }
      if (all.length == candidatesBefore) {
        excluded[target.id] = visibility.isNeverVisible
            ? 'Target never reaches the minimum altitude during astronomical darkness.'
            : 'No continuous visible and dark interval satisfies the minimum session duration.';
      }
    }

    // Stable ranking: highest score, then complete input, duration, and start.
    all.sort((a, b) {
      var cmp = b.score.score.compareTo(a.score.score);
      if (cmp != 0) return cmp;
      cmp = a.isProvisional == b.isProvisional ? 0 : (a.isProvisional ? 1 : -1);
      if (cmp != 0) return cmp;
      cmp = b.duration.compareTo(a.duration);
      if (cmp != 0) return cmp;
      cmp = a.startUtc.compareTo(b.startUtc);
      return cmp != 0 ? cmp : a.targetId.compareTo(b.targetId);
    });

    final ranked = <ObservationWindow>[];
    for (final candidate in all) {
      if (ranked.any(
        (prior) =>
            prior.targetId == candidate.targetId &&
            _overlapFraction(prior, candidate) >=
                options.maximumOverlapFraction,
      )) {
        continue;
      }
      ranked.add(candidate);
      if (ranked.length >= options.maximumRecommendations) break;
    }
    return ObservationWindowRecommendations(
      periodStartUtc: startUtc,
      periodEndUtc: endUtc,
      minimumAltitudeDegrees: scoringProfile.minimumAltitudeDegrees,
      astronomicalDarkness: darkness,
      rankedWindows: ranked,
      excludedTargets: excluded,
    );
  }

  static void _validatePeriod(
    DateTime start,
    DateTime end,
    DateTime evaluated,
  ) {
    if (!start.isUtc ||
        !end.isUtc ||
        !evaluated.isUtc ||
        !end.isAfter(start) ||
        end.difference(start) > const Duration(hours: 48)) {
      throw ArgumentError(
        'Expected an ascending UTC period <= 48 hours and an explicit UTC evaluation instant.',
      );
    }
  }

  static Iterable<Duration> _candidateDurations(
    Duration available,
    ObservationWindowOptions options,
  ) sync* {
    if (available < options.minimumSessionDuration) return;
    final maximum = available < options.maximumSessionDuration
        ? available
        : options.maximumSessionDuration;
    var current = options.minimumSessionDuration;
    while (current <= maximum) {
      yield current;
      current += options.candidateStep;
    }
    if (maximum > options.minimumSessionDuration &&
        maximum != current - options.candidateStep) {
      yield maximum;
    }
  }

  static Iterable<DateTime> _candidateStarts(
    VisibilityInterval interval,
    Duration duration,
    Duration step,
  ) sync* {
    final last = interval.endUtc.subtract(duration);
    if (last.isBefore(interval.startUtc)) return;
    var cursor = interval.startUtc;
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(step);
    }
    // Include the exact final endpoint even if not aligned to the grid.
    if (last.microsecondsSinceEpoch - interval.startUtc.microsecondsSinceEpoch >
            0 &&
        (last.difference(interval.startUtc).inMicroseconds %
                step.inMicroseconds) !=
            0) {
      yield last;
    }
  }

  static VisibilitySample _bestAt(
    EquatorialPosition target,
    ObserverPosition observer,
    DateTime start,
    DateTime end,
    Duration step,
  ) {
    VisibilitySample? best;
    var current = start;
    while (true) {
      final sample = VisibilitySample(
        utc: current,
        horizontal: AstronomicalCoordinates.calculateJ2000(
          j2000: target,
          observer: observer,
          time: current,
        ).horizontal,
      );
      if (best == null ||
          sample.horizontal.altitudeDegrees > best.horizontal.altitudeDegrees) {
        best = sample;
      }
      if (current == end) break;
      final next = current.add(step);
      current = next.isAfter(end) ? end : next;
    }
    return best;
  }

  static double _overlapFraction(ObservationWindow a, ObservationWindow b) {
    final start = a.startUtc.isAfter(b.startUtc) ? a.startUtc : b.startUtc;
    final end = a.endUtc.isBefore(b.endUtc) ? a.endUtc : b.endUtc;
    if (!end.isAfter(start)) return 0;
    final shortest = math.min(
      a.duration.inMicroseconds,
      b.duration.inMicroseconds,
    );
    return end.difference(start).inMicroseconds / shortest;
  }

  static List<VisibilityInterval> _scanAstronomicalDarkness(
    ObserverPosition observer,
    DateTime start,
    DateTime end,
  ) {
    bool isDark(DateTime utc) =>
        SolarEvents.sunAltitudeDegrees(
          at: utc,
          latitudeDegrees: observer.latitudeDegrees,
          longitudeDegrees: observer.longitudeDegrees,
        ) <
        SolarThreshold.astronomical.altitudeDegrees;

    final result = <VisibilityInterval>[];
    DateTime? opened = isDark(start) ? start : null;
    var left = start;
    var leftDark = isDark(left);
    while (left.isBefore(end)) {
      final stepEnd = left.add(_darknessScanStep);
      final right = stepEnd.isAfter(end) ? end : stepEnd;
      final rightDark = isDark(right);
      if (leftDark != rightDark) {
        var a = left;
        var b = right;
        while (b.difference(a) > _crossingPrecision) {
          final middle = DateTime.fromMicrosecondsSinceEpoch(
            (a.microsecondsSinceEpoch + b.microsecondsSinceEpoch) ~/ 2,
            isUtc: true,
          );
          if (isDark(middle) == leftDark) {
            a = middle;
          } else {
            b = middle;
          }
        }
        final crossing = DateTime.fromMicrosecondsSinceEpoch(
          (a.microsecondsSinceEpoch + b.microsecondsSinceEpoch) ~/ 2,
          isUtc: true,
        );
        if (leftDark) {
          if (opened != null && crossing.isAfter(opened)) {
            result.add(VisibilityInterval(startUtc: opened, endUtc: crossing));
          }
          opened = null;
        } else {
          opened = crossing;
        }
      }
      left = right;
      leftDark = rightDark;
    }
    if (opened != null && end.isAfter(opened)) {
      result.add(VisibilityInterval(startUtc: opened, endUtc: end));
    }
    return result;
  }

  static _WeatherCoverage _forecastCoverage({
    required WeatherForecastSnapshot? weather,
    required ObserverPosition observer,
    required DateTime startUtc,
    required DateTime endUtc,
    required DateTime evaluatedAtUtc,
    required WeatherCachePolicy cachePolicy,
  }) {
    if (weather == null) {
      return const _WeatherCoverage(
        WindowWeatherStatus.missing,
        0,
        0,
        'No weather forecast is available; the score remains provisional.',
      );
    }
    final forecast = weather.forecast;
    if ((forecast.latitudeDegrees - observer.latitudeDegrees).abs() > 0.02 ||
        (forecast.longitudeDegrees - observer.longitudeDegrees).abs() > 0.02) {
      return const _WeatherCoverage(
        WindowWeatherStatus.missing,
        0,
        0,
        'Forecast coordinates do not match the observing site.',
      );
    }
    if (weather.isStale ||
        weather.isStaleAt(evaluatedAtUtc, cachePolicy) ||
        weather.origin == WeatherForecastOrigin.staleCache ||
        weather.origin == WeatherForecastOrigin.staleFallback) {
      return const _WeatherCoverage(
        WindowWeatherStatus.stale,
        0,
        0,
        'Weather forecast is stale; original issue and fetch times are retained.',
      );
    }
    final hours = <int, HourlyWeatherForecast>{
      for (final value in forecast.hours)
        value.timeUtc.microsecondsSinceEpoch: value,
    };
    final totalUs = endUtc.difference(startUtc).inMicroseconds;
    var availableUs = 0.0;
    var parameterUs = 0.0;
    var hour = DateTime.utc(
      startUtc.year,
      startUtc.month,
      startUtc.day,
      startUtc.hour,
    );
    while (hour.isBefore(endUtc)) {
      final hourEnd = hour.add(const Duration(hours: 1));
      final overlapStart = hour.isAfter(startUtc) ? hour : startUtc;
      final overlapEnd = hourEnd.isBefore(endUtc) ? hourEnd : endUtc;
      final span = overlapEnd.difference(overlapStart).inMicroseconds;
      final reading = hours[hour.microsecondsSinceEpoch];
      if (span > 0 && reading != null) {
        final parameters = <WeatherValue<double>>[
          reading.totalCloudCoverPercent,
          reading.lowCloudCoverPercent,
          reading.midCloudCoverPercent,
          reading.highCloudCoverPercent,
          reading.precipitationMillimeters,
          reading.precipitationProbabilityPercent,
          reading.windSpeedMetersPerSecond,
          reading.windGustMetersPerSecond,
          reading.relativeHumidityPercent,
          reading.visibilityMeters,
        ];
        final known = parameters.where((value) => value.isAvailable).length;
        if (known > 0) availableUs += span;
        parameterUs += span * known / parameters.length;
      }
      hour = hourEnd;
    }
    final timeFraction = (availableUs / totalUs).clamp(0.0, 1.0).toDouble();
    final parameterFraction = (parameterUs / totalUs)
        .clamp(0.0, 1.0)
        .toDouble();
    if (timeFraction == 0) {
      return const _WeatherCoverage(
        WindowWeatherStatus.missing,
        0,
        0,
        'No usable hourly weather values cover this window.',
      );
    }
    final complete = parameterFraction >= 1 - 1e-10;
    return _WeatherCoverage(
      complete ? WindowWeatherStatus.complete : WindowWeatherStatus.partial,
      timeFraction,
      parameterFraction,
      complete ? null : 'Weather coverage is incomplete; unknown parameters are not treated as clear skies.',
    );
  }
}

final class _WeatherCoverage {
  const _WeatherCoverage(
    this.status,
    this.timeFraction,
    this.parameterFraction,
    this.warning,
  );
  final WindowWeatherStatus status;
  final double timeFraction;
  final double parameterFraction;
  final String? warning;
}
