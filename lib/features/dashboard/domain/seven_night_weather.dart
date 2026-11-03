import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../weather/domain/models/weather_forecast.dart';

/// A forecast hour describes [timeUtc, timeUtc + 1 hour). Only actual cloud
/// readings count as coverage; absent values and absent hours remain unknown.
final class SevenNightWeatherOptions {
  const SevenNightWeatherOptions({
    this.maximumCloudPercent = 30,
    this.minimumClearDuration = const Duration(hours: 2),
  });

  final int maximumCloudPercent;
  final Duration minimumClearDuration;

  void validate() {
    if (maximumCloudPercent < 0 ||
        maximumCloudPercent > 100 ||
        minimumClearDuration <= Duration.zero) {
      throw ArgumentError('Invalid seven-night weather settings.');
    }
  }
}

enum NightCloudTrend { improving, stable, worsening, unknown }

final class NightWeatherSummary {
  const NightWeatherSummary({
    required this.localDate,
    required this.darkness,
    required this.remainingDarkness,
    required this.forecastCoverage,
    required this.clearDuration,
    required this.longestClearInterval,
    required this.averageCloudPercent,
    required this.trend,
  });

  /// The local civil date on which this observing night starts at noon.
  final DateTime localDate;
  final Duration darkness;

  /// Future astronomical darkness, excluding already elapsed portions.
  final Duration remainingDarkness;
  final Duration forecastCoverage;

  /// Sum of fully observed, contiguous qualifying clear-sky intervals.
  final Duration clearDuration;
  final Duration longestClearInterval;
  final double? averageCloudPercent;
  final NightCloudTrend trend;

  bool get hasDarkness => darkness > Duration.zero;
  bool get hasForecast => forecastCoverage > Duration.zero;
  bool get isComplete =>
      remainingDarkness > Duration.zero &&
      forecastCoverage >= remainingDarkness;
  bool qualifies(SevenNightWeatherOptions options) =>
      clearDuration >= options.minimumClearDuration;
}

/// UTC-only interval intersection. No interpolation is ever performed.
abstract final class SevenNightWeatherAggregator {
  /// Generates the next seven observing nights at local noon, not seven UTC
  /// dates. Before local noon, the preceding evening is still "tonight".
  /// This also handles 23/25-hour civil days during DST transitions.
  static List<SolarDayEvents> upcomingNights({
    required ObservingLocation location,
    required DateTime nowUtc,
  }) {
    location.validate();
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc');
    }
    final zone = SolarEvents.timeZone(location.timeZone);
    final local = tz.TZDateTime.from(nowUtc, zone);
    var firstDay = local.day;
    if (local.hour < 12) {
      final previousDate = DateTime.utc(local.year, local.month, local.day - 1);
      final previousNight = SolarEvents.calculateForLocalDate(
        location: location,
        localDate: previousDate,
      );
      if (previousNight.astronomicalDarkness.any(
        (interval) =>
            interval.endUtc.isAfter(nowUtc) &&
            !interval.startUtc.isAfter(nowUtc),
      )) {
        firstDay -= 1;
      }
    }
    final firstDate = tz.TZDateTime(zone, local.year, local.month, firstDay);
    return List.generate(7, (index) {
      final date = tz.TZDateTime(
        zone,
        firstDate.year,
        firstDate.month,
        firstDate.day + index,
      );
      return SolarEvents.calculateForLocalDate(
        location: location,
        localDate: DateTime.utc(date.year, date.month, date.day),
      );
    });
  }

  static List<NightWeatherSummary> calculate({
    required List<SolarDayEvents> nights,
    required WeatherForecast forecast,
    required DateTime nowUtc,
    required SevenNightWeatherOptions options,
  }) {
    options.validate();
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc');
    }
    if (nights.length > 7) {
      throw ArgumentError('Maximum seven nights.');
    }
    forecast.validate();
    return [
      for (final night in nights)
        _summarize(night, forecast.hours, nowUtc, options),
    ];
  }

  static NightWeatherSummary _summarize(
    SolarDayEvents night,
    List<HourlyWeatherForecast> hours,
    DateTime nowUtc,
    SevenNightWeatherOptions options,
  ) {
    var darknessUs = 0;
    var remainingUs = 0;
    var coveredUs = 0;
    var clearUs = 0;
    var longestUs = 0;
    var weightedCloud = 0.0;
    var currentRunUs = 0;
    DateTime? runEnd;
    final segments = <_CloudSegment>[];

    void flush() {
      if (currentRunUs >= options.minimumClearDuration.inMicroseconds) {
        clearUs += currentRunUs;
      }
      longestUs = math.max(longestUs, currentRunUs);
      currentRunUs = 0;
      runEnd = null;
    }

    // Forecasts are sorted, distinct UTC hours by WeatherForecast.validate().
    for (final interval in night.astronomicalDarkness) {
      darknessUs += interval.duration.inMicroseconds;
      final start = _later(interval.startUtc, nowUtc);
      final end = interval.endUtc;
      if (!end.isAfter(start)) {
        continue;
      }
      remainingUs += end.difference(start).inMicroseconds;
      flush();
      for (final hour in hours) {
        final hourStart = hour.timeUtc;
        final hourEnd = hourStart.add(const Duration(hours: 1));
        if (!hourEnd.isAfter(start)) {
          continue;
        }
        if (!hourStart.isBefore(end)) {
          break;
        }
        final intersectStart = _later(start, hourStart);
        final intersectEnd = _earlier(end, hourEnd);
        if (!intersectEnd.isAfter(intersectStart)) {
          continue;
        }

        final cloud = hour.totalCloudCoverPercent.valueOrNull;
        // Explicitly missing cloud coverage breaks a run, just like a gap.
        if (cloud == null) {
          flush();
          continue;
        }
        final duration = intersectEnd.difference(intersectStart).inMicroseconds;
        coveredUs += duration;
        weightedCloud += cloud * duration;
        segments.add(_CloudSegment(intersectStart, intersectEnd, cloud));
        if (cloud <= options.maximumCloudPercent) {
          if (runEnd != null && runEnd != intersectStart) {
            flush();
          }
          currentRunUs += duration;
          runEnd = intersectEnd;
        } else {
          flush();
        }
      }
    }
    flush();

    return NightWeatherSummary(
      localDate: night.localDate,
      darkness: Duration(microseconds: darknessUs),
      remainingDarkness: Duration(microseconds: remainingUs),
      forecastCoverage: Duration(microseconds: coveredUs),
      clearDuration: Duration(microseconds: clearUs),
      longestClearInterval: Duration(microseconds: longestUs),
      averageCloudPercent: coveredUs == 0 ? null : weightedCloud / coveredUs,
      trend: _trend(segments),
    );
  }

  static NightCloudTrend _trend(List<_CloudSegment> segments) {
    if (segments.length < 2) {
      return NightCloudTrend.unknown;
    }
    final middleUs =
        segments.first.start.microsecondsSinceEpoch +
        (segments.last.end.difference(segments.first.start).inMicroseconds ~/
            2);
    var firstUs = 0;
    var lastUs = 0;
    var firstSum = 0.0;
    var lastSum = 0.0;
    for (final segment in segments) {
      final startUs = segment.start.microsecondsSinceEpoch;
      final endUs = segment.end.microsecondsSinceEpoch;
      final earlierUs = math.max(0, math.min(endUs, middleUs) - startUs);
      final laterStartUs = startUs > middleUs ? startUs : middleUs;
      final laterUs = endUs > laterStartUs ? endUs - laterStartUs : 0;
      firstUs += earlierUs;
      lastUs += laterUs;
      firstSum += earlierUs * segment.cloud;
      lastSum += laterUs * segment.cloud;
    }
    if (firstUs == 0 || lastUs == 0) {
      return NightCloudTrend.unknown;
    }
    final change = lastSum / lastUs - firstSum / firstUs;
    if (change <= -10) {
      return NightCloudTrend.improving;
    }
    if (change >= 10) {
      return NightCloudTrend.worsening;
    }
    return NightCloudTrend.stable;
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}

final class _CloudSegment {
  const _CloudSegment(this.start, this.end, this.cloud);
  final DateTime start;
  final DateTime end;
  final double cloud;
}
