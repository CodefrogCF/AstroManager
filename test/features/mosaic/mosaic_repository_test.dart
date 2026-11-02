import 'dart:io';

import 'package:drift/native.dart';
import 'package:astromanager/features/backup/data/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/mosaic/data/mosaic_repository.dart';
import 'package:astromanager/features/mosaic/domain/mosaic_plan.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';

const mosaic = MosaicPlan(
  projectId: 'p1',
  targetId: 'M31',
  profileId: 'setup',
  center: SkyAtlasPosition(raDegrees: 10.6, decDegrees: 41.2),
  rows: 2,
  columns: 3,
  overlapPercent: 20,
  rotationDegrees: 35,
);

void main() {
  test(
    'SQLite mosaic survives reopening and is removed with the project',
    () async {
      final dir = await Directory.systemTemp.createTemp('mosaic-test-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/database.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      final projects = DriftPlannedProjectsRepository(
        db,
        AppSettingsRepository(db),
      );
      await projects.save(
        PlannedImagingProject(
          id: 'p1',
          title: 'M31',
          targetIds: const ['M31'],
          createdAtUtc: DateTime.utc(2026, 11, 2),
        ),
      );
      final store = SettingsMosaicPlansRepository(AppSettingsRepository(db));
      await store.save(mosaic);
      expect((await store.load('p1'))?.columns, 3);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final after = SettingsMosaicPlansRepository(AppSettingsRepository(db));
      expect((await after.load('p1'))?.rotationDegrees, 35);
      await DriftPlannedProjectsRepository(
        db,
        AppSettingsRepository(db),
      ).remove('p1');
      expect(await after.load('p1'), isNull);
      await db.close();
    },
  );

  test(
    'portable backup includes and restores project mosaic metadata',
    () async {
      final original = AppDatabase(NativeDatabase.memory());
      final projects = DriftPlannedProjectsRepository(
        original,
        AppSettingsRepository(original),
      );
      await projects.save(
        PlannedImagingProject(
          id: 'p1',
          title: 'Andromeda',
          targetIds: const ['M31'],
          createdAtUtc: DateTime.utc(2026),
        ),
      );
      await SettingsMosaicPlansRepository(AppSettingsRepository(original))
          .save(mosaic);
      final archive = await AstroBackupService(original).export();
      await original.close();
      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(restored.close);
      await AstroBackupService(restored).restore(archive);
      final value = await SettingsMosaicPlansRepository(
        AppSettingsRepository(restored),
      ).load('p1');
      expect(value?.overlapPercent, 20);
      expect(value?.rows, 2);
      expect(
        (await DriftPlannedProjectsRepository(
          restored,
          AppSettingsRepository(restored),
        ).load()).single.id,
        'p1',
      );
    },
  );

  test('memory repository stores project mosaic independently', () async {
    final store = MemoryMosaicPlansRepository();
    await store.save(mosaic);
    expect((await store.load('p1'))?.profileId, 'setup');
    expect(await store.load('other'), isNull);
    await store.delete('p1');
    expect(await store.load('p1'), isNull);
  });
}
