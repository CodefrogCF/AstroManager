import 'package:drift/drift.dart';

// Persistent key-value entries for application configuration.
//
// Theme selection remains in SharedPreferences because it
// needs to be available before the application starts.
class AppSettings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 128)();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
