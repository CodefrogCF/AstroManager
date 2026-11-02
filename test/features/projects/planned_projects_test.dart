import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';

void main() {
  test(
    'projects survive repository re-creation and retain planning metadata',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = AppSettingsRepository(database);
      final repository = SettingsPlannedProjectsRepository(settings);
      final original = newPlannedProject(
        title: 'Andromeda imaging',
        targetId: 'NGC0224',
        localDate: DateTime(2026, 11, 2),
        locationId: 'home',
        profileId: 'sony',
        startUtc: DateTime.utc(2026, 11, 2, 21),
        endUtc: DateTime.utc(2026, 11, 3),
        nowUtc: DateTime.utc(2026, 11, 1),
      );
      await repository.save(original);
      final reloaded = (await SettingsPlannedProjectsRepository(
        settings,
      ).load()).single;
      expect(reloaded.title, 'Andromeda imaging');
      expect(reloaded.observingDate, '2026-11-02');
      expect(reloaded.locationId, 'home');
      expect(reloaded.opticalProfileId, 'sony');
      expect(reloaded.windowEndUtc, DateTime.utc(2026, 11, 3));
      expect(reloaded.targetIds, ['NGC0224']);

      await repository.save(
        reloaded.withTarget('NGC1976').withTarget('NGC1976'),
      );
      expect((await repository.load()).single.targetIds, [
        'NGC0224',
        'NGC1976',
      ]);
      await repository.remove(original.id);
      expect(await repository.load(), isEmpty);
    },
  );

  test('invalid project records fail without silently losing data', () {
    expect(
      () => PlannedImagingProject(
        id: '',
        title: 'No ID',
        targetIds: ['a'],
        createdAtUtc: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    expect(
      () => PlannedImagingProject(
        id: 'id',
        title: 'Invalid',
        targetIds: ['a', 'a'],
        createdAtUtc: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    expect(
      () => PlannedImagingProject(
        id: 'id',
        title: 'Invalid dates',
        targetIds: ['a'],
        createdAtUtc: DateTime.utc(2026),
        windowStartUtc: DateTime.utc(2026, 11, 3),
        windowEndUtc: DateTime.utc(2026, 11, 2),
      ),
      throwsFormatException,
    );
  });
}
