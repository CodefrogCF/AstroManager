import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';

import '../data/catalog_asset_source.dart';
import '../data/drift_celestial_catalog_repository.dart';
import '../domain/models/celestial_object.dart';
import '../domain/repositories/celestial_catalog_repository.dart';

final celestialCatalogRepositoryProvider = Provider<CelestialCatalogRepository>(
  (ref) {
    final database = ref.watch(appDatabaseProvider);

    return DriftCelestialCatalogRepository(database);
  },
);

final catalogAssetSourceProvider = Provider<CatalogAssetSource>((ref) {
  return const BundledOpenNgcCatalogSource();
});

final celestialCatalogProvider =
    AsyncNotifierProvider<
      CelestialCatalogController,
      CelestialCatalogViewState
    >(CelestialCatalogController.new, retry: (retryCount, error) => null);

final class CelestialCatalogViewState {
  CelestialCatalogViewState({
    required this.totalObjects,
    required this.query,
    required this.category,
    required List<CelestialObject> results,
  }) : results = List.unmodifiable(results);

  final int totalObjects;
  final String query;
  final CelestialCategory? category;
  final List<CelestialObject> results;
}

class CelestialCatalogController
    extends AsyncNotifier<CelestialCatalogViewState> {
  int _searchRevision = 0;
  int? _totalObjects;

  @override
  Future<CelestialCatalogViewState> build() async {
    final repository = ref.watch(celestialCatalogRepositoryProvider);

    final assetSource = ref.watch(catalogAssetSourceProvider);

    final bundle = await assetSource.load();

    await repository.seedIfNeeded(bundle);

    final total = await repository.count();
    final initialResults = await repository.search();

    _totalObjects = total;

    return CelestialCatalogViewState(
      totalObjects: total,
      query: '',
      category: null,
      results: initialResults,
    );
  }

  Future<void> search({
    required String query,
    CelestialCategory? category,
  }) async {
    final total = _totalObjects;

    if (total == null) return;

    final revision = ++_searchRevision;

    state = const AsyncLoading();

    try {
      final repository = ref.read(celestialCatalogRepositoryProvider);

      final results = await repository.search(query: query, category: category);

      if (!ref.mounted || revision != _searchRevision) {
        return;
      }

      state = AsyncData(
        CelestialCatalogViewState(
          totalObjects: total,
          query: query,
          category: category,
          results: results,
        ),
      );
    } catch (error, stackTrace) {
      if (!ref.mounted || revision != _searchRevision) {
        return;
      }

      state = AsyncError(error, stackTrace);
    }
  }
}
