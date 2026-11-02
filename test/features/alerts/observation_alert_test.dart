import 'dart:convert';
import 'dart:io';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/features/backup/data/backup_service.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/alerts/data/observation_alert_store.dart';
import 'package:astromanager/features/alerts/domain/observation_alert.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const rule = ObservationAlertRule(
  id: 'alert1',
  targetId: 'M31',
  targetName: 'Andromeda',
  locationId: 'site1',
  minimumScore: 75,
  minimumDurationMinutes: 90,
);

void main() {
  test('defaults to opt-in disabled and validates thresholds', () {
    expect(ObservationAlertState().enabled, isFalse);
    expect(
      () => const ObservationAlertRule(
        id: '1',
        targetId: 'x',
        targetName: 'X',
        locationId: 'loc',
        minimumScore: 101,
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const ObservationAlertRule(
        id: '1',
        targetId: 'x',
        targetName: 'X',
        locationId: 'loc',
        minimumDurationMinutes: 10,
      ).validate(),
      throwsFormatException,
    );
  });

  test(
    'versioned state preserves UTC delivery ledger and rejects bad versions',
    () {
      final delivered = DateTime.utc(2026, 11, 2, 18);
      final state = ObservationAlertState(
        enabled: true,
        rules: [rule],
        delivered: {'alert1|night': delivered},
      );
      final restored = ObservationAlertState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored.enabled, true);
      expect(restored.rules.single.minimumDurationMinutes, 90);
      expect(restored.delivered['alert1|night'], delivered);
      expect(
        () => ObservationAlertState.fromJson({...state.toJson(), 'version': 2}),
        throwsFormatException,
      );
    },
  );

  test(
    'alert rules and duplicate ledger survive a real SQLite reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('alerts-test-');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final file = File('${dir.path}/test.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      final store = SettingsObservationAlertStore(AppSettingsRepository(db));
      expect((await store.load()).enabled, isFalse);
      final value = ObservationAlertState(
        enabled: true,
        rules: [rule],
        delivered: {'a': DateTime.utc(2026, 11, 2)},
      );
      await store.save(value);
      final restored = await SettingsObservationAlertStore(
        AppSettingsRepository(db),
      ).load();
      expect(restored.rules.single.targetId, 'M31');
      expect(restored.delivered.length, 1);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final reopened = await SettingsObservationAlertStore(
        AppSettingsRepository(db),
      ).load();
      expect(reopened.rules.single.minimumScore, 75);
      expect(reopened.delivered['a'], DateTime.utc(2026, 11, 2));
      await db.close();
    },
  );

  test(
    '.ambackup round-trip restores alert rules and delivery history',
    () async {
      final original = AppDatabase(NativeDatabase.memory());
      final store = SettingsObservationAlertStore(
        AppSettingsRepository(original),
      );
      await store.save(
        ObservationAlertState(
          enabled: true,
          rules: [rule],
          delivered: {'alert1|night': DateTime.utc(2026, 11, 2)},
        ),
      );
      final backup = await AstroBackupService(original).export();
      await original.close();
      final restoredDb = AppDatabase(NativeDatabase.memory());
      addTearDown(restoredDb.close);
      await AstroBackupService(restoredDb).restore(backup);
      final restored = await SettingsObservationAlertStore(
        AppSettingsRepository(restoredDb),
      ).load();
      expect(restored.enabled, isTrue);
      expect(restored.rules.single.targetId, 'M31');
      expect(restored.delivered.keys, contains('alert1|night'));
    },
  );
}
