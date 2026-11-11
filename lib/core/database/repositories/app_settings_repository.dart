import '../app_database.dart';

class AppSettingsRepository {
  const AppSettingsRepository(this._database);

  final AppDatabase _database;

  Future<T> transaction<T>(Future<T> Function() action) =>
      _database.transaction(action);

  /// Reads a stored value by key.
  ///
  /// Returns null if the key does not exist.
  Future<String?> get(String key) async {
    final query = _database.select(_database.appSettings)
      ..where((table) => table.key.equals(key));

    final entry = await query.getSingleOrNull();

    return entry?.value;
  }

  /// Inserts or updates a value.
  Future<void> put(String key, String value) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  /// Deletes a stored entry.
  Future<void> delete(String key) async {
    await (_database.delete(
      _database.appSettings,
    )..where((table) => table.key.equals(key))).go();
  }
}
