import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/errors/app_failure.dart';

import '../domain/models/celestial_object.dart';
import '../domain/repositories/celestial_catalog_repository.dart';

final class DriftCelestialCatalogRepository
    implements CelestialCatalogRepository {
  const DriftCelestialCatalogRepository(this._database);

  static const _versionKey = 'catalog.openngc.version';

  final AppDatabase _database;

  @override
  Future<void> seedIfNeeded(CelestialCatalogBundle bundle) async {
    if (bundle.version.isEmpty || bundle.objects.isEmpty) {
      throw const ValidationFailure('The bundled celestial catalog is empty.');
    }

    final ids = <String>{};

    for (final object in bundle.objects) {
      object.validate();

      if (!ids.add(object.id)) {
        throw const ValidationFailure(
          'The bundled celestial catalog contains duplicate IDs.',
        );
      }
    }

    final settings = AppSettingsRepository(_database);
    final storedVersion = await settings.get(_versionKey);

    if (storedVersion == bundle.version &&
        await count() == bundle.objects.length) {
      return;
    }

    await _database.transaction(() async {
      // Upsert avoids deleting existing catalog identifiers.
      // Future user-generated references can stay separate.
      const chunkSize = 400;

      for (var start = 0; start < bundle.objects.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, bundle.objects.length);

        final companions = bundle.objects
            .sublist(start, end)
            .map(_toCompanion)
            .toList(growable: false);

        await _database.batch((batch) {
          batch.insertAllOnConflictUpdate(
            _database.celestialCatalogEntries,
            companions,
          );
        });
      }

      // The marker is written only after all rows succeeded.
      await settings.put(_versionKey, bundle.version);
    });
  }

  @override
  Future<int> count() async {
    final result = await _database
        .customSelect(
          'SELECT COUNT(*) AS total '
          'FROM celestial_catalog_entries',
        )
        .getSingle();

    return result.read<int>('total');
  }

  @override
  Future<List<CelestialObject>> search({
    String query = '',
    CelestialCategory? category,
    int limit = 80,
  }) async {
    final table = _database.celestialCatalogEntries;
    final statement = _database.select(table);

    if (category != null) {
      statement.where((row) => row.category.equals(category.name));
    }

    // Remove LIKE wildcards supplied by the user.
    // Other characters remain ordinary search text.
    final searchText = query.trim().replaceAll(RegExp(r'[%_]'), '');

    if (searchText.isNotEmpty) {
      final pattern = '%$searchText%';

      statement.where(
        (row) =>
            row.id.like(pattern) |
            row.designation.like(pattern) |
            row.commonNames.like(pattern) |
            row.aliases.like(pattern),
      );
    }

    statement.orderBy([(row) => OrderingTerm.asc(row.designation)]);

    statement.limit(limit.clamp(1, 100));

    final rows = await statement.get();

    return rows.map(_fromRow).toList(growable: false);
  }

  /// A bounded, bright-first catalog shortlist for interactive discovery.
  /// Null magnitudes always sort after known magnitudes. This does not
  /// replace the full offline catalog search used by the Targets browser.
  Future<List<CelestialObject>> discoveryCandidates({
    CelestialCategory? category,
    int limit = 80,
  }) async {
    final statement = _database.select(_database.celestialCatalogEntries);
    if (category != null) {
      statement.where((row) => row.category.equals(category.name));
    }
    statement.orderBy([
      (row) => OrderingTerm.asc(row.visualMagnitude.isNull()),
      (row) => OrderingTerm.asc(row.visualMagnitude),
      (row) => OrderingTerm.asc(row.designation),
    ]);
    statement.limit(limit.clamp(1, 100));
    return (await statement.get()).map(_fromRow).toList(growable: false);
  }

  @override
  Future<CelestialObject?> findById(String id) async {
    final statement = _database.select(_database.celestialCatalogEntries)
      ..where((row) => row.id.equals(id));

    final row = await statement.getSingleOrNull();

    return row == null ? null : _fromRow(row);
  }

  CelestialCatalogEntriesCompanion _toCompanion(CelestialObject object) {
    return CelestialCatalogEntriesCompanion.insert(
      id: object.id,
      designation: object.designation,
      category: object.category.name,
      sourceType: object.sourceType,
      raDegrees: object.raDegrees,
      decDegrees: object.decDegrees,
      constellation: object.constellation,
      visualMagnitude: Value(object.visualMagnitude),
      majorAxisArcmin: Value(object.majorAxisArcmin),
      minorAxisArcmin: Value(object.minorAxisArcmin),
      messierNumber: Value(object.messierNumber),
      commonNames: Value(object.commonNames),
      aliases: Value(object.aliases),
    );
  }

  CelestialObject _fromRow(CelestialCatalogEntryRow row) {
    return CelestialObject(
      id: row.id,
      designation: row.designation,
      category: CelestialCategory.values.byName(row.category),
      sourceType: row.sourceType,
      raDegrees: row.raDegrees,
      decDegrees: row.decDegrees,
      constellation: row.constellation,
      visualMagnitude: row.visualMagnitude,
      majorAxisArcmin: row.majorAxisArcmin,
      minorAxisArcmin: row.minorAxisArcmin,
      messierNumber: row.messierNumber,
      commonNames: row.commonNames,
      aliases: row.aliases,
    );
  }
}
