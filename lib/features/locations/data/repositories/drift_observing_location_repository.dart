import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/observing_location.dart';
import '../../domain/repositories/observing_location_repository.dart';

final class DriftObservingLocationRepository
    implements ObservingLocationRepository {
  const DriftObservingLocationRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<ObservingLocation>> getAll() async {
    final rows = await _database.select(_database.observingLocations).get();

    final sorted = [...rows]
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return sorted.map(_mapRow).toList(growable: false);
  }

  @override
  Future<void> save(ObservingLocation location) async {
    location.validate();

    await _database.transaction(() async {
      final table = _database.observingLocations;

      final existing = await (_database.select(
        table,
      )..where((row) => row.id.equals(location.id))).getSingleOrNull();

      final allRows = await _database.select(table).get();

      // The first saved location becomes the default.
      // Editing an existing default must preserve that status.
      final makeDefault =
          allRows.isEmpty ||
          location.isDefault ||
          (existing?.isDefault ?? false);

      if (makeDefault) {
        await _database
            .update(table)
            .write(const ObservingLocationsCompanion(isDefault: Value(false)));
      }

      await _database
          .into(table)
          .insertOnConflictUpdate(
            ObservingLocationsCompanion.insert(
              id: location.id,
              name: location.name.trim(),
              latitude: location.latitude,
              longitude: location.longitude,
              elevationMeters: location.elevationMeters,
              timeZone: location.timeZone.trim(),
              isDefault: Value(makeDefault),
            ),
          );
    });
  }

  @override
  Future<void> setDefault(String id) async {
    await _database.transaction(() async {
      final table = _database.observingLocations;

      final target = await (_database.select(
        table,
      )..where((row) => row.id.equals(id))).getSingleOrNull();

      if (target == null) {
        throw StateError('Observing location not found.');
      }

      await _database
          .update(table)
          .write(const ObservingLocationsCompanion(isDefault: Value(false)));

      await (_database.update(table)..where((row) => row.id.equals(id))).write(
        const ObservingLocationsCompanion(isDefault: Value(true)),
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      final table = _database.observingLocations;

      final target = await (_database.select(
        table,
      )..where((row) => row.id.equals(id))).getSingleOrNull();

      if (target == null) return;

      await (_database.delete(table)..where((row) => row.id.equals(id))).go();

      // Keep exactly one default if any locations remain.
      if (target.isDefault) {
        final remaining = await _database.select(table).get();

        if (remaining.isNotEmpty) {
          remaining.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

          await (_database.update(table)
                ..where((row) => row.id.equals(remaining.first.id)))
              .write(const ObservingLocationsCompanion(isDefault: Value(true)));
        }
      }
    });
  }

  ObservingLocation _mapRow(ObservingLocationRow row) {
    return ObservingLocation(
      id: row.id,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
      elevationMeters: row.elevationMeters,
      timeZone: row.timeZone,
      isDefault: row.isDefault,
    );
  }
}
