import 'dart:convert';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/features/atlas/domain/sky_dome.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const site = ObservingLocation(
    id: 'zurich',
    name: 'Zurich',
    latitude: 47.3769,
    longitude: 8.5417,
    elevationMeters: 408,
    timeZone: 'Europe/Zurich',
    isDefault: true,
  );
  final epoch = DateTime.utc(2026, 11, 2, 22);
  const observer = ObserverPosition(
    latitudeDegrees: 47.3769,
    longitudeDegrees: 8.5417,
  );

  test('zenith is at 90 degrees altitude after J2000 round trip', () {
    final dome = SkyDomeGeometry.calculate(location: site, utc: epoch);
    final position = AstronomicalCoordinates.calculateJ2000(
      j2000: EquatorialPosition(
        raDegrees: dome.zenith.raDegrees,
        decDegrees: dome.zenith.decDegrees,
      ),
      observer: observer,
      time: epoch,
    );
    expect(position.horizontal.altitudeDegrees, closeTo(90, 1e-5));
  });

  test('horizon, altitude rings and cardinals are stable in J2000', () {
    final dome = SkyDomeGeometry.calculate(
      location: site,
      utc: epoch,
      minimumAltitudeDegrees: 25,
    );
    expect(dome.horizon.length, 121);
    expect(dome.altitude30.length, 121);
    expect(dome.altitude60.length, 121);
    expect(dome.minimumAltitude.length, 121);
    expect(dome.cardinals.map((e) => e.label), ['N', 'E', 'S', 'W']);
    expect(
      dome.horizon.first.raDegrees,
      closeTo(dome.horizon.last.raDegrees, 1e-7),
    );
    expect(
      dome.horizon.first.decDegrees,
      closeTo(dome.horizon.last.decDegrees, 1e-7),
    );

    for (final (ring, expectedAltitude) in [
      (dome.horizon, 0.0),
      (dome.altitude30, 30.0),
      (dome.altitude60, 60.0),
      (dome.minimumAltitude, 25.0),
    ]) {
      for (var index = 0; index < ring.length; index += 15) {
        final point = ring[index];
        final result = AstronomicalCoordinates.calculateJ2000(
          j2000: EquatorialPosition(
            raDegrees: point.raDegrees,
            decDegrees: point.decDegrees,
          ),
          observer: observer,
          time: epoch,
        );
        expect(
          result.horizontal.altitudeDegrees,
          closeTo(expectedAltitude, 1e-4),
        );
      }
    }
  });

  test('horizon rotates relative to the catalog over time', () {
    final first = SkyDomeGeometry.calculate(location: site, utc: epoch);
    final later = SkyDomeGeometry.calculate(
      location: site,
      utc: epoch.add(const Duration(hours: 2)),
    );
    expect(
      (first.zenith.raDegrees - later.zenith.raDegrees).abs(),
      greaterThan(20),
    );
  });

  test(
    'metadata and horizon are JSON serializable and invalid inputs fail',
    () {
      final dome = SkyDomeGeometry.calculate(location: site, utc: epoch);
      final encoded = jsonDecode(jsonEncode(dome.toJson())) as Map;
      expect((encoded['horizon'] as List).length, 121);
      expect(
        () => SkyDomeGeometry.calculate(
          location: site,
          utc: epoch,
          minimumAltitudeDegrees: 90,
        ),
        throwsArgumentError,
      );
    },
  );
}
