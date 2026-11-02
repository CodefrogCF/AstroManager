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
  int get schemaVersion => 5;

  // Raw SQL avoids requiring generated Drift table code for this additive
  // migration. Projects are accessed with parameterised custom queries.
  Future<void> _createImagingProjectTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS imaging_projects (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        imaging_goal TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'planned'
          CHECK (status IN ('planned', 'inProgress', 'completed', 'archived')),
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        planned_integration_seconds INTEGER NOT NULL DEFAULT 0
          CHECK (planned_integration_seconds >= 0),
        observing_date TEXT,
        location_id TEXT,
        optical_profile_id TEXT,
        window_start_utc TEXT,
        window_end_utc TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS imaging_project_targets (
        project_id TEXT NOT NULL REFERENCES imaging_projects(id)
          ON DELETE CASCADE,
        target_id TEXT NOT NULL,
        PRIMARY KEY (project_id, target_id)
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS imaging_projects_status_idx
        ON imaging_projects(status, updated_at_utc)
    ''');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createImagingProjectTables();
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

      // v4 -> v5: normalised offline imaging projects and target links.
      if (from < 5 && to >= 5) {
        await _createImagingProjectTables();
      }
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
