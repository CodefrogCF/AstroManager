import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';

void main() {
  group('AppSettingsRepository', () {
    late AppDatabase database;
    late AppSettingsRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());

      repository = AppSettingsRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('stores and retrieves a value', () async {
      await repository.put('test.location', 'Switzerland');

      final value = await repository.get('test.location');

      expect(value, 'Switzerland');
    });

    test('updates an existing value', () async {
      await repository.put('test.key', 'first');
      await repository.put('test.key', 'second');

      expect(await repository.get('test.key'), 'second');
    });

    test('deletes an existing value', () async {
      await repository.put('test.key', 'value');

      await repository.delete('test.key');

      expect(await repository.get('test.key'), isNull);
    });

    test('returns null for missing keys', () async {
      expect(await repository.get('missing.key'), isNull);
    });

    test('uses schema version 2', () async {
      await repository.put('schema.test', 'ok');

      final result = await database
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(result.read<int>('user_version'), 2);
    });
  });

  test('data survives closing and reopening a SQLite file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'astromanager_database_test_',
    );

    final file = File('${directory.path}${Platform.pathSeparator}test.sqlite');

    try {
      // First connection: write data.
      final firstDatabase = AppDatabase(NativeDatabase(file));

      try {
        final firstRepository = AppSettingsRepository(firstDatabase);

        await firstRepository.put('persistent.key', 'persistent.value');

        expect(await firstRepository.get('persistent.key'), 'persistent.value');
      } finally {
        await firstDatabase.close();
      }

      // Second connection: verify persistence.
      // The first database has already been closed.
      final reopenedDatabase = AppDatabase(NativeDatabase(file));

      try {
        final reopenedRepository = AppSettingsRepository(reopenedDatabase);

        expect(
          await reopenedRepository.get('persistent.key'),
          'persistent.value',
        );

        final result = await reopenedDatabase
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(result.read<int>('user_version'), 2);
      } finally {
        await reopenedDatabase.close();
      }
    } finally {
      // Clean up the temporary SQLite database.
      await directory.delete(recursive: true);
    }
  });
}
