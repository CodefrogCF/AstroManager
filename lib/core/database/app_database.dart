import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/app_settings.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Allows dependency injection of a custom executor.
  ///
  /// Unit tests can provide an in-memory SQLite database.
  AppDatabase(super.executor);

  /// Default database for Android, iOS, desktop and web.
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },

    // Future schema upgrades will use generated
    // step-by-step migrations.
    onUpgrade: (migrator, from, to) async {
      throw StateError(
        'Missing database migration from '
        'schema version $from to $to.',
      );
    },

    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
