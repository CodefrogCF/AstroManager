import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/app_settings.dart';
import 'tables/observing_locations.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettings, ObservingLocations])
class AppDatabase extends _$AppDatabase {
  /// Constructor for tests and dependency injection.
  AppDatabase(super.executor);

  /// Default database for supported Flutter platforms.
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },

    onUpgrade: (migrator, from, to) async {
      if (from == 1 && to == 2) {
        await migrator.createTable(observingLocations);
        return;
      }

      throw StateError('Unsupported database migration: $from -> $to');
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
