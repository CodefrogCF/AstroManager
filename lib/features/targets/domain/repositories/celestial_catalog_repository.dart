import '../models/celestial_object.dart';

abstract interface class CelestialCatalogRepository {
  /// Imports a catalog if the stored version differs.
  Future<void> seedIfNeeded(CelestialCatalogBundle bundle);

  /// Returns the total number of catalog objects.
  Future<int> count();

  /// Searches the local SQLite database.
  Future<List<CelestialObject>> search({
    String query = '',
    CelestialCategory? category,
    int limit = 80,
  });

  /// Retrieves one object by its catalog identifier.
  Future<CelestialObject?> findById(String id);
}
