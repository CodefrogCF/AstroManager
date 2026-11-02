import 'dart:io';
import 'dart:typed_data';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/projects/data/attachments/attachment_store.dart';
import 'package:astromanager/features/projects/data/observation_sessions_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:flutter_test/flutter_test.dart';

class MemoryImages implements SessionAttachmentStore {
  final files = <String, Uint8List>{};
  @override
  Future<void> put(String key, Uint8List bytes) async {
    files[key] = bytes;
  }

  @override
  Future<Uint8List> read(String key) async => files[key]!;
  @override
  Future<void> remove(String key) async {
    files.remove(key);
  }
}

PlannedImagingProject project(String id) => PlannedImagingProject(
  id: id,
  title: 'M31',
  targetIds: [],
  createdAtUtc: DateTime.utc(2026, 11, 2),
);

ObservationSession session(
  String id,
  String projectId, {
  String camera = 'Sony a7 II',
}) => ObservationSession(
  id: id,
  projectId: projectId,
  startedAtUtc: DateTime.utc(2026, 11, 2, 20),
  timeZoneId: 'Europe/Zurich',
  utcOffsetMinutes: 60,
  locationId: 'loc1',
  locationName: 'Garden',
  cameraId: 'camera1',
  cameraName: camera,
  opticId: 'optic1',
  opticName: 'Tamron 70-200mm',
  mountId: 'mount1',
  mountName: 'Star Adventurer GTi',
  exposureSeconds: 37.5,
  frameCount: 12,
  acceptedFrames: 10,
  rejectedFrames: 2,
  iso: 800,
  apertureFNumber: 2.8,
  notes: 'Clear night',
);

void main() {
  test('v6 creates session tables and enforces project foreign keys', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final sessions = DriftObservationSessionsRepository(
      db,
      attachments: MemoryImages(),
    );
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      6,
    );
    await expectLater(
      sessions.save(session('s1', 'absent')),
      throwsA(isA<Exception>()),
    );
    await DriftPlannedProjectsRepository(
      db,
      AppSettingsRepository(db),
    ).save(project('project1'));
    await sessions.save(session('s1', 'project1'));
    expect(await sessions.forProject('project1'), hasLength(1));
  });

  test(
    'create, edit, multiple sessions, delete and equipment snapshots',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final projects = DriftPlannedProjectsRepository(
        db,
        AppSettingsRepository(db),
      );
      final sessions = DriftObservationSessionsRepository(
        db,
        attachments: MemoryImages(),
      );
      await projects.save(project('p1'));
      await projects.save(project('p2'));
      await sessions.save(session('s1', 'p1'));
      await sessions.save(session('s2', 'p1'));
      await sessions.save(session('other', 'p2'));
      expect(await sessions.forProject('p1'), hasLength(2));
      expect(await sessions.forProject('p2'), hasLength(1));
      await sessions.save(session('s1', 'p1', camera: 'Renamed snapshot'));
      final loaded = await sessions.forProject('p1');
      expect(
        loaded.singleWhere((s) => s.id == 's1').cameraName,
        'Renamed snapshot',
      );
      expect(loaded.first.exposureSeconds, 37.5);
      await sessions.remove('s2');
      expect(await sessions.forProject('p1'), hasLength(1));
      await projects.remove('p1');
      expect(await sessions.forProject('p1'), isEmpty);
      expect(await sessions.forProject('p2'), hasLength(1));
    },
  );

  test(
    'image bytes stay out of SQLite and metadata cascades on deletion',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await DriftPlannedProjectsRepository(
        db,
        AppSettingsRepository(db),
      ).save(project('p1'));
      final store = MemoryImages();
      final sessions = DriftObservationSessionsRepository(
        db,
        attachments: store,
      );
      await sessions.save(session('s1', 'p1'));
      final image = await sessions.addImage(
        's1',
        'stack.png',
        Uint8List.fromList([137, 80, 78, 71]),
      );
      expect((await sessions.images('s1')).single.fileName, 'stack.png');
      expect((await sessions.readImage(image)).length, 4);
      expect(store.files, contains(image.storageKey));
      final dbRows = await db
          .customSelect('SELECT * FROM observation_session_images')
          .get();
      expect(dbRows.single.data.keys, isNot(contains('bytes')));
      await sessions.remove('s1');
      expect(await sessions.images('s1'), isEmpty);
      expect(store.files, isEmpty);
    },
  );

  test('image import validates extensions and size', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final sessions = DriftObservationSessionsRepository(
      db,
      attachments: MemoryImages(),
    );
    await expectLater(
      sessions.addImage('x', 'not-image.exe', Uint8List.fromList([1])),
      throwsFormatException,
    );
    await expectLater(
      sessions.addImage('x', 'empty.png', Uint8List(0)),
      throwsFormatException,
    );
  });

  test(
    'session data persists after closing a real SQLite database file',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'astromanager_sessions_',
      );
      addTearDown(() async {
        await dir.delete(recursive: true);
      });
      final file = File('${dir.path}${Platform.pathSeparator}sessions.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      await DriftPlannedProjectsRepository(
        first,
        AppSettingsRepository(first),
      ).save(project('p1'));
      await DriftObservationSessionsRepository(
        first,
        attachments: MemoryImages(),
      ).save(session('s1', 'p1'));
      await first.close();
      final second = AppDatabase(NativeDatabase(file));
      try {
        final found = await DriftObservationSessionsRepository(
          second,
          attachments: MemoryImages(),
        ).forProject('p1');
        expect(found.single.cameraName, 'Sony a7 II');
        expect(found.single.acceptedIntegrationSeconds, 375);
        expect(found.single.startedAtUtc, DateTime.utc(2026, 11, 2, 20));
      } finally {
        await second.close();
      }
    },
  );

  test('upgrades v5 data to v6 without losing project records', () async {
    final dir = await Directory.systemTemp.createTemp(
      'astromanager_migration_v6_',
    );
    addTearDown(() async {
      await dir.delete(recursive: true);
    });
    final file = File('${dir.path}${Platform.pathSeparator}migration.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    await DriftPlannedProjectsRepository(
      first,
      AppSettingsRepository(first),
    ).save(project('preserved'));
    await first.customStatement('DROP TABLE observation_session_images');
    await first.customStatement('DROP TABLE observation_sessions');
    await first.close();
    // Simulate a v5 release while preserving its original project row.
    // This intentionally uses raw SQL, not the current app migration path.
    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 5');
    raw.close();
    final reopened = AppDatabase(NativeDatabase(file));
    try {
      expect(
        (await reopened.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        6,
      );
      final projects = await DriftPlannedProjectsRepository(
        reopened,
        AppSettingsRepository(reopened),
      ).load();
      expect(projects.single.id, 'preserved');
      final sessions = DriftObservationSessionsRepository(
        reopened,
        attachments: MemoryImages(),
      );
      await sessions.save(session('new', 'preserved'));
      expect(await sessions.forProject('preserved'), hasLength(1));
    } finally {
      await reopened.close();
    }
  });
}
