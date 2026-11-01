import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/app_settings.dart';
import 'tables/observing_locations.dart';
import 'tables/equipment_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [AppSettings, ObservingLocations, EquipmentItems, OpticalProfiles],
)
class AppDatabase extends _$AppDatabase {
  /// Constructor for tests and dependency injection.
  AppDatabase(super.executor);

  /// Platform-aware persistent SQLite database.
  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'astromanager',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },

    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= to || to > schemaVersion) {
        throw StateError('Unsupported database migration: $from -> $to');
      }

      // v1 -> v2:
      // Add observing locations.
      //
      // This step is also executed for direct
      // upgrades from v1 to v3.
      if (from < 2 && to >= 2) {
        await migrator.createTable(observingLocations);
      }

      // v2 -> v3:
      // Add equipment inventory and optical profiles.
      //
      // These tables are not created when a migration
      // test explicitly targets schema version 2.
      if (from < 3 && to >= 3) {
        await migrator.createTable(equipmentItems);

        await migrator.createTable(opticalProfiles);
      }
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
