import '../../features/locations/domain/models/observing_location.dart';
import 'astronomical_coordinates.dart';
import 'solar_events.dart';

/// A half-open UTC interval [startUtc, endUtc). Both boundaries are absolute
/// instants, so intervals crossing midnight or daylight-saving changes work.
final class VisibilityInterval {
  VisibilityInterval({required DateTime startUtc, required DateTime endUtc})
    : startUtc = startUtc.toUtc(),
      endUtc = endUtc.toUtc() {
    if (!this.endUtc.isAfter(this.startUtc)) {
      throw ArgumentError('Visibility interval end must follow its start.');
    }
  }

  final DateTime startUtc;
  final DateTime endUtc;

  Duration get duration => endUtc.difference(startUtc);
}

/// A position evaluated at one instant in the requested period.
final class VisibilitySample {
  const VisibilitySample({required this.utc, required this.horizontal});

  final DateTime utc;
  final HorizontalPosition horizontal;
}

/// An upper meridian transit (hour angle = 0) inside the requested period.
final class TargetCulmination {
  const TargetCulmination({required this.utc, required this.horizontal});

  final DateTime utc;
  final HorizontalPosition horizontal;
}

enum TargetVisibilityState {
  /// The target stays at/above the configured altitude in every allowed span.
  continuouslyVisible,

  /// At least one but not every allowed instant exceeds the altitude limit.
  partiallyVisible,

  /// No time in the allowed spans meets the minimum altitude, or there is no
  /// astronomical darkness when filtering by darkness.
  notVisible,
}

/// Reusable result for catalog discovery, scoring and the night planner.
///
/// [periodStartUtc] and [periodEndUtc] describe the full requested window.
/// [allowedIntervals] restrict the usable portions (e.g. Sun below -18°).
/// [visibleIntervals] is the intersection with the altitude constraint.
/// [culminations] and [samples] describe the *full* requested period, even
/// if no astronomical darkness is available.
final class TargetVisibilityResult {
  TargetVisibilityResult({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.minimumAltitudeDegrees,
    required this.state,
    required List<VisibilityInterval> allowedIntervals,
    required List<VisibilityInterval> visibleIntervals,
    required List<VisibilitySample> samples,
    required List<TargetCulmination> culminations,
    required this.maximumPeriodSample,
    required this.bestVisiblePosition,
  }) : allowedIntervals = List.unmodifiable(allowedIntervals),
       visibleIntervals = List.unmodifiable(visibleIntervals),
       samples = List.unmodifiable(samples),
       culminations = List.unmodifiable(culminations);

  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final double minimumAltitudeDegrees;
  final TargetVisibilityState state;
  final List<VisibilityInterval> allowedIntervals;
  final List<VisibilityInterval> visibleIntervals;
  final List<VisibilitySample> samples;
  final List<TargetCulmination> culminations;

  /// Highest target position throughout the full observation period, even
  /// outside darkness or below the requested minimum altitude.
  final VisibilitySample maximumPeriodSample;

  /// Highest qualifying position within an allowed/visible interval.
  /// Null when there is no valid visibility window.
  final VisibilitySample? bestVisiblePosition;

  DateTime? get bestTimeUtc => bestVisiblePosition?.utc;
  double? get bestAltitudeDegrees =>
      bestVisiblePosition?.horizontal.altitudeDegrees;
  double? get bestAzimuthDegrees =>
      bestVisiblePosition?.horizontal.azimuthDegrees;

  bool get isContinuouslyVisible =>
      state == TargetVisibilityState.continuouslyVisible;
  bool get isNeverVisible => state == TargetVisibilityState.notVisible;

  Duration get totalVisibleDuration => visibleIntervals.fold(
    Duration.zero,
    (sum, interval) => sum + interval.duration,
  );

  Duration get totalAllowedDuration => allowedIntervals.fold(
    Duration.zero,
    (sum, interval) => sum + interval.duration,
  );

  double get visibleFraction {
    final allowed = totalAllowedDuration.inMicroseconds;
    if (allowed == 0) return 0;
    return totalVisibleDuration.inMicroseconds / allowed;
  }
}

/// Deterministic visibility calculations for catalog objects with J2000 RA/Dec.
///
/// Altitudes are geometric, referenced to an unobstructed horizon. The same
/// IAU-1976 precession and mean sidereal time used elsewhere in AstroManager
/// are applied. No terrain mask, refraction, weather or artificial light is
/// modeled. Sampling identifies candidate transitions, which are then refined
/// by bisection (about one second). A short, isolated crossing entirely
/// between two samples may be missed: use a smaller [sampleStep] if needed.
abstract final class TargetVisibility {
  static const Duration defaultSampleStep = Duration(minutes: 5);
  static const Duration _precision = Duration(seconds: 1);
  static const Duration _culminationPrecision = Duration(milliseconds: 100);

  /// Custom absolute observation period. [allowedIntervals] is optional: if
  /// omitted the entire period is usable; if empty there is no usable time.
  /// Overlapping or adjacent spans are merged and clipped to the period.
  static TargetVisibilityResult calculate({
    required EquatorialPosition targetJ2000,
    required ObserverPosition observer,
    required DateTime startUtc,
    required DateTime endUtc,
    double minimumAltitudeDegrees = 30,
    Duration sampleStep = defaultSampleStep,
    List<VisibilityInterval>? allowedIntervals,
  }) {
    targetJ2000.validate();
    observer.validate();
    if (!minimumAltitudeDegrees.isFinite ||
        minimumAltitudeDegrees < -90 ||
        minimumAltitudeDegrees > 90) {
      throw ArgumentError.value(
        minimumAltitudeDegrees,
        'minimumAltitudeDegrees',
        'Expected an angle between -90 and 90 degrees.',
      );
    }
    if (sampleStep < const Duration(minutes: 1) ||
        sampleStep > const Duration(hours: 1)) {
      throw ArgumentError.value(
        sampleStep,
        'sampleStep',
        'Expected 1 minute to 1 hour.',
      );
    }

    final start = startUtc.toUtc();
    final end = endUtc.toUtc();
    if (!end.isAfter(start) ||
        end.difference(start) > const Duration(days: 31)) {
      throw ArgumentError('Observation period must be > 0 and <= 31 days.');
    }

    HorizontalPosition horizontal(DateTime utc) =>
        AstronomicalCoordinates.calculateJ2000(
          j2000: targetJ2000,
          observer: observer,
          time: utc,
        ).horizontal;
    double altitude(DateTime utc) => horizontal(utc).altitudeDegrees;

    final allowed = _allowed(start, end, allowedIntervals);
    final samples = <VisibilitySample>[];
    final culminations = <TargetCulmination>[];

    var previousUtc = start;
    final initialHorizontal = horizontal(start);
    var previousHourAngle = _hourAngle(targetJ2000, observer, start);
    samples.add(VisibilitySample(utc: start, horizontal: initialHorizontal));

    var maximum = samples.first;
    while (previousUtc.isBefore(end)) {
      final next = _next(previousUtc, sampleStep, end);
      final current = horizontal(next);
      final currentSample = VisibilitySample(utc: next, horizontal: current);
      samples.add(currentSample);
      if (current.altitudeDegrees > maximum.horizontal.altitudeDegrees) {
        maximum = currentSample;
      }

      final currentHourAngle = _hourAngle(targetJ2000, observer, next);
      // Exclude the signed-hour-angle discontinuity at +/-180 degrees.
      if (previousHourAngle <= 0 &&
          currentHourAngle >= 0 &&
          currentHourAngle - previousHourAngle < 90) {
        final transit = _bisectHourAngle(
          previousUtc,
          next,
          targetJ2000,
          observer,
        );
        if (culminations.isEmpty ||
            transit.difference(culminations.last.utc).abs() >
                const Duration(minutes: 1)) {
          culminations.add(
            TargetCulmination(utc: transit, horizontal: horizontal(transit)),
          );
        }
      }

      previousUtc = next;
      previousHourAngle = currentHourAngle;
    }

    // Refine the maximum even when the meridian transit falls between samples.
    final periodPeak = _bestInRange(start, end, sampleStep, horizontal);
    if (periodPeak.horizontal.altitudeDegrees >
        maximum.horizontal.altitudeDegrees) {
      maximum = periodPeak;
    }

    final visible = <VisibilityInterval>[];
    for (final span in allowed) {
      DateTime? open = altitude(span.startUtc) >= minimumAltitudeDegrees
          ? span.startUtc
          : null;
      var left = span.startUtc;
      var leftAltitude = altitude(left);
      while (left.isBefore(span.endUtc)) {
        final right = _next(left, sampleStep, span.endUtc);
        final rightAltitude = altitude(right);
        final leftVisible = leftAltitude >= minimumAltitudeDegrees;
        final rightVisible = rightAltitude >= minimumAltitudeDegrees;

        if (leftVisible != rightVisible) {
          final crossing = _bisectAltitude(
            left,
            right,
            minimumAltitudeDegrees,
            altitude,
            leftVisible,
          );
          if (leftVisible) {
            if (open != null && crossing.isAfter(open)) {
              visible.add(VisibilityInterval(startUtc: open, endUtc: crossing));
            }
            open = null;
          } else {
            open = crossing;
          }
        }
        left = right;
        leftAltitude = rightAltitude;
      }
      if (open != null && span.endUtc.isAfter(open)) {
        visible.add(VisibilityInterval(startUtc: open, endUtc: span.endUtc));
      }
    }

    VisibilitySample? best;
    for (final span in visible) {
      final candidate = _bestInRange(
        span.startUtc,
        span.endUtc,
        sampleStep,
        horizontal,
      );
      if (best == null ||
          candidate.horizontal.altitudeDegrees >
              best.horizontal.altitudeDegrees) {
        best = candidate;
      }
    }

    final permittedUs = allowed.fold<int>(
      0,
      (total, interval) => total + interval.duration.inMicroseconds,
    );
    final visibleUs = visible.fold<int>(
      0,
      (total, interval) => total + interval.duration.inMicroseconds,
    );
    // A one-second difference at a numerical crossing is not a genuine
    // absence of continuous visibility. Ignore sub-second rounding in status.
    final state = visibleUs == 0
        ? TargetVisibilityState.notVisible
        : (permittedUs - visibleUs).abs() <=
              allowed.length * _precision.inMicroseconds
        ? TargetVisibilityState.continuouslyVisible
        : TargetVisibilityState.partiallyVisible;

    return TargetVisibilityResult(
      periodStartUtc: start,
      periodEndUtc: end,
      minimumAltitudeDegrees: minimumAltitudeDegrees,
      state: state,
      allowedIntervals: allowed,
      visibleIntervals: visible,
      samples: samples,
      culminations: culminations,
      maximumPeriodSample: maximum,
      bestVisiblePosition: best,
    );
  }

  /// Observe on the local-date night from noon to next noon, optionally
  /// restricting visibility to intervals with Sun altitude strictly < -18°.
  /// UTC boundaries come from [SolarEvents], preserving DST transitions.
  static TargetVisibilityResult forObservingNight({
    required EquatorialPosition targetJ2000,
    required ObservingLocation location,
    required DateTime localDate,
    double minimumAltitudeDegrees = 30,
    bool requireAstronomicalDarkness = true,
    Duration sampleStep = defaultSampleStep,
  }) {
    location.validate();
    final solar = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: localDate,
    );
    return calculate(
      targetJ2000: targetJ2000,
      observer: ObserverPosition(
        latitudeDegrees: location.latitude,
        longitudeDegrees: location.longitude,
        elevationMeters: location.elevationMeters,
      ),
      startUtc: solar.nightStartUtc,
      endUtc: solar.nightEndUtc,
      minimumAltitudeDegrees: minimumAltitudeDegrees,
      sampleStep: sampleStep,
      allowedIntervals: requireAstronomicalDarkness
          ? [
              for (final dark in solar.astronomicalDarkness)
                VisibilityInterval(
                  startUtc: dark.startUtc,
                  endUtc: dark.endUtc,
                ),
            ]
          : null,
    );
  }

  static List<VisibilityInterval> _allowed(
    DateTime start,
    DateTime end,
    List<VisibilityInterval>? requested,
  ) {
    if (requested == null) {
      return [VisibilityInterval(startUtc: start, endUtc: end)];
    }
    final clipped = <VisibilityInterval>[];
    for (final interval in requested) {
      final a = interval.startUtc.isBefore(start) ? start : interval.startUtc;
      final b = interval.endUtc.isAfter(end) ? end : interval.endUtc;
      if (b.isAfter(a)) {
        clipped.add(VisibilityInterval(startUtc: a, endUtc: b));
      }
    }
    clipped.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final merged = <VisibilityInterval>[];
    for (final span in clipped) {
      if (merged.isNotEmpty && !span.startUtc.isAfter(merged.last.endUtc)) {
        final prior = merged.removeLast();
        merged.add(
          VisibilityInterval(
            startUtc: prior.startUtc,
            endUtc: span.endUtc.isAfter(prior.endUtc)
                ? span.endUtc
                : prior.endUtc,
          ),
        );
      } else {
        merged.add(span);
      }
    }
    return merged;
  }

  static DateTime _next(DateTime from, Duration step, DateTime end) {
    final proposed = from.add(step);
    return proposed.isAfter(end) ? end : proposed;
  }

  static double _hourAngle(
    EquatorialPosition j2000,
    ObserverPosition observer,
    DateTime utc,
  ) {
    final equatorial = AstronomicalCoordinates.precessJ2000ToDate(
      j2000: j2000,
      time: utc,
    );
    return AstronomicalCoordinates.hourAngleDegrees(
      localSiderealDegrees: AstronomicalCoordinates.localMeanSiderealDegrees(
        utc,
        observer.longitudeDegrees,
      ),
      rightAscensionDegrees: equatorial.raDegrees,
    );
  }

  static DateTime _bisectHourAngle(
    DateTime left,
    DateTime right,
    EquatorialPosition j2000,
    ObserverPosition observer,
  ) {
    var a = left;
    var b = right;

    // Refine meridian transit to 100 milliseconds.
    // This keeps the angular error caused by time
    // resolution well below 0.001 degrees.
    while (b.difference(a) > _culminationPrecision) {
      final mid = _midpoint(a, b);

      if (_hourAngle(j2000, observer, mid) < 0) {
        a = mid;
      } else {
        b = mid;
      }
    }

    return _midpoint(a, b);
  }

  static DateTime _bisectAltitude(
    DateTime left,
    DateTime right,
    double threshold,
    double Function(DateTime) altitude,
    bool initiallyVisible,
  ) {
    var a = left;
    var b = right;
    while (b.difference(a) > _precision) {
      final mid = _midpoint(a, b);
      final visible = altitude(mid) >= threshold;
      if (visible == initiallyVisible) {
        a = mid;
      } else {
        b = mid;
      }
    }
    return _midpoint(a, b);
  }

  static DateTime _midpoint(DateTime a, DateTime b) =>
      DateTime.fromMicrosecondsSinceEpoch(
        (a.microsecondsSinceEpoch + b.microsecondsSinceEpoch) ~/ 2,
        isUtc: true,
      );

  /// Search a sampled interval and refine its best sample with a bounded
  /// golden-section search. The endpoints are also eligible maxima.
  static VisibilitySample _bestInRange(
    DateTime start,
    DateTime end,
    Duration step,
    HorizontalPosition Function(DateTime) horizontal,
  ) {
    var best = VisibilitySample(utc: start, horizontal: horizontal(start));
    var at = start;
    while (at.isBefore(end)) {
      at = _next(at, step, end);
      final sample = VisibilitySample(utc: at, horizontal: horizontal(at));
      if (sample.horizontal.altitudeDegrees > best.horizontal.altitudeDegrees) {
        best = sample;
      }
    }

    final left = best.utc.subtract(step).isBefore(start)
        ? start
        : best.utc.subtract(step);
    final right = best.utc.add(step).isAfter(end) ? end : best.utc.add(step);
    if (right.difference(left) <= _precision) return best;

    var a = left.microsecondsSinceEpoch.toDouble();
    var b = right.microsecondsSinceEpoch.toDouble();
    const fraction = 0.3819660112501051;
    DateTime instant(double us) =>
        DateTime.fromMicrosecondsSinceEpoch(us.round(), isUtc: true);
    var c = a + fraction * (b - a);
    var d = b - fraction * (b - a);
    var fc = horizontal(instant(c)).altitudeDegrees;
    var fd = horizontal(instant(d)).altitudeDegrees;
    for (var i = 0; i < 35 && b - a > 1000000; i++) {
      if (fc < fd) {
        a = c;
        c = d;
        fc = fd;
        d = b - fraction * (b - a);
        fd = horizontal(instant(d)).altitudeDegrees;
      } else {
        b = d;
        d = c;
        fd = fc;
        c = a + fraction * (b - a);
        fc = horizontal(instant(c)).altitudeDegrees;
      }
    }
    final peakUtc = instant((a + b) / 2);
    final peak = VisibilitySample(
      utc: peakUtc,
      horizontal: horizontal(peakUtc),
    );
    return peak.horizontal.altitudeDegrees > best.horizontal.altitudeDegrees
        ? peak
        : best;
  }
}
