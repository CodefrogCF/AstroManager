import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';

import 'package:astromanager/features/locations/data/repositories/drift_observing_location_repository.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';

import 'package:astromanager/features/equipment/data/repositories/drift_equipment_repository.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';

void main() {
  test('migration v2 to v5 preserves existing data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'astromanager_equipment_migration_',
    );

    final file = File(
      '${directory.path}${Platform.pathSeparator}migration.sqlite',
    );

    try {
      final originalDatabase = AppDatabase(NativeDatabase(file));

      try {
        final settings = AppSettingsRepository(originalDatabase);

        await settings.put('migration.setting', 'keep-this-value');

        final locations = DriftObservingLocationRepository(originalDatabase);

        await locations.save(
          const ObservingLocation(
            id: 'location-1',
            name: 'Existing Observatory',
            latitude: 47.48,
            longitude: 8.21,
            elevationMeters: 400,
            timeZone: 'Europe/Zurich',
            isDefault: false,
          ),
        );

        // Construct a simulated v2 database.
        // Only temporary test data is affected.
        // The simulated legacy schema must not contain v5 project tables.
        await originalDatabase.customStatement(
          'DROP TABLE imaging_project_targets',
        );
        await originalDatabase.customStatement('DROP TABLE imaging_projects');

        await originalDatabase.customStatement(
          'DROP TABLE celestial_catalog_entries',
        );

        await originalDatabase.customStatement('DROP TABLE optical_profiles');

        await originalDatabase.customStatement('DROP TABLE equipment_items');

        await originalDatabase.customStatement('PRAGMA user_version = 2');
      } finally {
        await originalDatabase.close();
      }

      final migratedDatabase = AppDatabase(NativeDatabase(file));

      try {
        final settings = AppSettingsRepository(migratedDatabase);

        final locations = DriftObservingLocationRepository(migratedDatabase);

        final equipment = DriftEquipmentRepository(migratedDatabase);

        expect(await settings.get('migration.setting'), 'keep-this-value');

        final savedLocations = await locations.getAll();

        expect(savedLocations, hasLength(1));
        expect(savedLocations.first.name, 'Existing Observatory');
        expect(savedLocations.first.isDefault, isTrue);

        expect((await equipment.load()).items, isEmpty);

        await equipment.saveItem(
          const EquipmentItem(
            id: 'new-camera',
            name: 'Camera After Migration',
            kind: EquipmentKind.camera,
            sensorWidthMm: 36,
            sensorHeightMm: 24,
            resolutionX: 6000,
            resolutionY: 4000,
          ),
        );

        expect((await equipment.load()).cameras, hasLength(1));

        final version = await migratedDatabase
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(version.read<int>('user_version'), 6);

        final projectTables = await migratedDatabase
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('imaging_projects', 'imaging_project_targets')",
            )
            .get();
        expect(projectTables, hasLength(2));
      } finally {
        await migratedDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
