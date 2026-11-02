import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../../core/astronomy/target_visibility.dart';
import '../../terrain/domain/terrain_horizon.dart';
import '../../../features/locations/domain/models/observing_location.dart';

/// All geometry is based on UTC duration, not local clock arithmetic.
/// A spring-forward night and a fall-back night therefore have different widths.
final class NightTimeline {
  NightTimeline(this.day)
    : startUtc = day.nightStartUtc,
      endUtc = day.nightEndUtc;
  final SolarDayEvents day;
  final DateTime startUtc;
  final DateTime endUtc;

  Duration get duration => endUtc.difference(startUtc);

  double fraction(DateTime utc) =>
      (utc.toUtc().difference(startUtc).inMicroseconds /
              duration.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();

  double widthFraction(DateTime start, DateTime end) =>
      (fraction(end) - fraction(start)).clamp(0.0, 1.0).toDouble();

  bool contains(DateTime start, DateTime end) =>
      !start.toUtc().isBefore(startUtc) &&
      !end.toUtc().isAfter(endUtc) &&
      end.toUtc().isAfter(start.toUtc());

  List<VisibilityInterval> darknessIntervals() => [
    for (final dark in day.astronomicalDarkness)
      VisibilityInterval(startUtc: dark.startUtc, endUtc: dark.endUtc),
  ];

  /// Tick every N elapsed UTC hours, labelled using the observing site.
  /// Repeated wall-clock hours receive distinct UTC offsets at DST fallback.
  List<DateTime> ticks({int hours = 2}) {
    assert(hours > 0);
    final result = <DateTime>[];
    for (
      var instant = startUtc;
      !instant.isAfter(endUtc);
      instant = instant.add(Duration(hours: hours))
    ) {
      result.add(instant);
    }
    if (result.last != endUtc) {
      result.add(endUtc);
    }
    return result;
  }

  String clockLabel(DateTime utc) {
    final local = tz.TZDateTime.from(utc, SolarEvents.timeZone(day.timeZone));
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} UTC$sign'
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }
}

/// Use the project's existing offline astronomical visibility calculations.
abstract final class NightTargetVisibility {
  static TargetVisibilityResult calculate({
    required NightTimeline timeline,
    required ObservingLocation site,
    required double raDegrees,
    required double decDegrees,
    double minimumAltitudeDegrees = 30,
    TerrainHorizonProfile? terrainHorizon,
  }) => TargetVisibility.calculate(
    targetJ2000: EquatorialPosition(
      raDegrees: raDegrees,
      decDegrees: decDegrees,
    ),
    observer: ObserverPosition(
      latitudeDegrees: site.latitude,
      longitudeDegrees: site.longitude,
      elevationMeters: site.elevationMeters,
    ),
    startUtc: timeline.startUtc,
    endUtc: timeline.endUtc,
    minimumAltitudeDegrees: minimumAltitudeDegrees,
    terrainHorizon: terrainHorizon,
    allowedIntervals: timeline.darknessIntervals(),
  );
}

/// Resolve a selected site-local date/time without silently normalizing
/// nonexistent hours. A repeated fall-back hour returns both UTC instants.
abstract final class NightLocalClock {
  static List<DateTime> candidates({
    required String timeZoneId,
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) {
    final zone = SolarEvents.timeZone(timeZoneId);
    final normalized = tz.TZDateTime(
      zone,
      year,
      month,
      day,
      hour,
      minute,
    ).toUtc();
    final matches = <DateTime>{};
    // Cover uncommon 30/90/120-minute DST changes as well as ordinary 1h.
    for (var offset = -180; offset <= 180; offset += 15) {
      final instant = normalized.add(Duration(minutes: offset));
      final local = tz.TZDateTime.from(instant, zone);
      if (local.year == year &&
          local.month == month &&
          local.day == day &&
          local.hour == hour &&
          local.minute == minute) {
        matches.add(instant);
      }
    }
    return matches.toList()..sort();
  }
}
