import 'dart:math' as math;

import '../../../../core/astronomy/astronomical_coordinates.dart';
import '../../../../core/astronomy/lunar_ephemeris.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../core/astronomy/target_visibility.dart';
import '../../../equipment/domain/models/equipment_models.dart';
import '../../../targets/domain/models/celestial_object.dart';
import '../../../weather/domain/models/weather_cache.dart';
import '../../../weather/domain/models/weather_forecast.dart';
import '../../../weather/domain/models/weather_value.dart';
import '../models/suitability_score.dart';

/// Deterministic interval-based scoring; no UI, provider, clock, or I/O calls.
///
/// Scores are heuristic and are NOT calibrated predictions of image quality.
/// Missing readings contribute no positive points. Hard astronomical
/// constraints (no darkness or no usable target altitude) force zero.
abstract final class AstrophotographySuitabilityScoring {
  static double _bounded(double value) => value.clamp(0.0, 100.0).toDouble();
  static double _fraction(double value) => value.clamp(0.0, 1.0).toDouble();

  /// Evaluate a single UTC observation interval. [evaluatedAtUtc] is explicit
  /// so freshness checks and scores are repeatable across machines/tests.
  /// Pass the actual [WeatherForecastSnapshot] rather than its bare forecast
  /// so stale/offline data cannot masquerade as a fresh result.
  static TargetSuitabilityScore score({
    required CelestialObject target,
    required ObserverPosition observer,
    required DateTime startUtc,
    required DateTime endUtc,
    required DateTime evaluatedAtUtc,
    WeatherForecastSnapshot? weather,
    WeatherCachePolicy cachePolicy = const WeatherCachePolicy(),
    OpticalMetrics? optics,
    SuitabilityScoringProfile profile = const SuitabilityScoringProfile(),
  }) {
    target.validate();
    observer.validate();
    profile.validate();
    if (!startUtc.isUtc ||
        !endUtc.isUtc ||
        !evaluatedAtUtc.isUtc ||
        !endUtc.isAfter(startUtc)) {
      throw ArgumentError(
        'Expected valid ascending UTC interval and UTC evaluation time.',
      );
    }
    if (endUtc.difference(startUtc) > const Duration(hours: 48)) {
      throw ArgumentError('Score a maximum of 48 hours at a time.');
    }

    final targetPosition = EquatorialPosition(
      raDegrees: target.raDegrees,
      decDegrees: target.decDegrees,
    );
    final visibility = TargetVisibility.calculate(
      targetJ2000: targetPosition,
      observer: observer,
      startUtc: startUtc,
      endUtc: endUtc,
      minimumAltitudeDegrees: profile.minimumAltitudeDegrees,
      sampleStep: profile.sampleStep,
    );

    final forecast = weather?.forecast;
    final forecastMatchesObserver =
        forecast != null &&
        (forecast.latitudeDegrees - observer.latitudeDegrees).abs() <= 0.02 &&
        (forecast.longitudeDegrees - observer.longitudeDegrees).abs() <= 0.02;
    final validWeather =
        forecastMatchesObserver &&
        weather != null &&
        !weather.isStale &&
        weather.origin != WeatherForecastOrigin.staleCache &&
        weather.origin != WeatherForecastOrigin.staleFallback &&
        !weather.isStaleAt(evaluatedAtUtc, cachePolicy);
    final hourlyForecasts = <int, HourlyWeatherForecast>{};
    if (validWeather) {
      for (final hour in forecast.hours) {
        hourlyForecasts[hour.timeUtc.microsecondsSinceEpoch] = hour;
      }
    }

    final totalUs = endUtc.difference(startUtc).inMicroseconds;
    var darkUs = 0;
    var usableUs = 0;
    var moonQualityUs = 0.0;
    double? bestAltitude;
    var weatherQualityUs = 0.0;
    var weatherCoverageUs = 0.0;
    var weatherCompleteUs = 0.0;

    var cursor = startUtc;
    while (cursor.isBefore(endUtc)) {
      final suggested = cursor.add(profile.sampleStep);
      final next = suggested.isAfter(endUtc) ? endUtc : suggested;
      final spanUs = next.difference(cursor).inMicroseconds;
      final midpoint = DateTime.fromMicrosecondsSinceEpoch(
        cursor.microsecondsSinceEpoch + spanUs ~/ 2,
        isUtc: true,
      );

      final targetAltitude = AstronomicalCoordinates.calculateJ2000(
        j2000: targetPosition,
        observer: observer,
        time: midpoint,
      ).horizontal.altitudeDegrees;
      final isDark =
          SolarEvents.sunAltitudeDegrees(
            at: midpoint,
            latitudeDegrees: observer.latitudeDegrees,
            longitudeDegrees: observer.longitudeDegrees,
          ) <
          SolarThreshold.astronomical.altitudeDegrees;

      if (isDark) darkUs += spanUs;
      if (isDark && targetAltitude >= profile.minimumAltitudeDegrees) {
        usableUs += spanUs;
        if (bestAltitude == null || targetAltitude > bestAltitude) {
          bestAltitude = targetAltitude;
        }
        final lunar = LunarEphemeris.conditionsForTarget(
          at: midpoint,
          observer: observer,
          targetJ2000: targetPosition,
        );
        moonQualityUs +=
            lunarQuality(
              moonAltitudeDegrees: lunar.moon.horizontal.altitudeDegrees,
              illuminationFraction: lunar.moon.illuminationFraction,
              targetSeparationDegrees: lunar.targetSeparationDegrees,
            ) *
            spanUs;
      }

      if (validWeather) {
        final hourStart = DateTime.utc(
          midpoint.year,
          midpoint.month,
          midpoint.day,
          midpoint.hour,
        ).microsecondsSinceEpoch;
        final reading = hourlyForecasts[hourStart];
        if (reading != null) {
          final quality = _weatherQuality(reading);
          weatherQualityUs += quality.score * spanUs;
          weatherCoverageUs += quality.coverage * spanUs;
          if (quality.coverage >= 0.999999) weatherCompleteUs += spanUs;
        }
      }
      cursor = next;
    }

    final totalDuration = endUtc.difference(startUtc);
    final darkFraction = darkUs / totalUs;
    final visibleFraction =
        visibility.totalVisibleDuration.inMicroseconds / totalUs;
    final altitudeGrade = bestAltitude == null
        ? 0.0
        : _bounded(
            100 *
                (bestAltitude - profile.minimumAltitudeDegrees) /
                (profile.goodAltitudeDegrees - profile.minimumAltitudeDegrees),
          );
    final moonGrade = usableUs == 0 ? null : moonQualityUs / usableUs;
    final weatherCoverage = validWeather ? weatherCoverageUs / totalUs : 0.0;
    final weatherGrade = weatherCoverage == 0
        ? null
        : _bounded(weatherQualityUs / totalUs);

    final opticsGrade = _opticalQuality(target: target, optics: optics);
    final results = <SuitabilityFactor, SuitabilityFactorResult>{};
    final weights = profile.weights;
    final totalWeight = weights.total;

    void record(
      SuitabilityFactor factor,
      double? rawScore,
      double coverage,
      String explanation,
    ) {
      final boundedCoverage = _fraction(coverage);
      final status = boundedCoverage == 0
          ? SuitabilityDataStatus.missing
          : boundedCoverage < 0.999999
          ? SuitabilityDataStatus.partial
          : SuitabilityDataStatus.complete;
      final normalizedWeight = weights.forFactor(factor) / totalWeight;
      results[factor] = SuitabilityFactorResult(
        factor: factor,
        status: status,
        rawScore: rawScore == null ? null : _bounded(rawScore),
        weight: normalizedWeight,
        contribution:
            (rawScore == null ? 0 : _bounded(rawScore)) * normalizedWeight,
        dataCoverage: boundedCoverage,
        explanation: explanation,
      );
    }

    record(
      SuitabilityFactor.altitude,
      altitudeGrade,
      1,
      bestAltitude == null
          ? 'The target never reaches the minimum altitude during astronomical darkness.'
          : 'Best usable altitude ${bestAltitude.toStringAsFixed(1)}°, '
                'scored from ${profile.minimumAltitudeDegrees.toStringAsFixed(0)}° '
                'to ${profile.goodAltitudeDegrees.toStringAsFixed(0)}°.',
    );
    record(
      SuitabilityFactor.visibleDuration,
      100 * visibleFraction,
      1,
      'Target above minimum altitude for '
      '${_minutes(visibility.totalVisibleDuration)} of ${_minutes(totalDuration)} minutes.',
    );
    record(
      SuitabilityFactor.astronomicalDarkness,
      100 * darkFraction,
      1,
      'Sun below -18° for ${_minutes(Duration(microseconds: darkUs))} '
      'of ${_minutes(totalDuration)} minutes.',
    );
    record(
      SuitabilityFactor.weather,
      weatherGrade,
      weatherCoverage,
      weather == null
          ? 'No forecast supplied. Weather contributes no points.'
          : !forecastMatchesObserver
          ? 'Forecast location does not match the observing site.'
          : !validWeather
          ? 'Forecast is stale or offline; original timestamps retained. '
                'Weather contributes no points.'
          : weatherCoverage == 0
          ? 'No usable forecast parameters cover this interval.'
          : 'Forecast coverage ${(100 * weatherCoverage).toStringAsFixed(0)}%; '
                'complete hourly readings for '
                '${(100 * weatherCompleteUs / totalUs).toStringAsFixed(0)}% of the interval. '
                'Unavailable values score zero, not clear skies.',
    );
    record(
      SuitabilityFactor.moonlight,
      moonGrade,
      usableUs > 0 ? 1 : 0,
      usableUs == 0
          ? 'Moonlight is not assessed because there is no usable dark target interval.'
          : 'Moon altitude, illumination and topocentric target separation '
                'are evaluated throughout usable dark target time.',
    );
    record(
      SuitabilityFactor.fieldOfView,
      opticsGrade.score,
      opticsGrade.coverage,
      opticsGrade.explanation,
    );

    var score = results.values.fold<double>(
      0,
      (sum, factor) => sum + factor.contribution,
    );
    final constraints = <String>[];
    if (darkUs == 0) {
      constraints.add('No astronomical darkness within the interval.');
    }
    if (visibility.totalVisibleDuration == Duration.zero) {
      constraints.add('Target never reaches the configured minimum altitude.');
    }
    if (usableUs == 0 && constraints.isEmpty) {
      constraints.add(
        'Altitude visibility does not overlap astronomical darkness.',
      );
    }
    if (constraints.isNotEmpty) score = 0;
    if (weatherCoverage == 0 && weights.weather > 0) {
      score = math.min(score, profile.maximumScoreWithoutWeather);
      constraints.add(
        'Incomplete weather: score capped at '
        '${profile.maximumScoreWithoutWeather.toStringAsFixed(0)}/100.',
      );
    }

    final dataCoverage = results.values.fold<double>(
      0,
      (sum, factor) => sum + factor.weight * factor.dataCoverage,
    );
    final provisional = results.values.any(
      (factor) =>
          factor.weight > 0 && factor.status != SuitabilityDataStatus.complete,
    );
    return TargetSuitabilityScore(
      targetId: target.id,
      startUtc: startUtc,
      endUtc: endUtc,
      score: _bounded(score),
      dataCoverage: _fraction(dataCoverage),
      isProvisional: provisional,
      visibleDuration: visibility.totalVisibleDuration,
      astronomicalDarkDuration: Duration(microseconds: darkUs),
      usableDuration: Duration(microseconds: usableUs),
      bestUsableAltitudeDegrees: bestAltitude,
      factors: results,
      constraints: constraints,
    );
  }

  /// A local, explainable lunar heuristic: Moon below horizon = 100; when
  /// above, risk grows with illumination and proximity (<= 10° worst,
  /// >= 90° negligible). No atmospheric scattering model is claimed.
  static double lunarQuality({
    required double moonAltitudeDegrees,
    required double illuminationFraction,
    required double targetSeparationDegrees,
  }) {
    if (!moonAltitudeDegrees.isFinite ||
        moonAltitudeDegrees < -90 ||
        moonAltitudeDegrees > 90 ||
        !illuminationFraction.isFinite ||
        illuminationFraction < 0 ||
        illuminationFraction > 1 ||
        !targetSeparationDegrees.isFinite ||
        targetSeparationDegrees < 0 ||
        targetSeparationDegrees > 180) {
      throw ArgumentError('Invalid lunar inputs.');
    }
    if (moonAltitudeDegrees <= 0) return 100;
    final proximity = _fraction((90 - targetSeparationDegrees) / 80);
    return _bounded(100 * (1 - illuminationFraction * proximity));
  }

  static int _minutes(Duration duration) => duration.inMinutes;

  static _WeatherQuality _weatherQuality(HourlyWeatherForecast hour) {
    var score = 0.0;
    var coverage = 0.0;
    void include(
      WeatherValue<double> field,
      double weight,
      double Function(double) grade,
    ) {
      final value = field.valueOrNull;
      if (value != null && value.isFinite) {
        score += weight * _bounded(grade(value));
        coverage += weight;
      }
    }

    include(hour.totalCloudCoverPercent, 0.38, (v) => 100 - v);
    include(hour.lowCloudCoverPercent, 0.08, (v) => 100 - v);
    include(hour.midCloudCoverPercent, 0.08, (v) => 100 - v);
    include(hour.highCloudCoverPercent, 0.06, (v) => 100 - v);
    include(hour.precipitationMillimeters, 0.12, (v) => 100 * (1 - v / 1.5));
    include(hour.precipitationProbabilityPercent, 0.12, (v) => 100 - v);
    include(hour.windSpeedMetersPerSecond, 0.06, (v) => 100 * (12 - v) / 9);
    include(hour.windGustMetersPerSecond, 0.04, (v) => 100 * (16 - v) / 11);
    include(hour.relativeHumidityPercent, 0.03, (v) => 100 * (95 - v) / 35);
    include(hour.visibilityMeters, 0.03, (v) => 100 * (v - 1000) / 19000);
    return _WeatherQuality(_bounded(score), _fraction(coverage));
  }

  static _OpticalQuality _opticalQuality({
    required CelestialObject target,
    required OpticalMetrics? optics,
  }) {
    if (optics == null) {
      return const _OpticalQuality(null, 0, 'No optical profile supplied.');
    }
    final major = target.majorAxisArcmin;
    final minor = target.minorAxisArcmin;
    if (major == null && minor == null) {
      return const _OpticalQuality(
        null,
        0,
        'Target has no catalog angular size.',
      );
    }
    final fields = [optics.horizontalFovDegrees, optics.verticalFovDegrees];
    if (fields.any((value) => !value.isFinite || value <= 0)) {
      throw ArgumentError('Optical field-of-view dimensions must be positive.');
    }
    // Missing second axis is treated as a square only for a provisional score.
    final width = (major ?? minor!) / 60.0;
    final height = (minor ?? major!) / 60.0;
    final upright = math.max(width / fields[0], height / fields[1]);
    final rotated = math.max(width / fields[1], height / fields[0]);
    final frameFraction = math.min(upright, rotated);
    final quality = frameFraction > 1
        ? 0.0
        : frameFraction >= 0.25
        ? 100.0
        : frameFraction >= 0.1
        ? 40 + 60 * (frameFraction - 0.1) / 0.15
        : 20.0;
    final fullSize = major != null && minor != null;
    return _OpticalQuality(
      fullSize ? quality : quality * 0.5,
      fullSize ? 1 : 0.5,
      frameFraction > 1
          ? 'Target exceeds the sensor field of view at this focal length.'
          : 'Object fills roughly ${(100 * frameFraction).toStringAsFixed(1)}% '
                'of the limiting frame axis (90° rotations allowed). '
                '${fullSize ? 'Both catalog axes are known.' : 'One axis is unknown; provisional size estimate.'}',
    );
  }
}

final class _WeatherQuality {
  const _WeatherQuality(this.score, this.coverage);
  final double score;
  final double coverage;
}

final class _OpticalQuality {
  const _OpticalQuality(this.score, this.coverage, this.explanation);
  final double? score;
  final double coverage;
  final String explanation;
}
