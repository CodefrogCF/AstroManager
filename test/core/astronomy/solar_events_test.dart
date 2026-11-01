import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:astromanager/core/astronomy/solar_events.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';

const zurich = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

ObservingLocation polarLocation({required double latitude}) =>
    ObservingLocation(
      id: 'polar',
      name: 'Polar site',
      latitude: latitude,
      longitude: 0,
      elevationMeters: 0,
      timeZone: 'Etc/UTC',
      isDefault: true,
    );

void expectLocalMinute(
  tz.TZDateTime? event,
  int hour,
  int minute, {
  int toleranceMinutes = 3,
}) {
  expect(event, isNotNull);
  final actual = event!.hour * 60 + event.minute;
  final expected = hour * 60 + minute;
  expect((actual - expected).abs(), lessThanOrEqualTo(toleranceMinutes));
}

void main() {
  group('Solar altitude and reference events', () {
    test('solar altitude is positive near noon, negative near midnight', () {
      final noon = SolarEvents.sunAltitudeDegrees(
        at: DateTime.utc(2026, 11, 1, 11, 9),
        latitudeDegrees: zurich.latitude,
        longitudeDegrees: zurich.longitude,
      );
      final night = SolarEvents.sunAltitudeDegrees(
        at: DateTime.utc(2026, 11, 1, 23),
        latitudeDegrees: zurich.latitude,
        longitudeDegrees: zurich.longitude,
      );
      expect(noon, closeTo(28.2, 0.5));
      expect(night, lessThan(-18));
      expect(
        SolarEvents.isAstronomicallyDark(
          at: DateTime.utc(2026, 11, 1, 23),
          location: zurich,
        ),
        isTrue,
      );
    });

    test('Zurich 2026-11-01 agrees with published solar events', () {
      // Reference (rounded to minute): timeanddate.com/sun/switzerland/zurich
      // November 2026, Nov 1: rise 07:09, set 17:09;
      // civil 06:37/17:41; nautical 06:00/18:17;
      // astronomical 05:25/18:52 (CET, UTC+01:00).
      final day = SolarEvents.calculateForLocalDate(
        location: zurich,
        localDate: DateTime(2026, 11, 1),
      );
      expectLocalMinute(day.sunrise?.local, 7, 9);
      expectLocalMinute(day.sunset?.local, 17, 9);
      expectLocalMinute(day.civilDawn?.local, 6, 37);
      expectLocalMinute(day.civilDusk?.local, 17, 41);
      expectLocalMinute(day.nauticalDawn?.local, 6, 0);
      expectLocalMinute(day.nauticalDusk?.local, 18, 17);
      expectLocalMinute(day.astronomicalDawn?.local, 5, 25);
      expectLocalMinute(day.astronomicalDusk?.local, 18, 52);
      expect(day.sunrise!.local.timeZoneOffset, const Duration(hours: 1));
      expect(day.civilDayLength, const Duration(hours: 24));
    });

    test('astronomical darkness crosses midnight and ends next morning', () {
      final day = SolarEvents.calculateForLocalDate(
        location: zurich,
        localDate: DateTime.utc(2026, 11, 1),
      );
      expect(day.astronomicalDarkness, hasLength(1));
      final night = day.astronomicalDarkness.single;
      expect(night.startLocal.day, 1);
      expect(night.endLocal.day, 2);
      expectLocalMinute(night.startLocal, 18, 52);
      expectLocalMinute(night.endLocal, 5, 26);
      expect(night.duration.inHours, inInclusiveRange(9, 11));
      expect(night.startUtc.isBefore(night.endUtc), isTrue);
    });

    test('crossing altitude brackets its threshold', () {
      final day = SolarEvents.calculateForLocalDate(
        location: zurich,
        localDate: DateTime(2026, 11, 1),
      );
      for (final threshold in SolarThreshold.values) {
        final events = day.forThreshold(threshold);
        expect(events.crossings, hasLength(2));
        for (final event in events.crossings) {
          final actual = SolarEvents.sunAltitudeDegrees(
            at: event.utc,
            latitudeDegrees: zurich.latitude,
            longitudeDegrees: zurich.longitude,
          );
          expect(actual, closeTo(threshold.altitudeDegrees, 0.01));
        }
      }
    });

    test('invalid coordinates are rejected', () {
      expect(
        () => SolarEvents.sunAltitudeDegrees(
          at: DateTime.utc(2026),
          latitudeDegrees: 100,
          longitudeDegrees: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Polar and missing events', () {
    test('polar summer has no sunrise or astronomical darkness', () {
      final location = polarLocation(latitude: 89);
      final day = SolarEvents.calculateForLocalDate(
        location: location,
        localDate: DateTime(2026, 6, 21),
      );
      expect(day.sunrise, isNull);
      expect(day.sunset, isNull);
      expect(
        day.forThreshold(SolarThreshold.horizon).state,
        SolarCrossingState.alwaysAbove,
      );
      expect(day.astronomicalDarkness, isEmpty);
    });

    test('polar winter is astronomically dark all night', () {
      final location = polarLocation(latitude: 89);
      final day = SolarEvents.calculateForLocalDate(
        location: location,
        localDate: DateTime(2026, 12, 21),
      );
      expect(day.sunrise, isNull);
      expect(day.sunset, isNull);
      expect(
        day.forThreshold(SolarThreshold.astronomical).state,
        SolarCrossingState.alwaysBelow,
      );
      expect(day.astronomicalDarkness, hasLength(1));
      expect(
        day.astronomicalDarkness.single.duration,
        const Duration(hours: 24),
      );
    });

    test('a polar night can have twilight without sunrise', () {
      final location = ObservingLocation(
        id: 'tromso',
        name: 'Tromso',
        latitude: 69.6492,
        longitude: 18.9553,
        elevationMeters: 10,
        timeZone: 'Europe/Oslo',
        isDefault: true,
      );
      final day = SolarEvents.calculateForLocalDate(
        location: location,
        localDate: DateTime(2026, 12, 21),
      );
      expect(day.sunrise, isNull);
      expect(day.sunset, isNull);
      expect(day.civilDawn, isNotNull);
      expect(day.civilDusk, isNotNull);
    });
  });

  group('Time zones and DST', () {
    test('spring-forward local day is 23 hours', () {
      final day = SolarEvents.calculateForLocalDate(
        location: zurich,
        localDate: DateTime(2026, 3, 29),
      );
      expect(day.civilDayLength, const Duration(hours: 23));
      expect(day.sunrise!.local.timeZoneOffset, const Duration(hours: 2));
      expect(day.sunrise!.local.day, 29);
    });

    test('fall-back local day is 25 hours', () {
      final day = SolarEvents.calculateForLocalDate(
        location: zurich,
        localDate: DateTime(2026, 10, 25),
      );
      expect(day.civilDayLength, const Duration(hours: 25));
      expect(day.sunrise!.local.timeZoneOffset, const Duration(hours: 1));
    });

    test('repeated fall-back wall-clock time is disambiguated by offset', () {
      final zone = SolarEvents.timeZone('Europe/Zurich');
      final first = tz.TZDateTime.from(DateTime.utc(2026, 10, 25, 0, 30), zone);
      final second = tz.TZDateTime.from(
        DateTime.utc(2026, 10, 25, 1, 30),
        zone,
      );
      expect(first.hour, 2);
      expect(second.hour, 2);
      expect(SolarEvents.formatLocal(first), '02:30 (UTC+02:00)');
      expect(SolarEvents.formatLocal(second), '02:30 (UTC+01:00)');
    });

    test(
      'night spans the DST fall-back transition without wall-time arithmetic',
      () {
        final day = SolarEvents.calculateForLocalDate(
          location: zurich,
          localDate: DateTime(2026, 10, 24),
        );
        expect(
          day.nightEndUtc.difference(day.nightStartUtc),
          const Duration(hours: 25),
        );
        final night = day.astronomicalDarkness.single;
        expect(night.startLocal.timeZoneOffset, const Duration(hours: 2));
        expect(night.endLocal.timeZoneOffset, const Duration(hours: 1));
        expect(night.duration.inMinutes, greaterThan(600));
      },
    );
  });
}
