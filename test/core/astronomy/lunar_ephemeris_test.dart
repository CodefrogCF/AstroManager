import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/core/astronomy/lunar_ephemeris.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';

const _zurichObserver = ObserverPosition(
  latitudeDegrees: 47.3769,
  longitudeDegrees: 8.5417,
  elevationMeters: 408,
);

const _zurichLocation = ObservingLocationForTest.zurich;

/// Avoid a fake repository: all calculations operate on immutable location
/// models and UTC instants.
abstract final class ObservingLocationForTest {
  static const zurich = ObservingLocation(
    id: 'zurich',
    name: 'Zurich',
    latitude: 47.3769,
    longitude: 8.5417,
    elevationMeters: 408,
    timeZone: 'Europe/Zurich',
    isDefault: true,
  );

  static const northPole = ObservingLocation(
    id: 'north-pole',
    name: 'North Pole',
    latitude: 90,
    longitude: 0,
    elevationMeters: 0,
    timeZone: 'Etc/UTC',
    isDefault: false,
  );
}

void main() {
  group('Meeus reference lunar ephemeris', () {
    test('1992-04-12 ecliptic coordinates and distance match Table 47.A/B', () {
      // Meeus, Astronomical Algorithms, second edition, example 47.a.
      // 1992-04-12 00:00 TT; the engine approximates TT with UTC.
      final moon = LunarEphemeris.positionAt(
        at: DateTime.utc(1992, 4, 12),
        observer: _zurichObserver,
      );

      expect(moon.eclipticLongitudeDegrees, closeTo(133.162655, 0.03));
      expect(moon.eclipticLatitudeDegrees, closeTo(-3.229126, 0.03));
      expect(moon.distanceKilometers, closeTo(368409.7, 100));
    });

    test(
      'coordinates are valid and observer altitude/azimuth are physical',
      () {
        final moon = LunarEphemeris.positionAt(
          at: DateTime.utc(2026, 11, 1, 12),
          observer: _zurichObserver,
        );

        expect(moon.geocentricEquatorial.raDegrees, inInclusiveRange(0, 360));
        expect(moon.geocentricEquatorial.decDegrees, inInclusiveRange(-90, 90));
        expect(moon.horizontal.altitudeDegrees, inInclusiveRange(-90, 90));
        expect(moon.horizontal.azimuthDegrees!, inInclusiveRange(0, 360));
        expect(moon.distanceKilometers, inInclusiveRange(350000, 410000));
        expect(moon.illuminationFraction, inInclusiveRange(0, 1));
      },
    );

    test('Moon is topocentrically displaced by parallax', () {
      final moon = LunarEphemeris.positionAt(
        at: DateTime.utc(2026, 11, 1, 12),
        observer: _zurichObserver,
      );
      final separation = AstronomicalCoordinates.angularSeparationDegrees(
        moon.geocentricEquatorial,
        moon.topocentricEquatorial,
      );
      expect(separation, greaterThan(0.1));
      expect(separation, lessThan(1.1));
    });

    test('local DateTime and UTC instant give identical positions', () {
      final instant = DateTime.utc(2026, 10, 25, 1, 45);
      final a = LunarEphemeris.positionAt(
        at: instant,
        observer: _zurichObserver,
      );
      final b = LunarEphemeris.positionAt(
        at: instant.toLocal(),
        observer: _zurichObserver,
      );
      expect(a.distanceKilometers, b.distanceKilometers);
      expect(a.horizontal.altitudeDegrees, b.horizontal.altitudeDegrees);
    });
  });

  group('Lunar illumination and phases', () {
    test('2026-11-09 new Moon is less than 1% illuminated', () {
      // Published new moon: 2026-11-09 08:02 CET = 07:02 UTC.
      final moon = LunarEphemeris.positionAt(
        at: DateTime.utc(2026, 11, 9, 7, 2),
        observer: _zurichObserver,
      );
      expect(moon.illuminationFraction, lessThan(0.01));
      expect(moon.phase, LunarPhase.newMoon);
    });

    test('2026-11-24 full Moon is more than 99% illuminated', () {
      // Published full moon: 2026-11-24 15:53 CET = 14:53 UTC.
      final moon = LunarEphemeris.positionAt(
        at: DateTime.utc(2026, 11, 24, 14, 53),
        observer: _zurichObserver,
      );
      expect(moon.illuminationFraction, greaterThan(0.99));
      expect(moon.phase, LunarPhase.fullMoon);
    });

    test('2026-11-01 is approximately last quarter', () {
      final moon = LunarEphemeris.positionAt(
        at: DateTime.utc(2026, 11, 1, 20, 28),
        observer: _zurichObserver,
      );
      expect(moon.phase, LunarPhase.lastQuarter);
      expect(moon.illuminationFraction, closeTo(0.5, 0.02));
    });
  });

  group('Topocentric target separation', () {
    test('catalog target aligned with Moon at J2000 has zero separation', () {
      final at = DateTime.utc(2000, 1, 1, 12);
      final moon = LunarEphemeris.positionAt(at: at, observer: _zurichObserver);
      final result = LunarEphemeris.conditionsForTarget(
        at: at,
        observer: _zurichObserver,
        targetJ2000: moon.topocentricEquatorial,
      );
      expect(result.targetSeparationDegrees, closeTo(0, 1e-7));
    });

    test('a target opposite Moon at J2000 has 180 degree separation', () {
      final at = DateTime.utc(2000, 1, 1, 12);
      final moon = LunarEphemeris.positionAt(at: at, observer: _zurichObserver);
      final result = LunarEphemeris.conditionsForTarget(
        at: at,
        observer: _zurichObserver,
        targetJ2000: EquatorialPosition(
          raDegrees: AstronomicalCoordinates.normalizeDegrees(
            moon.topocentricEquatorial.raDegrees + 180,
          ),
          decDegrees: -moon.topocentricEquatorial.decDegrees,
        ),
      );
      expect(result.targetSeparationDegrees, closeTo(180, 1e-5));
    });

    test('precessed catalog target separation is within 0-180 degrees', () {
      final result = LunarEphemeris.conditionsForTarget(
        at: DateTime.utc(2026, 11, 1),
        observer: _zurichObserver,
        targetJ2000: const EquatorialPosition(
          raDegrees: 10.6848,
          decDegrees: 41.2691,
        ),
      );
      expect(result.targetSeparationDegrees, inInclusiveRange(0, 180));
    });
  });

  group('Rise/set and boundary conditions', () {
    test('Zurich 2026-11-03 rise/set follow published reference times', () {
      // timeanddate.com: 03 Nov rise 00:26 CET, set 14:36 CET.
      // Reference tolerances are deliberately 20 min (geometric horizon,
      // standard pressure and refractive assumptions vary).
      final day = LunarEphemeris.calculateForLocalDate(
        location: _zurichLocation,
        localDate: DateTime.utc(2026, 11, 3),
      );
      expect(day.state, LunarCrossingState.crossings);
      expect(day.moonrise, isNotNull);
      expect(day.moonset, isNotNull);
      expect(
        day.moonrise!.utc.difference(DateTime.utc(2026, 11, 2, 23, 26)).abs(),
        lessThan(const Duration(minutes: 20)),
      );
      expect(
        day.moonset!.utc.difference(DateTime.utc(2026, 11, 3, 13, 36)).abs(),
        lessThan(const Duration(minutes: 20)),
      );
      expect(day.moonrise!.local.timeZoneOffset, const Duration(hours: 1));
    });

    test('local day may have a set but no rise', () {
      final day = LunarEphemeris.calculateForLocalDate(
        location: _zurichLocation,
        localDate: DateTime.utc(2026, 11, 2),
      );
      expect(day.moonrise, isNull);
      expect(day.moonset, isNotNull);
      expect(day.events.length, 1);
    });

    test('north pole can have no event when always above horizon', () {
      final day = LunarEphemeris.calculateForLocalDate(
        location: ObservingLocationForTest.northPole,
        localDate: DateTime.utc(2026, 11, 1),
      );
      expect(day.events, isEmpty);
      expect(day.state, LunarCrossingState.alwaysAbove);
    });

    test('north pole can have no event when always below horizon', () {
      final day = LunarEphemeris.calculateForLocalDate(
        location: ObservingLocationForTest.northPole,
        localDate: DateTime.utc(2026, 11, 14),
      );
      expect(day.events, isEmpty);
      expect(day.state, LunarCrossingState.alwaysBelow);
    });

    test('observing night spans midnight, not split into two days', () {
      final night = LunarEphemeris.calculateForObservingNight(
        location: _zurichLocation,
        localDate: DateTime.utc(2026, 11, 2),
      );
      expect(
        night.endUtc.difference(night.startUtc),
        const Duration(hours: 24),
      );
      expect(night.moonrise, isNotNull);
      expect(night.moonrise!.local.day, 3);
      expect(night.moonrise!.local.hour, 0);
    });

    test(
      'civil day and night correctly span DST fall-back and spring-forward',
      () {
        final fall = LunarEphemeris.calculateForLocalDate(
          location: _zurichLocation,
          localDate: DateTime.utc(2026, 10, 25),
        );
        final spring = LunarEphemeris.calculateForLocalDate(
          location: _zurichLocation,
          localDate: DateTime.utc(2026, 3, 29),
        );
        expect(
          fall.endUtc.difference(fall.startUtc),
          const Duration(hours: 25),
        );
        expect(
          spring.endUtc.difference(spring.startUtc),
          const Duration(hours: 23),
        );
      },
    );
  });
}
