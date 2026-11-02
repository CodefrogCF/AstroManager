import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/locations/domain/models/observing_location.dart';
import 'astronomical_coordinates.dart';

/// Standard geometric solar-center altitude thresholds.
///
/// Sunrise/sunset includes the conventional solar semidiameter and
/// atmospheric refraction at the horizon; the others are geometric.
enum SolarThreshold {
  horizon(-0.8333),
  civil(-6),
  nautical(-12),
  astronomical(-18);

  const SolarThreshold(this.altitudeDegrees);

  final double altitudeDegrees;
}

enum SolarCrossingState { normal, alwaysAbove, alwaysBelow }

/// A crossing of a specified solar altitude, with the local wall-clock time.
final class SolarEvent {
  const SolarEvent({
    required this.threshold,
    required this.isRising,
    required this.utc,
    required this.local,
  });

  final SolarThreshold threshold;
  final bool isRising;
  final DateTime utc;
  final tz.TZDateTime local;
}

/// Crossings within one local civil day (00:00 to the next 00:00).
final class SolarThresholdEvents {
  SolarThresholdEvents({
    required this.threshold,
    required this.state,
    required List<SolarEvent> crossings,
  }) : crossings = List.unmodifiable(crossings);

  final SolarThreshold threshold;
  final SolarCrossingState state;
  final List<SolarEvent> crossings;

  SolarEvent? get morning {
    for (final event in crossings) {
      if (event.isRising) return event;
    }
    return null;
  }

  SolarEvent? get evening {
    for (final event in crossings) {
      if (!event.isRising) return event;
    }
    return null;
  }
}

/// Contiguous interval in which the geometric solar-center altitude is < -18°.
/// The interval is clipped to the local-noon-to-next-local-noon night window.
final class AstronomicalDarknessInterval {
  const AstronomicalDarknessInterval({
    required this.startUtc,
    required this.endUtc,
    required this.startLocal,
    required this.endLocal,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final tz.TZDateTime startLocal;
  final tz.TZDateTime endLocal;

  Duration get duration => endUtc.difference(startUtc);
}

/// All threshold crossings on one local calendar date, plus darkness for
/// the observing night starting at local noon on that date.
final class SolarDayEvents {
  SolarDayEvents({
    required this.localDate,
    required this.timeZone,
    required this.dayStartUtc,
    required this.dayEndUtc,
    required this.nightStartUtc,
    required this.nightEndUtc,
    required Map<SolarThreshold, SolarThresholdEvents> thresholds,
    required List<AstronomicalDarknessInterval> astronomicalDarkness,
  }) : thresholds = Map.unmodifiable(thresholds),
       astronomicalDarkness = List.unmodifiable(astronomicalDarkness);

  final DateTime localDate;
  final String timeZone;
  final DateTime dayStartUtc;
  final DateTime dayEndUtc;
  final DateTime nightStartUtc;
  final DateTime nightEndUtc;
  final Map<SolarThreshold, SolarThresholdEvents> thresholds;
  final List<AstronomicalDarknessInterval> astronomicalDarkness;

  Duration get civilDayLength => dayEndUtc.difference(dayStartUtc);

  SolarThresholdEvents forThreshold(SolarThreshold threshold) =>
      thresholds[threshold]!;

  SolarEvent? get sunrise => forThreshold(SolarThreshold.horizon).morning;
  SolarEvent? get sunset => forThreshold(SolarThreshold.horizon).evening;
  SolarEvent? get civilDawn => forThreshold(SolarThreshold.civil).morning;
  SolarEvent? get civilDusk => forThreshold(SolarThreshold.civil).evening;
  SolarEvent? get nauticalDawn => forThreshold(SolarThreshold.nautical).morning;
  SolarEvent? get nauticalDusk => forThreshold(SolarThreshold.nautical).evening;
  SolarEvent? get astronomicalDawn =>
      forThreshold(SolarThreshold.astronomical).morning;
  SolarEvent? get astronomicalDusk =>
      forThreshold(SolarThreshold.astronomical).evening;
}

/// Offline solar ephemeris and local-date event calculations.
///
/// Meeus/NOAA-style solar longitude, obliquity and equatorial coordinates,
/// coupled to the shared mean sidereal-time calculation.
/// Accuracy is appropriate for planning, not precision telescope pointing.
abstract final class SolarEvents {
  static const double _degreesToRadians = math.pi / 180;
  static const double _radiansToDegrees = 180 / math.pi;
  static const Duration _samplingStep = Duration(minutes: 2);
  static bool _timeZonesInitialized = false;

  static double _sinDegrees(double degrees) =>
      math.sin(degrees * _degreesToRadians);

  static double _cosDegrees(double degrees) =>
      math.cos(degrees * _degreesToRadians);

  static tz.Location timeZone(String identifier) {
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    return tz.getLocation(identifier);
  }

  /// Approximate apparent geocentric equatorial Sun position at an instant.
  /// Do not apply the J2000 precession function to this result.
  static EquatorialPosition sunEquatorialPosition(DateTime at) {
    final jd = AstronomicalCoordinates.julianDate(at);
    final t = (jd - AstronomicalCoordinates.j2000JulianDate) / 36525.0;

    final meanLongitude = AstronomicalCoordinates.normalizeDegrees(
      280.46646 + t * (36000.76983 + 0.0003032 * t),
    );
    final meanAnomaly = AstronomicalCoordinates.normalizeDegrees(
      357.52911 + t * (35999.05029 - 0.0001537 * t),
    );
    final equationOfCenter =
        (1.914602 - t * (0.004817 + 0.000014 * t)) * _sinDegrees(meanAnomaly) +
        (0.019993 - 0.000101 * t) * _sinDegrees(2 * meanAnomaly) +
        0.000289 * _sinDegrees(3 * meanAnomaly);

    final omega = 125.04 - 1934.136 * t;
    final apparentLongitude = AstronomicalCoordinates.normalizeDegrees(
      meanLongitude + equationOfCenter - 0.00569 - 0.00478 * _sinDegrees(omega),
    );

    final obliquitySeconds =
        21.448 - t * (46.815 + t * (0.00059 - t * 0.001813));
    final meanObliquity = 23 + (26 + obliquitySeconds / 60) / 60;
    final obliquity = meanObliquity + 0.00256 * _cosDegrees(omega);

    final lambda = apparentLongitude * _degreesToRadians;
    final epsilon = obliquity * _degreesToRadians;
    final ra = math.atan2(
      math.cos(epsilon) * math.sin(lambda),
      math.cos(lambda),
    );
    final dec = math.asin(math.sin(epsilon) * math.sin(lambda));

    return EquatorialPosition(
      raDegrees: AstronomicalCoordinates.normalizeDegrees(
        ra * _radiansToDegrees,
      ),
      decDegrees: dec * _radiansToDegrees,
    );
  }

  /// Geometric altitude of the center of the Sun at an arbitrary instant.
  /// No terrain masking, refraction or solar disk correction is applied.
  static double sunAltitudeDegrees({
    required DateTime at,
    required double latitudeDegrees,
    required double longitudeDegrees,
  }) {
    final observer = ObserverPosition(
      latitudeDegrees: latitudeDegrees,
      longitudeDegrees: longitudeDegrees,
    );
    observer.validate();

    return AstronomicalCoordinates.equatorialToHorizontal(
      equatorialOfDate: sunEquatorialPosition(at),
      observer: observer,
      time: at,
    ).altitudeDegrees;
  }

  /// Calculate all solar events occurring on [localDate] in the given
  /// observing location's time zone. The date's year/month/day are interpreted
  /// as local calendar fields, regardless of the DateTime's own time zone.
  ///
  /// Darkness is computed for local noon on [localDate] through local noon
  /// on the following day, ensuring one night is kept together over midnight.
  static SolarDayEvents calculateForLocalDate({
    required ObservingLocation location,
    required DateTime localDate,
  }) {
    location.validate();
    final zone = timeZone(location.timeZone);
    final y = localDate.year;
    final m = localDate.month;
    final d = localDate.day;
    final dayStart = tz.TZDateTime(zone, y, m, d);
    final dayEnd = tz.TZDateTime(zone, y, m, d + 1);
    final nightStart = tz.TZDateTime(zone, y, m, d, 12);
    final nightEnd = tz.TZDateTime(zone, y, m, d + 1, 12);

    final dayThresholds = <SolarThreshold, SolarThresholdEvents>{};
    for (final threshold in SolarThreshold.values) {
      final scan = _scanThreshold(
        location: location,
        zone: zone,
        startUtc: dayStart.toUtc(),
        endUtc: dayEnd.toUtc(),
        threshold: threshold,
      );
      dayThresholds[threshold] = SolarThresholdEvents(
        threshold: threshold,
        state: scan.state,
        crossings: scan.events,
      );
    }

    final darknessScan = _scanThreshold(
      location: location,
      zone: zone,
      startUtc: nightStart.toUtc(),
      endUtc: nightEnd.toUtc(),
      threshold: SolarThreshold.astronomical,
    );
    final intervals = <AstronomicalDarknessInterval>[];
    DateTime? darkStart =
        sunAltitudeDegrees(
              at: nightStart.toUtc(),
              latitudeDegrees: location.latitude,
              longitudeDegrees: location.longitude,
            ) <
            SolarThreshold.astronomical.altitudeDegrees
        ? nightStart.toUtc()
        : null;

    for (final crossing in darknessScan.events) {
      if (crossing.isRising) {
        if (darkStart != null && crossing.utc.isAfter(darkStart)) {
          intervals.add(_darkInterval(darkStart, crossing.utc, zone));
        }
        darkStart = null;
      } else {
        darkStart = crossing.utc;
      }
    }
    if (darkStart != null && nightEnd.toUtc().isAfter(darkStart)) {
      intervals.add(_darkInterval(darkStart, nightEnd.toUtc(), zone));
    }

    return SolarDayEvents(
      localDate: DateTime.utc(y, m, d),
      timeZone: location.timeZone,
      dayStartUtc: dayStart.toUtc(),
      dayEndUtc: dayEnd.toUtc(),
      nightStartUtc: nightStart.toUtc(),
      nightEndUtc: nightEnd.toUtc(),
      thresholds: dayThresholds,
      astronomicalDarkness: intervals,
    );
  }

  static AstronomicalDarknessInterval _darkInterval(
    DateTime start,
    DateTime end,
    tz.Location zone,
  ) => AstronomicalDarknessInterval(
    startUtc: start,
    endUtc: end,
    startLocal: tz.TZDateTime.from(start, zone),
    endLocal: tz.TZDateTime.from(end, zone),
  );

  static _ThresholdScan _scanThreshold({
    required ObservingLocation location,
    required tz.Location zone,
    required DateTime startUtc,
    required DateTime endUtc,
    required SolarThreshold threshold,
  }) {
    double delta(DateTime at) =>
        sunAltitudeDegrees(
          at: at,
          latitudeDegrees: location.latitude,
          longitudeDegrees: location.longitude,
        ) -
        threshold.altitudeDegrees;

    final events = <SolarEvent>[];
    var left = startUtc;
    var leftValue = delta(left);
    final initialAbove = leftValue >= 0;

    while (left.isBefore(endUtc)) {
      final candidate = left.add(_samplingStep);
      final right = candidate.isBefore(endUtc) ? candidate : endUtc;
      final rightValue = delta(right);

      // Capture either a strict sign change or an exact threshold crossing.
      if ((leftValue < 0 && rightValue >= 0) ||
          (leftValue >= 0 && rightValue < 0)) {
        final rising = leftValue < 0;
        final utc = _refineCrossing(left, right, delta, rising);
        events.add(
          SolarEvent(
            threshold: threshold,
            isRising: rising,
            utc: utc,
            local: tz.TZDateTime.from(utc, zone),
          ),
        );
      }
      left = right;
      leftValue = rightValue;
    }

    return _ThresholdScan(
      events: events,
      state: events.isNotEmpty
          ? SolarCrossingState.normal
          : initialAbove
          ? SolarCrossingState.alwaysAbove
          : SolarCrossingState.alwaysBelow,
    );
  }

  /// Bisection to approximately 1 second, independent of timezone / DST.
  static DateTime _refineCrossing(
    DateTime a,
    DateTime b,
    double Function(DateTime) delta,
    bool rising,
  ) {
    var low = a.millisecondsSinceEpoch;
    var high = b.millisecondsSinceEpoch;
    while (high - low > 1000) {
      final middle = low + (high - low) ~/ 2;
      final value = delta(
        DateTime.fromMillisecondsSinceEpoch(middle, isUtc: true),
      );
      if ((value >= 0) == rising) {
        high = middle;
      } else {
        low = middle;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(
      low + (high - low) ~/ 2,
      isUtc: true,
    );
  }

  /// True if the geometric solar altitude is below -18° at [at].
  static bool isAstronomicallyDark({
    required DateTime at,
    required ObservingLocation location,
  }) =>
      sunAltitudeDegrees(
        at: at,
        latitudeDegrees: location.latitude,
        longitudeDegrees: location.longitude,
      ) <
      SolarThreshold.astronomical.altitudeDegrees;

  /// Local time with numeric UTC offset, including the local date when useful.
  /// Numeric offsets disambiguate repeated times on DST fall-back days.
  static String formatLocal(tz.TZDateTime value, {bool includeDate = false}) {
    String two(int number) => number.toString().padLeft(2, '0');
    final offsetMinutes = value.timeZoneOffset.inMinutes;
    final sign = offsetMinutes < 0 ? '-' : '+';
    final absoluteMinutes = offsetMinutes.abs();
    final offset =
        '$sign${two(absoluteMinutes ~/ 60)}:'
        '${two(absoluteMinutes % 60)}';
    final time = '${two(value.hour)}:${two(value.minute)}';
    final date = includeDate
        ? '${two(value.day)}.${two(value.month)}.${value.year} '
        : '';
    return '$date$time (UTC$offset)';
  }
}

final class _ThresholdScan {
  const _ThresholdScan({required this.events, required this.state});
  final List<SolarEvent> events;
  final SolarCrossingState state;
}
