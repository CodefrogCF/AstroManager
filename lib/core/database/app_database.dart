import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/app_settings.dart';
import 'tables/observing_locations.dart';
import 'tables/equipment_tables.dart';
import 'tables/celestial_catalog_entries.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppSettings,
    ObservingLocations,
    EquipmentItems,
    OpticalProfiles,
    CelestialCatalogEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },

    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= to || to > schemaVersion) {
        throw StateError('Unsupported database migration: $from -> $to');
      }

      // v1 -> v2: Observing locations.
      if (from < 2 && to >= 2) {
        await migrator.createTable(observingLocations);
      }

      // v2 -> v3: Equipment and optical profiles.
      if (from < 3 && to >= 3) {
        await migrator.createTable(equipmentItems);

        await migrator.createTable(opticalProfiles);
      }

      // v3 -> v4: Offline celestial catalog.
      if (from < 4 && to >= 4) {
        await migrator.createTable(celestialCatalogEntries);
      }
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
