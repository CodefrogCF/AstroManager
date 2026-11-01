import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/core/errors/app_failure.dart';

import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/features/settings/data/repositories/drift_app_preferences_repository.dart';
import 'package:astromanager/features/settings/domain/models/app_preferences.dart';
import 'package:astromanager/features/settings/domain/repositories/app_preferences_repository.dart';

class FakePreferencesRepository implements AppPreferencesRepository {
  AppPreferences current = AppPreferences.defaults;
  bool failSave = false;

  @override
  Future<AppPreferences> load() async => current;

  @override
  Future<void> save(AppPreferences preferences) async {
    if (failSave) {
      throw const StorageFailure('Simulated storage failure');
    }

    current = preferences;
  }
}

void main() {
  group('AppPreferences serialization', () {
    test('defaults are valid', () {
      expect(AppPreferences.defaults.units, MeasurementUnits.metric);

      expect(AppPreferences.defaults.clockFormat, ClockFormat.system);
    });

    test('JSON round-trip preserves settings', () {
      const original = AppPreferences(
        units: MeasurementUnits.imperial,
        clockFormat: ClockFormat.hour12,
        language: LanguagePreference.german,
      );

      final restored = AppPreferences.fromJson(original.toJson());

      expect(restored, original);
    });

    test('invalid enum is rejected', () {
      final invalid = {
        ...AppPreferences.defaults.toJson(),
        'units': 'invalid_unit',
      };

      expect(() => AppPreferences.fromJson(invalid), throwsFormatException);
    });

    test('unsupported format version is rejected', () {
      final invalid = {...AppPreferences.defaults.toJson(), 'version': 999};

      expect(() => AppPreferences.fromJson(invalid), throwsFormatException);
    });
  });

  group('Drift preferences persistence', () {
    late AppDatabase database;
    late AppSettingsRepository storage;
    late DriftAppPreferencesRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      storage = AppSettingsRepository(database);
      repository = DriftAppPreferencesRepository(storage);
    });

    tearDown(() async {
      await database.close();
    });

    test('missing settings return defaults', () async {
      final loaded = await repository.load();

      expect(loaded, AppPreferences.defaults);
    });

    test('settings survive repository recreation', () async {
      const preferences = AppPreferences(
        units: MeasurementUnits.imperial,
        clockFormat: ClockFormat.hour24,
        language: LanguagePreference.english,
      );

      await repository.save(preferences);

      final recreated = DriftAppPreferencesRepository(
        AppSettingsRepository(database),
      );

      expect(await recreated.load(), preferences);
    });

    test('corrupted JSON produces StorageFailure', () async {
      await storage.put(
        DriftAppPreferencesRepository.storageKey,
        '{invalid-json',
      );

      expect(repository.load(), throwsA(isA<StorageFailure>()));
    });

    test('invalid preferences produce StorageFailure', () async {
      await storage.put(
        DriftAppPreferencesRepository.storageKey,
        '{"version":1,"units":"unknown",'
        '"clockFormat":"system","language":"system"}',
      );

      expect(repository.load(), throwsA(isA<StorageFailure>()));
    });
  });

  group('Riverpod preferences controller', () {
    test('updates and persists measurement units', () async {
      final repository = FakePreferencesRepository();

      final container = ProviderContainer.test(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await container.read(appPreferencesProvider.future);

      await container
          .read(appPreferencesProvider.notifier)
          .setUnits(MeasurementUnits.imperial);

      expect(
        container.read(appPreferencesProvider).value?.units,
        MeasurementUnits.imperial,
      );

      expect(repository.current.units, MeasurementUnits.imperial);
    });

    test('failed save restores previous settings', () async {
      final repository = FakePreferencesRepository();

      final container = ProviderContainer.test(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await container.read(appPreferencesProvider.future);

      repository.failSave = true;

      await expectLater(
        container
            .read(appPreferencesProvider.notifier)
            .setClockFormat(ClockFormat.hour12),
        throwsA(isA<StorageFailure>()),
      );

      expect(
        container.read(appPreferencesProvider).value,
        AppPreferences.defaults,
      );
    });

    test('restore defaults overwrites preferences', () async {
      final repository = FakePreferencesRepository()
        ..current = const AppPreferences(
          units: MeasurementUnits.imperial,
          clockFormat: ClockFormat.hour12,
          language: LanguagePreference.german,
        );

      final container = ProviderContainer.test(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await container.read(appPreferencesProvider.future);

      await container.read(appPreferencesProvider.notifier).restoreDefaults();

      expect(repository.current, AppPreferences.defaults);
    });
  });
}
