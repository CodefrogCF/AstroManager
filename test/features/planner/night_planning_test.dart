import 'dart:io';

import 'package:astromanager/core/astronomy/solar_events.dart';
import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/planner/data/night_plans_repository.dart';
import 'package:astromanager/features/planner/domain/night_observation_block.dart';
import 'package:astromanager/features/planner/domain/night_timeline.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const site = ObservingLocation(
  id: 'zrh',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

NightObservationBlock block(
  String id,
  DateTime start,
  DateTime end, {
  String projectId = 'p1',
  String nightDate = '2026-11-02',
}) => NightObservationBlock(
  id: id,
  locationId: 'zrh',
  nightDate: nightDate,
  timeZoneId: 'Europe/Zurich',
  projectId: projectId,
  targetId: 'm31',
  projectName: 'Andromeda',
  targetName: 'M31',
  startUtc: start,
  endUtc: end,
);

void main() {
  test('no overlap when blocks touch; multi-block conflicts are symmetric', () {
    final a = block(
      'a',
      DateTime.utc(2026, 11, 2, 19),
      DateTime.utc(2026, 11, 2, 20),
    );
    final b = block(
      'b',
      DateTime.utc(2026, 11, 2, 20),
      DateTime.utc(2026, 11, 2, 21),
    );
    final c = block(
      'c',
      DateTime.utc(2026, 11, 2, 19, 30),
      DateTime.utc(2026, 11, 2, 20, 30),
    );
    expect(NightPlanConflicts.detect([a, b]), isEmpty);
    final conflicts = NightPlanConflicts.detect([b, c, a]);
    expect(conflicts['a'], {'c'});
    expect(conflicts['b'], {'c'});
    expect(conflicts['c'], {'a', 'b'});
  });

  test('unscheduled darkness excludes overlapping blocks only once', () {
    final timeline = NightTimeline(
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 2),
      ),
    );
    final darkness = timeline.day.astronomicalDarkness.single;
    final beforeDusk = block(
      'dusk',
      darkness.startUtc.subtract(const Duration(minutes: 30)),
      darkness.startUtc.add(const Duration(hours: 1)),
    );
    final overlaps = block(
      'overlap',
      darkness.startUtc.add(const Duration(minutes: 30)),
      darkness.startUtc.add(const Duration(minutes: 90)),
    );
    final afterDawn = block(
      'daylight',
      darkness.endUtc.add(const Duration(minutes: 10)),
      darkness.endUtc.add(const Duration(minutes: 30)),
    );
    expect(
      timeline.unscheduledDarkness([overlaps, afterDawn, beforeDusk]),
      darkness.duration - const Duration(minutes: 90),
    );
  });

  test('UTC intervals preserve their night and snapshot through JSON', () {
    final original = block(
      'one',
      DateTime.utc(2026, 11, 2, 22),
      DateTime.utc(2026, 11, 3, 1),
    );
    final restored = NightObservationBlock.fromJson(original.toJson());
    expect(restored.startUtc, original.startUtc);
    expect(restored.duration, const Duration(hours: 3));
    expect(restored.projectName, 'Andromeda');
    expect(restored.nightDate, '2026-11-02');
    expect(
      () => block(
        'invalid',
        DateTime.utc(2026, 11, 2, 20),
        DateTime.utc(2026, 11, 2, 19),
      ),
      throwsFormatException,
    );
    expect(
      () => block(
        'invalid',
        DateTime.now(),
        DateTime.now().add(const Duration(hours: 1)),
      ),
      throwsFormatException,
    );
  });

  test('local noon-to-noon duration handles March and October DST', () {
    final spring = NightTimeline(
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 3, 28),
      ),
    );
    final autumn = NightTimeline(
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 10, 24),
      ),
    );
    expect(spring.duration, const Duration(hours: 23));
    expect(autumn.duration, const Duration(hours: 25));
    expect(spring.fraction(spring.startUtc), 0);
    expect(spring.fraction(spring.endUtc), 1);
    expect(spring.darknessIntervals(), isNotEmpty);
    final fallLabels = autumn.ticks(hours: 1).map(autumn.clockLabel).toList();
    expect(fallLabels, contains('02:00 UTC+02:00'));
    expect(fallLabels, contains('02:00 UTC+01:00'));
  });

  test('site-local clock rejects spring gap and distinguishes autumn fold', () {
    final missing = NightLocalClock.candidates(
      timeZoneId: 'Europe/Zurich',
      year: 2026,
      month: 3,
      day: 29,
      hour: 2,
      minute: 30,
    );
    expect(missing, isEmpty);
    final repeated = NightLocalClock.candidates(
      timeZoneId: 'Europe/Zurich',
      year: 2026,
      month: 10,
      day: 25,
      hour: 2,
      minute: 30,
    );
    expect(repeated, hasLength(2));
    expect(repeated[1].difference(repeated[0]), const Duration(hours: 1));
    final ordinary = NightLocalClock.candidates(
      timeZoneId: 'Europe/Zurich',
      year: 2026,
      month: 11,
      day: 2,
      hour: 21,
      minute: 30,
    );
    expect(ordinary, hasLength(1));
  });

  test('visibility geometry is bounded by astronomical darkness', () {
    final night = NightTimeline(
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 2),
      ),
    );
    final visibility = NightTargetVisibility.calculate(
      timeline: night,
      site: site,
      raDegrees: 10.6847,
      decDegrees: 41.2687,
    );
    expect(visibility.samples, isNotEmpty);
    for (final span in visibility.visibleIntervals) {
      expect(night.contains(span.startUtc, span.endUtc), isTrue);
      expect(
        night.darknessIntervals().any(
          (dark) =>
              !span.startUtc.isBefore(dark.startUtc) &&
              !span.endUtc.isAfter(dark.endUtc),
        ),
        isTrue,
      );
    }
  });

  test(
    'night blocks persist offline and can be edited/deleted independently',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'astro_night_plan_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}night.sqlite',
      );
      final database = AppDatabase(NativeDatabase(file));
      final repo = SettingsNightPlansRepository(
        AppSettingsRepository(database),
      );
      const key = NightPlanKey('zrh', '2026-11-02');
      expect(await repo.forNight(key), isEmpty);
      final first = block(
        'one',
        DateTime.utc(2026, 11, 2, 20),
        DateTime.utc(2026, 11, 2, 21),
      );
      final second = block(
        'two',
        DateTime.utc(2026, 11, 2, 22),
        DateTime.utc(2026, 11, 2, 23),
      );
      await Future.wait([repo.save(first), repo.save(second)]);
      await repo.save(
        block(
          'one',
          DateTime.utc(2026, 11, 2, 20),
          DateTime.utc(2026, 11, 2, 22),
        ),
      );
      await database.close();
      final reloaded = AppDatabase(NativeDatabase(file));
      try {
        final next = SettingsNightPlansRepository(
          AppSettingsRepository(reloaded),
        );
        final saved = await next.forNight(key);
        expect(saved, hasLength(2));
        expect(saved.first.duration, const Duration(hours: 2));
        expect(saved.last.projectId, 'p1');
        expect(
          await next.forNight(const NightPlanKey('other', '2026-11-02')),
          isEmpty,
        );
        await next.remove(key, 'one');
        expect((await next.forNight(key)).single.id, 'two');
        await next.remove(key, 'two');
        expect(await next.forNight(key), isEmpty);
      } finally {
        await reloaded.close();
      }
    },
  );
}
