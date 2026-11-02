import 'dart:convert';
import 'dart:typed_data';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/backup/data/backup_service.dart';
import 'package:astromanager/features/projects/data/attachments/attachment_store.dart';
import 'package:astromanager/features/projects/data/observation_sessions_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Images implements SessionAttachmentStore {
  final files = <String, Uint8List>{};

  @override
  Future<void> put(String key, Uint8List bytes) async {
    files[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> read(String key) async => files[key]!;

  @override
  Future<void> remove(String key) async {
    files.remove(key);
  }
}

Future<void> _seed(AppDatabase db, _Images images) async {
  await db.customStatement('''
    INSERT INTO observing_locations
    (id, name, latitude, longitude, elevation_meters, time_zone, is_default)
    VALUES ('zurich', 'Zurich', 47.37, 8.54, 410, 'Europe/Zurich', 1)
  ''');
  await db.customStatement('''
    INSERT INTO equipment_items (id, name, kind)
    VALUES ('cam1', 'Sony a7 II', 'camera'),
           ('opt1', 'Telescope', 'telescope'),
           ('mnt1', 'Star Adventurer GTi', 'mount')
  ''');
  await db.customStatement('''
    INSERT INTO optical_profiles
    (id, name, camera_id, optic_id, mount_id, focal_multiplier)
    VALUES ('setup1', 'Deep sky', 'cam1', 'opt1', 'mnt1', 1.0)
  ''');
  final project = PlannedImagingProject(
    id: 'p1',
    title: 'Andromeda',
    targetIds: ['M31'],
    locationId: 'zurich',
    opticalProfileId: 'setup1',
    createdAtUtc: DateTime.utc(2026, 11, 2),
    plannedIntegrationSeconds: 10800,
  );
  await DriftPlannedProjectsRepository(
    db,
    AppSettingsRepository(db),
  ).save(project);
  final session = ObservationSession(
    id: 's1',
    projectId: 'p1',
    startedAtUtc: DateTime.utc(2026, 11, 2, 21),
    timeZoneId: 'Europe/Zurich',
    utcOffsetMinutes: 60,
    locationId: 'zurich',
    locationName: 'Zurich',
    cameraId: 'cam1',
    cameraName: 'Sony a7 II',
    exposureSeconds: 60,
    frameCount: 70,
    acceptedFrames: 60,
    rejectedFrames: 10,
  );
  final sessions = DriftObservationSessionsRepository(db, attachments: images);
  await sessions.save(session);
  await sessions.addImage(
    's1',
    'preview.png',
    Uint8List.fromList([137, 80, 78, 71]),
  );
  await AppSettingsRepository(db).put(
    'planner.night.v1.zurich.2026-11-02',
    jsonEncode([
      {
        'id': 'block1',
        'locationId': 'zurich',
        'nightDate': '2026-11-02',
        'timeZoneId': 'Europe/Zurich',
        'projectId': 'p1',
        'targetId': 'M31',
        'projectName': 'Andromeda',
        'targetName': 'M31',
        'startUtc': '2026-11-02T21:00:00.000Z',
        'endUtc': '2026-11-02T22:00:00.000Z',
        'notes': '',
      },
    ]),
  );
  await AppSettingsRepository(db).put(
    'app.preferences.v1',
    '{"version":1,"units":"metric","clockFormat":"hour24","language":"system"}',
  );
}

void main() {
  test(
    'ZIP round trip preserves data, relationships and image binaries',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final destination = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      final srcImages = _Images();
      final dstImages = _Images();
      await _seed(source, srcImages);
      final bytes = await AstroBackupService(
        source,
        attachments: srcImages,
      ).export(includeImages: true, theme: 'night');
      final backup = AstroBackupService(destination, attachments: dstImages);
      final preview = backup.inspect(bytes);
      expect(preview.imageCount, 1);
      expect(preview.theme, 'night');
      expect(preview.counts['imaging_projects'], 1);
      expect(preview.counts['optical_profiles'], 1);
      await backup.restore(bytes);
      final projects = await DriftPlannedProjectsRepository(
        destination,
        AppSettingsRepository(destination),
      ).load();
      expect(projects.single.targetIds, ['M31']);
      expect(projects.single.opticalProfileId, 'setup1');
      final sessions = DriftObservationSessionsRepository(
        destination,
        attachments: dstImages,
      );
      final result = (await sessions.forProject('p1')).single;
      expect(result.acceptedFrames, 60);
      expect(result.acceptedIntegrationSeconds, 3600);
      expect(result.cameraName, 'Sony a7 II');
      final image = (await sessions.images('s1')).single;
      expect(await sessions.readImage(image), [137, 80, 78, 71]);
      expect(image.storageKey, isNot(srcImages.files.keys.single));
      expect(
        await AppSettingsRepository(destination)
            .get('planner.night.v1.zurich.2026-11-02'),
        contains('block1'),
      );
      expect(
        (await destination
            .customSelect('SELECT * FROM observing_locations')
            .get()),
        hasLength(1),
      );
      expect(
        (await destination
            .customSelect('SELECT * FROM optical_profiles')
            .get()),
        hasLength(1),
      );
    },
  );

  test(
    'images can be excluded without importing broken attachment rows',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final destination = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      final images = _Images();
      await _seed(source, images);
      final bytes = await AstroBackupService(
        source,
        attachments: images,
      ).export(includeImages: false);
      final backup = AstroBackupService(destination, attachments: _Images());
      expect(backup.inspect(bytes).imageCount, 0);
      await backup.restore(bytes);
      expect(
        (await destination
            .customSelect('SELECT * FROM observation_session_images')
            .get()),
        isEmpty,
      );
      expect(
        (await destination
            .customSelect('SELECT * FROM observation_sessions')
            .get()),
        hasLength(1),
      );
    },
  );

  test(
    'merge rejects duplicate IDs atomically without changing existing rows',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final destination = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      final images = _Images();
      await _seed(source, images);
      await _seed(destination, _Images());
      final bytes = await AstroBackupService(
        source,
        attachments: images,
      ).export(includeImages: true);
      final service = AstroBackupService(destination, attachments: _Images());
      await expectLater(service.restore(bytes), throwsA(isA<Exception>()));
      expect(
        (await destination
            .customSelect('SELECT * FROM imaging_projects')
            .get()),
        hasLength(1),
      );
      expect(
        (await destination
            .customSelect('SELECT * FROM observation_session_images')
            .get()),
        hasLength(1),
      );
    },
  );

  test('replace needs explicit confirmation and removes old records', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final destination = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(destination.close);
    final images = _Images();
    final otherImages = _Images();
    await _seed(source, images);
    await _seed(destination, otherImages);
    await destination.customStatement(
      "UPDATE imaging_projects SET title = 'Old value'",
    );
    final bytes = await AstroBackupService(
      source,
      attachments: images,
    ).export(includeImages: true);
    final service = AstroBackupService(destination, attachments: otherImages);
    await expectLater(
      service.restore(bytes, mode: BackupRestoreMode.replace),
      throwsStateError,
    );
    await service.restore(
      bytes,
      mode: BackupRestoreMode.replace,
      confirmedReplace: true,
    );
    final row =
        (await destination
                .customSelect('SELECT title FROM imaging_projects')
                .get())
            .single;
    expect(row.read<String>('title'), 'Andromeda');
    expect(
      (await destination
          .customSelect('SELECT * FROM observation_session_images')
          .get()),
      hasLength(1),
    );
    expect(otherImages.files, hasLength(1));
  });

  test(
    'rejects damaged and unsupported archives without modifying data',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final backup = AstroBackupService(db, attachments: _Images());
      expect(
        () => backup.inspect(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      await expectLater(
        backup.restore(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(
        (await db.customSelect('SELECT * FROM imaging_projects').get()),
        isEmpty,
      );
    },
  );
}
