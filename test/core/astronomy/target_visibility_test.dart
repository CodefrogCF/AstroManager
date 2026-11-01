import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/core/astronomy/target_visibility.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';

const _greenwich = ObserverPosition(latitudeDegrees: 0, longitudeDegrees: 0);
const _north = ObserverPosition(latitudeDegrees: 45, longitudeDegrees: 0);

const _zurich = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

void main() {
  // USNO/standard reference: GMST(J2000 noon) = 280.46061837 degrees.
  // At latitude 0 and declination 0, the altitude is 90° on the meridian.
  final epoch = DateTime.utc(2000, 1, 1, 12);
  const meridianTarget = EquatorialPosition(
    raDegrees: 280.46061837,
    decDegrees: 0,
  );

  group('Reference geometry and culmination', () {
    test('zenith transit at J2000 noon occurs at the right instant', () {
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: epoch.subtract(const Duration(hours: 4)),
        endUtc: epoch.add(const Duration(hours: 4)),
        minimumAltitudeDegrees: 0,
      );

      expect(result.culminations, hasLength(1));
      expect(
        result.culminations.single.utc.difference(epoch).abs(),
        lessThan(const Duration(seconds: 2)),
      );
      expect(
        result.culminations.single.horizontal.altitudeDegrees,
        closeTo(90, 0.001),
      );
      expect(result.bestAltitudeDegrees, closeTo(90, 0.001));
      expect(
        result.bestTimeUtc!.difference(epoch).abs(),
        lessThan(const Duration(seconds: 3)),
      );
    });

    test('long custom periods can contain multiple upper culminations', () {
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: epoch.subtract(const Duration(hours: 1)),
        endUtc: epoch.add(const Duration(hours: 26)),
        minimumAltitudeDegrees: 0,
      );

      expect(result.culminations, hasLength(2));
      // Earth rotation relative to the stars: one sidereal day is ~23h56m.
      final between = result.culminations[1].utc.difference(
        result.culminations[0].utc,
      );
      expect(between.inMinutes, closeTo(1436, 2));
    });

    test('meridian altitude is 90 minus absolute latitude-declination', () {
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _north,
        startUtc: epoch.subtract(const Duration(hours: 2)),
        endUtc: epoch.add(const Duration(hours: 2)),
        minimumAltitudeDegrees: 0,
      );

      expect(result.culminations, hasLength(1));
      expect(
        result.culminations.single.horizontal.altitudeDegrees,
        closeTo(45, 0.01),
      );
      expect(result.bestAltitudeDegrees, closeTo(45, 0.01));
    });

    test('30 degree altitude at equator gives about 8 sidereal hours', () {
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: DateTime.utc(2000, 1, 1, 8),
        endUtc: DateTime.utc(2000, 1, 1, 17),
        minimumAltitudeDegrees: 30,
      );

      // Independent spherical geometry: sin(h) = cos(H) at lat=dec=0.
      // h=30 => |H|=60 degrees. At 15.0410686 deg/hour, duration=7h58m41s.
      const predictedSeconds = 120 / (360.98564736629 / 86400);
      expect(result.visibleIntervals, hasLength(1));
      expect(
        result.totalVisibleDuration.inSeconds.toDouble(),
        closeTo(predictedSeconds, 120),
      );
      expect(result.state, TargetVisibilityState.partiallyVisible);
      expect(result.samples.first.utc, DateTime.utc(2000, 1, 1, 8));
      expect(result.samples.last.utc, DateTime.utc(2000, 1, 1, 17));
      expect(result.samples.first.horizontal.azimuthDegrees, isNotNull);
      expect(result.samples.last.horizontal.azimuthDegrees, isNotNull);
    });
  });

  group('Edge cases', () {
    test('circumpolar target stays visible above a 30 degree cutoff', () {
      final result = TargetVisibility.calculate(
        targetJ2000: const EquatorialPosition(raDegrees: 100, decDegrees: 89),
        observer: _north,
        startUtc: epoch,
        endUtc: epoch.add(const Duration(hours: 24)),
        minimumAltitudeDegrees: 30,
      );

      expect(result.state, TargetVisibilityState.continuouslyVisible);
      expect(result.visibleIntervals, hasLength(1));
      expect(result.totalVisibleDuration, const Duration(hours: 24));
      expect(result.bestTimeUtc, isNotNull);
    });

    test('southern polar target never rises above 0 at 45 north', () {
      final result = TargetVisibility.calculate(
        targetJ2000: const EquatorialPosition(raDegrees: 100, decDegrees: -89),
        observer: _north,
        startUtc: epoch,
        endUtc: epoch.add(const Duration(hours: 24)),
        minimumAltitudeDegrees: 0,
      );

      expect(result.state, TargetVisibilityState.notVisible);
      expect(result.visibleIntervals, isEmpty);
      expect(result.bestTimeUtc, isNull);
      expect(
        result.maximumPeriodSample.horizontal.altitudeDegrees,
        lessThan(0),
      );
    });

    test('custom window can be fully inside visibility', () {
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: epoch.subtract(const Duration(minutes: 15)),
        endUtc: epoch.add(const Duration(minutes: 15)),
        minimumAltitudeDegrees: 80,
      );
      expect(result.isContinuouslyVisible, isTrue);
      expect(result.totalVisibleDuration, const Duration(minutes: 30));
      expect(result.bestAltitudeDegrees, closeTo(90, 0.001));
    });

    test('allows multiple disjoint windows and merges overlaps', () {
      final start = epoch.subtract(const Duration(hours: 3));
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: start,
        endUtc: epoch.add(const Duration(hours: 3)),
        minimumAltitudeDegrees: 0,
        allowedIntervals: [
          VisibilityInterval(
            startUtc: start,
            endUtc: epoch.subtract(const Duration(hours: 1)),
          ),
          VisibilityInterval(
            startUtc: epoch.subtract(const Duration(hours: 2)),
            endUtc: epoch,
          ),
          VisibilityInterval(
            startUtc: epoch.add(const Duration(hours: 1)),
            endUtc: epoch.add(const Duration(hours: 2)),
          ),
        ],
      );
      expect(result.allowedIntervals, hasLength(2));
      expect(result.visibleIntervals, hasLength(2));
      expect(result.totalAllowedDuration, const Duration(hours: 4));
      expect(result.totalVisibleDuration, const Duration(hours: 4));
      expect(result.isContinuouslyVisible, isTrue);
    });

    test('empty allowed time is not observable', () {
      final result = TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: epoch,
        endUtc: epoch.add(const Duration(hours: 1)),
        allowedIntervals: [],
      );
      expect(result.allowedIntervals, isEmpty);
      expect(result.visibleIntervals, isEmpty);
      expect(result.bestTimeUtc, isNull);
      expect(result.isNeverVisible, isTrue);
    });

    test('rejects invalid period, step and altitude', () {
      TargetVisibilityResult run({
        DateTime? end,
        double limit = 30,
        Duration step = const Duration(minutes: 5),
      }) => TargetVisibility.calculate(
        targetJ2000: meridianTarget,
        observer: _greenwich,
        startUtc: epoch,
        endUtc: end ?? epoch.add(const Duration(hours: 1)),
        minimumAltitudeDegrees: limit,
        sampleStep: step,
      );
      expect(() => run(end: epoch), throwsArgumentError);
      expect(() => run(limit: 91), throwsArgumentError);
      expect(() => run(limit: double.nan), throwsArgumentError);
      expect(() => run(step: const Duration(seconds: 30)), throwsArgumentError);
    });
  });

  group('Local observing nights', () {
    const m31 = EquatorialPosition(raDegrees: 10.6848, decDegrees: 41.2691);

    test('M31 visibility uses dark hours and may cross midnight', () {
      final result = TargetVisibility.forObservingNight(
        targetJ2000: m31,
        location: _zurich,
        localDate: DateTime.utc(2026, 11, 1),
        minimumAltitudeDegrees: 30,
      );
      expect(result.totalAllowedDuration, greaterThan(Duration.zero));
      expect(result.totalVisibleDuration, greaterThan(Duration.zero));
      expect(result.visibleIntervals, isNotEmpty);
      expect(result.bestAltitudeDegrees!, greaterThan(30));
      expect(
        result.visibleIntervals.every(
          (span) =>
              !span.startUtc.isBefore(result.periodStartUtc) &&
              !span.endUtc.isAfter(result.periodEndUtc),
        ),
        isTrue,
      );
      // An actual observation interval can run from one civil date to the next.
      expect(
        result.allowedIntervals.any(
          (span) => span.startUtc.day != span.endUtc.day,
        ),
        isTrue,
      );
    });

    test('night boundaries follow time-zone transitions', () {
      final spring = TargetVisibility.forObservingNight(
        targetJ2000: m31,
        location: _zurich,
        localDate: DateTime.utc(2026, 3, 28),
      );
      final autumn = TargetVisibility.forObservingNight(
        targetJ2000: m31,
        location: _zurich,
        localDate: DateTime.utc(2026, 10, 24),
      );
      expect(
        spring.periodEndUtc.difference(spring.periodStartUtc),
        const Duration(hours: 23),
      );
      expect(
        autumn.periodEndUtc.difference(autumn.periodStartUtc),
        const Duration(hours: 25),
      );
    });

    test('polar summer with no astronomical darkness reports no windows', () {
      const tromso = ObservingLocation(
        id: 'tromso',
        name: 'Tromso',
        latitude: 69.6492,
        longitude: 18.9553,
        elevationMeters: 10,
        timeZone: 'Europe/Oslo',
        isDefault: true,
      );
      final result = TargetVisibility.forObservingNight(
        targetJ2000: m31,
        location: tromso,
        localDate: DateTime.utc(2026, 6, 21),
      );
      expect(result.allowedIntervals, isEmpty);
      expect(result.visibleIntervals, isEmpty);
      expect(result.bestTimeUtc, isNull);
    });

    test('identical inputs produce identical outputs', () {
      TargetVisibilityResult run() => TargetVisibility.forObservingNight(
        targetJ2000: m31,
        location: _zurich,
        localDate: DateTime.utc(2026, 11, 1),
      );
      final a = run();
      final b = run();
      expect(a.bestTimeUtc, b.bestTimeUtc);
      expect(a.bestAltitudeDegrees, b.bestAltitudeDegrees);
      expect(a.totalVisibleDuration, b.totalVisibleDuration);
    });
  });
}
