import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';

PlannedImagingProject project(String id, {String? equipment}) =>
    PlannedImagingProject(
      id: id,
      title: 'Orion nebula',
      targetIds: const ['NGC1976', 'NGC1982'],
      createdAtUtc: DateTime.utc(2026, 11, 2),
      updatedAtUtc: DateTime.utc(2026, 11, 2),
      opticalProfileId: equipment,
      description: 'Wide field',
      notes: 'Avoid moonlight',
      imagingGoal: 'Ha/OIII',
      plannedIntegrationSeconds: 18000,
      observingDate: '2026-11-03',
    );

void main() {
  test('v5 creates normalized project and target-link tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = DriftPlannedProjectsRepository(
      db,
      AppSettingsRepository(db),
    );
    await repository.save(project('a'));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 5);
    final tables =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='table'",
                )
                .get())
            .map((row) => row.read<String>('name'))
            .toSet();
    expect(
      tables,
      containsAll(['imaging_projects', 'imaging_project_targets']),
    );
    final links = await db
        .customSelect('SELECT * FROM imaging_project_targets')
        .get();
    expect(links, hasLength(2));
  });

  test(
    'CRUD, status transitions, metadata and target links round trip',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftPlannedProjectsRepository(
        db,
        AppSettingsRepository(db),
      );
      await repository.save(project('a', equipment: 'sony-camera'));
      var loaded = (await repository.load()).single;
      expect(loaded.description, 'Wide field');
      expect(loaded.notes, 'Avoid moonlight');
      expect(loaded.imagingGoal, 'Ha/OIII');
      expect(loaded.plannedIntegrationSeconds, 18000);
      expect(loaded.targetIds, ['NGC1976', 'NGC1982']);
      expect(loaded.opticalProfileId, 'sony-camera');
      for (final status in [
        ImagingProjectStatus.inProgress,
        ImagingProjectStatus.completed,
        ImagingProjectStatus.archived,
        ImagingProjectStatus.planned,
      ]) {
        await repository.save(loaded.copyWith(status: status));
        loaded = (await repository.load()).single;
        expect(loaded.status, status);
      }
      await repository.save(
        loaded.copyWith(
          targetIds: ['NGC1976'],
          notes: 'More luminance needed',
          plannedIntegrationSeconds: 21600,
        ),
      );
      expect((await repository.load()).single.targetIds, ['NGC1976']);
      expect((await repository.load()).single.notes, 'More luminance needed');
      await repository.remove('a');
      expect(await repository.load(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM imaging_project_targets').get(),
        isEmpty,
      );
    },
  );

  test(
    'equipment IDs remain readable even if the equipment was deleted',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftPlannedProjectsRepository(
        db,
        AppSettingsRepository(db),
      );
      // Deliberately no matching optical_profiles row.
      await repository.save(project('orphan', equipment: 'deleted-profile-id'));
      expect(
        (await repository.load()).single.opticalProfileId,
        'deleted-profile-id',
      );
    },
  );

  test(
    'one-time upgrade imports all old JSON projects without duplicates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = AppSettingsRepository(db);
      final legacy = SettingsPlannedProjectsRepository(settings);
      await legacy.save(project('old'));
      final repository = DriftPlannedProjectsRepository(db, settings);
      expect((await repository.load()).single.id, 'old');
      expect(
        await settings.get(SettingsPlannedProjectsRepository.storageKey),
        isNull,
      );
      expect((await repository.load()), hasLength(1));
      expect(
        (await DriftPlannedProjectsRepository(db, settings).load()),
        hasLength(1),
      );
    },
  );

  test('malformed legacy records are preserved for recovery', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = AppSettingsRepository(db);
    await settings.put(SettingsPlannedProjectsRepository.storageKey, '{broken');
    final repository = DriftPlannedProjectsRepository(db, settings);
    await expectLater(repository.load(), throwsFormatException);
    expect(
      await settings.get(SettingsPlannedProjectsRepository.storageKey),
      '{broken',
    );
  });

  test(
    'offline projects survive closing and reopening the database file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'astromanager_project_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}projects.sqlite',
      );
      final first = AppDatabase(NativeDatabase(file));
      await DriftPlannedProjectsRepository(
        first,
        AppSettingsRepository(first),
      ).save(project('permanent', equipment: 'long-gone'));
      await first.close();
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final stored = (await DriftPlannedProjectsRepository(
        reopened,
        AppSettingsRepository(reopened),
      ).load()).single;
      expect(stored.id, 'permanent');
      expect(stored.plannedIntegrationSeconds, 18000);
      expect(stored.opticalProfileId, 'long-gone');
    },
  );

  test('new metadata validates integration time and target identifiers', () {
    expect(
      () => project('a').copyWith(plannedIntegrationSeconds: -1),
      throwsFormatException,
    );
    expect(
      () => project('a').copyWith(targetIds: ['x', 'x']),
      throwsFormatException,
    );
    expect(() => project('a').copyWith(title: '  '), throwsFormatException);
  });
}
