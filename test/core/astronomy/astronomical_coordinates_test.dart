import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';

void main() {
  final j2000Time = DateTime.utc(2000, 1, 1, 12);

  group('Julian Date', () {
    test('J2000 epoch equals JD 2451545.0', () {
      expect(AstronomicalCoordinates.julianDate(j2000Time), 2451545.0);
    });

    test('Unix epoch equals JD 2440587.5', () {
      expect(
        AstronomicalCoordinates.julianDate(DateTime.utc(1970, 1, 1)),
        2440587.5,
      );
    });

    test('one day changes JD by exactly one', () {
      final first = DateTime.utc(2026, 11, 1);
      final second = DateTime.utc(2026, 11, 2);

      final difference =
          AstronomicalCoordinates.julianDate(second) -
          AstronomicalCoordinates.julianDate(first);

      expect(difference, closeTo(1.0, 1e-9));
    });

    test('UTC and local representations agree', () {
      final utc = DateTime.utc(2026, 11, 1, 20);
      final local = utc.toLocal();

      expect(
        AstronomicalCoordinates.julianDate(utc),
        AstronomicalCoordinates.julianDate(local),
      );
    });
  });

  group('Sidereal time', () {
    test('GMST at J2000 matches reference', () {
      final gmst = AstronomicalCoordinates.greenwichMeanSiderealDegrees(
        j2000Time,
      );

      expect(gmst, closeTo(280.46061837, 1e-6));
    });

    test('local sidereal time at Greenwich equals GMST', () {
      final gmst = AstronomicalCoordinates.greenwichMeanSiderealDegrees(
        j2000Time,
      );

      final lst = AstronomicalCoordinates.localMeanSiderealDegrees(
        j2000Time,
        0,
      );

      expect(lst, closeTo(gmst, 1e-9));
    });

    test('15 degrees east adds one sidereal hour', () {
      final gmst = AstronomicalCoordinates.greenwichMeanSiderealDegrees(
        j2000Time,
      );

      final lst = AstronomicalCoordinates.localMeanSiderealDegrees(
        j2000Time,
        15,
      );

      final difference = AstronomicalCoordinates.normalizeDegrees(lst - gmst);

      expect(difference, closeTo(15, 1e-9));
    });

    test('western longitude subtracts from sidereal time', () {
      final gmst = AstronomicalCoordinates.greenwichMeanSiderealDegrees(
        j2000Time,
      );

      final lst = AstronomicalCoordinates.localMeanSiderealDegrees(
        j2000Time,
        -30,
      );

      expect(
        AstronomicalCoordinates.normalizeSignedDegrees(lst - gmst),
        closeTo(-30, 1e-9),
      );
    });

    test('angles normalize correctly', () {
      expect(
        AstronomicalCoordinates.normalizeDegrees(-10),
        closeTo(350, 1e-12),
      );

      expect(AstronomicalCoordinates.normalizeDegrees(725), closeTo(5, 1e-12));

      expect(
        AstronomicalCoordinates.normalizeSignedDegrees(270),
        closeTo(-90, 1e-12),
      );
    });
  });

  group('Precession', () {
    test('J2000 to J2000 is the identity', () {
      const input = EquatorialPosition(raDegrees: 83.633, decDegrees: 22.014);

      final result = AstronomicalCoordinates.precessJ2000ToDate(
        j2000: input,
        time: j2000Time,
      );

      expect(result.raDegrees, closeTo(input.raDegrees, 1e-9));

      expect(result.decDegrees, closeTo(input.decDegrees, 1e-9));
    });

    test('precession changes coordinates over decades', () {
      const input = EquatorialPosition(raDegrees: 0, decDegrees: 0);

      final result = AstronomicalCoordinates.precessJ2000ToDate(
        j2000: input,
        time: DateTime.utc(2026, 11, 1),
      );

      expect(result.raDegrees, greaterThan(0));
      expect(result.raDegrees, lessThan(1));

      expect(result.decDegrees, greaterThan(0));
      expect(result.decDegrees, lessThan(1));
    });

    test('precession keeps valid coordinate ranges', () {
      const input = EquatorialPosition(raDegrees: 359.9, decDegrees: 89.9);

      final result = AstronomicalCoordinates.precessJ2000ToDate(
        j2000: input,
        time: DateTime.utc(2050, 6, 1),
      );

      expect(result.raDegrees, inInclusiveRange(0, 360));
      expect(result.decDegrees, inInclusiveRange(-90, 90));
    });
  });

  group('Horizontal coordinates', () {
    final gmst = AstronomicalCoordinates.greenwichMeanSiderealDegrees(
      j2000Time,
    );

    test('equatorial object on meridian is at zenith', () {
      final horizontal = AstronomicalCoordinates.equatorialToHorizontal(
        equatorialOfDate: EquatorialPosition(raDegrees: gmst, decDegrees: 0),
        observer: const ObserverPosition(
          latitudeDegrees: 0,
          longitudeDegrees: 0,
        ),
        time: j2000Time,
      );

      expect(horizontal.altitudeDegrees, closeTo(90, 1e-8));

      expect(horizontal.azimuthDegrees, isNull);
      expect(horizontal.zenithDistanceDegrees, closeTo(0, 1e-8));
    });

    test('equatorial meridian transit at 45 north', () {
      final horizontal = AstronomicalCoordinates.equatorialToHorizontal(
        equatorialOfDate: EquatorialPosition(raDegrees: gmst, decDegrees: 0),
        observer: const ObserverPosition(
          latitudeDegrees: 45,
          longitudeDegrees: 0,
        ),
        time: j2000Time,
      );

      expect(horizontal.altitudeDegrees, closeTo(45, 1e-8));

      expect(horizontal.azimuthDegrees!, closeTo(180, 1e-8));
    });

    test('negative hour angle places object in east', () {
      final equatorial = EquatorialPosition(
        raDegrees: AstronomicalCoordinates.normalizeDegrees(gmst + 90),
        decDegrees: 0,
      );

      final horizontal = AstronomicalCoordinates.equatorialToHorizontal(
        equatorialOfDate: equatorial,
        observer: const ObserverPosition(
          latitudeDegrees: 0,
          longitudeDegrees: 0,
        ),
        time: j2000Time,
      );

      expect(horizontal.altitudeDegrees, closeTo(0, 1e-8));

      expect(horizontal.azimuthDegrees!, closeTo(90, 1e-8));
    });

    test('positive hour angle places object in west', () {
      final equatorial = EquatorialPosition(
        raDegrees: AstronomicalCoordinates.normalizeDegrees(gmst - 90),
        decDegrees: 0,
      );

      final horizontal = AstronomicalCoordinates.equatorialToHorizontal(
        equatorialOfDate: equatorial,
        observer: const ObserverPosition(
          latitudeDegrees: 0,
          longitudeDegrees: 0,
        ),
        time: j2000Time,
      );

      expect(horizontal.altitudeDegrees, closeTo(0, 1e-8));

      expect(horizontal.azimuthDegrees!, closeTo(270, 1e-8));
    });

    test('full J2000 pipeline returns a position', () {
      final result = AstronomicalCoordinates.calculateJ2000(
        j2000: EquatorialPosition(raDegrees: gmst, decDegrees: 0),
        observer: const ObserverPosition(
          latitudeDegrees: 0,
          longitudeDegrees: 0,
        ),
        time: j2000Time,
      );

      expect(result.julianDate, 2451545.0);
      expect(result.hourAngleDegrees, closeTo(0, 1e-8));
      expect(result.horizontal.altitudeDegrees, closeTo(90, 1e-8));
    });
  });

  group('Angular separation', () {
    test('identical positions have zero separation', () {
      const position = EquatorialPosition(raDegrees: 120, decDegrees: 30);

      expect(
        AstronomicalCoordinates.angularSeparationDegrees(position, position),
        closeTo(0, 1e-10),
      );
    });

    test('quarter circle is 90 degrees', () {
      expect(
        AstronomicalCoordinates.angularSeparationDegrees(
          const EquatorialPosition(raDegrees: 0, decDegrees: 0),
          const EquatorialPosition(raDegrees: 90, decDegrees: 0),
        ),
        closeTo(90, 1e-8),
      );
    });

    test('antipodal points are 180 degrees apart', () {
      expect(
        AstronomicalCoordinates.angularSeparationDegrees(
          const EquatorialPosition(raDegrees: 0, decDegrees: 0),
          const EquatorialPosition(raDegrees: 180, decDegrees: 0),
        ),
        closeTo(180, 1e-8),
      );
    });

    test('RA wraparound is handled correctly', () {
      expect(
        AstronomicalCoordinates.angularSeparationDegrees(
          const EquatorialPosition(raDegrees: 359.9, decDegrees: 0),
          const EquatorialPosition(raDegrees: 0.1, decDegrees: 0),
        ),
        closeTo(0.2, 1e-8),
      );
    });
  });

  group('Relative airmass', () {
    test('zenith has approximately one airmass', () {
      expect(AstronomicalCoordinates.relativeAirmass(90), closeTo(1, 1e-6));
    });

    test('30 degree altitude is approximately two', () {
      expect(AstronomicalCoordinates.relativeAirmass(30)!, closeTo(2, 0.02));
    });

    test('below-horizon positions have no airmass', () {
      expect(AstronomicalCoordinates.relativeAirmass(-10), isNull);

      expect(AstronomicalCoordinates.relativeAirmass(0), isNull);
    });
  });

  group('Input validation', () {
    test('invalid celestial coordinates are rejected', () {
      const invalid = EquatorialPosition(raDegrees: 400, decDegrees: 0);

      expect(invalid.validate, throwsArgumentError);
    });

    test('invalid observer latitude is rejected', () {
      const invalid = ObserverPosition(
        latitudeDegrees: 95,
        longitudeDegrees: 8,
      );

      expect(invalid.validate, throwsArgumentError);
    });

    test('non-finite longitude is rejected', () {
      const invalid = ObserverPosition(
        latitudeDegrees: 47,
        longitudeDegrees: double.nan,
      );

      expect(invalid.validate, throwsArgumentError);
    });
  });
}
