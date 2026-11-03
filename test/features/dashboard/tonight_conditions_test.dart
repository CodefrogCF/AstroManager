import 'package:astromanager/features/dashboard/domain/tonight_conditions.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:flutter_test/flutter_test.dart';

const _zurich = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

ObservingLocation _polar() => const ObservingLocation(
  id: 'north-pole',
  name: 'North Pole',
  latitude: 89,
  longitude: 0,
  elevationMeters: 0,
  timeZone: 'Etc/UTC',
  isDefault: false,
);

void main() {
  test(
    'current night stays associated with the previous date after midnight',
    () {
      final duringNight = DateTime.utc(2026, 11, 4, 1);
      expect(
        TonightConditionsCalculator.currentNight(_zurich, duringNight),
        DateTime.utc(2026, 11, 3),
      );
      expect(
        TonightConditionsCalculator.currentNight(
          _zurich,
          DateTime.utc(2026, 11, 4, 11),
        ),
        DateTime.utc(2026, 11, 4),
      );
    },
  );

  test(
    'night includes sunset, next-day sunrise, darkness and lunar events',
    () {
      final result = TonightConditionsCalculator.calculate(
        location: _zurich,
        localDate: DateTime.utc(2026, 11, 3),
      );
      expect(result.sunset, isNotNull);
      expect(result.sunrise, isNotNull);
      expect(result.astronomicalDusk, isNotNull);
      expect(result.astronomicalDawn, isNotNull);
      expect(result.sunset!.local.day, 3);
      expect(result.sunrise!.local.day, 4);
      expect(
        result.astronomicalDusk!.utc.isBefore(result.astronomicalDawn!.utc),
        isTrue,
      );
      expect(result.darknessState, TonightDarknessState.partial);
      expect(result.darknessDuration.inHours, inInclusiveRange(9, 12));
      expect(result.moon.illuminationFraction, inInclusiveRange(0, 1));
      expect(result.moonEvents.startUtc, result.night.nightStartUtc);
      expect(result.moonEvents.endUtc, result.night.nightEndUtc);
      expect(
        result.remainingDarknessAt(result.night.nightStartUtc),
        result.darknessDuration,
      );
      expect(
        result.remainingDarknessAt(result.night.nightEndUtc),
        Duration.zero,
      );
      final interval = result.night.astronomicalDarkness.first;
      final midpoint = interval.startUtc.add(interval.duration ~/ 2);
      final remaining = result.remainingDarknessAt(midpoint);
      expect((remaining - interval.duration ~/ 2).inSeconds.abs(), lessThan(5));
    },
  );

  test('local noon-to-noon duration is correct across spring DST jump', () {
    final result = TonightConditionsCalculator.calculate(
      location: _zurich,
      localDate: DateTime.utc(2026, 3, 28),
    );
    expect(result.observationWindow, const Duration(hours: 23));
    expect(result.darknessDuration, greaterThan(Duration.zero));
    expect(result.sunset?.local.day, 28);
    expect(result.sunrise?.local.day, 29);
    expect(result.remainingDarknessAt(result.night.nightEndUtc), Duration.zero);
  });

  test('local noon-to-noon duration is correct across autumn DST rollback', () {
    final result = TonightConditionsCalculator.calculate(
      location: _zurich,
      localDate: DateTime.utc(2026, 10, 24),
    );
    expect(result.observationWindow, const Duration(hours: 25));
    expect(result.darknessDuration, greaterThan(Duration.zero));
    expect(result.sunset?.local.day, 24);
    expect(result.sunrise?.local.day, 25);
  });

  test('polar summer has no astronomical darkness or solar crossings', () {
    final result = TonightConditionsCalculator.calculate(
      location: _polar(),
      localDate: DateTime.utc(2026, 6, 21),
    );
    expect(result.darknessState, TonightDarknessState.none);
    expect(result.darknessDuration, Duration.zero);
    expect(result.sunset, isNull);
    expect(result.sunrise, isNull);
    expect(result.astronomicalDusk, isNull);
    expect(result.astronomicalDawn, isNull);
    expect(
      result.remainingDarknessAt(result.night.nightStartUtc),
      Duration.zero,
    );
  });

  test('polar winter has continuous darkness without invented twilight', () {
    final result = TonightConditionsCalculator.calculate(
      location: _polar(),
      localDate: DateTime.utc(2026, 12, 21),
    );
    expect(result.darknessState, TonightDarknessState.continuous);
    expect(result.darknessDuration, const Duration(hours: 24));
    expect(result.sunset, isNull);
    expect(result.sunrise, isNull);
    expect(result.astronomicalDusk, isNull);
    expect(result.astronomicalDawn, isNull);
  });
}
