import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/data/drift_celestial_catalog_repository.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../targets/domain/repositories/celestial_catalog_repository.dart';

abstract interface class DiscoveryCandidateSource {
  Future<List<CelestialObject>> load({
    required String query,
    required CelestialCategory? category,
    required Set<String> favoriteIds,
    required bool favoritesOnly,
    int limit = 24,
  });
}

/// Uses the local catalog only. Unfiltered discovery begins with bright
/// objects instead of the first 80 NGC designations alphabetically.
final class LocalDiscoveryCandidateSource implements DiscoveryCandidateSource {
  const LocalDiscoveryCandidateSource(this._repository, this._database);

  final CelestialCatalogRepository _repository;
  final AppDatabase _database;

  @override
  Future<List<CelestialObject>> load({
    required String query,
    required CelestialCategory? category,
    required Set<String> favoriteIds,
    required bool favoritesOnly,
    int limit = 24,
  }) async {
    if (limit < 1 || limit > 60) {
      throw ArgumentError.value(limit, 'limit', 'Expected 1..60');
    }
    final byId = <String, CelestialObject>{};
    bool matches(CelestialObject object) {
      if (category != null && object.category != category) return false;
      final text = query.trim().toLowerCase();
      if (text.isEmpty) return true;
      return [
        object.id,
        object.designation,
        object.displayTitle,
        object.commonNames,
        object.aliases,
      ].any((value) => value.toLowerCase().contains(text));
    }

    // Favorites are prioritized and remain discoverable even if they are not
    // part of the bright-first shortlist.
    for (final id in favoriteIds.toList()..sort()) {
      final object = await _repository.findById(id);
      if (object != null && matches(object)) byId[id] = object;
      if (byId.length >= limit) break;
    }
    if (!favoritesOnly && byId.length < limit) {
      final matches = query.trim().isNotEmpty
          ? await _repository.search(
              query: query,
              category: category,
              limit: 100,
            )
          : await DriftCelestialCatalogRepository(_database)
                .discoveryCandidates(category: category, limit: 100);
      for (final object in matches) {
        if (byId.length >= limit) break;
        byId.putIfAbsent(object.id, () => object);
      }
    }
    return byId.values.toList(growable: false);
  }
}

abstract interface class TargetFavoritesStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> identifiers);
}

/// Favorites reuse the existing key-value settings table: no migration.
final class SettingsTargetFavoritesStore implements TargetFavoritesStore {
  const SettingsTargetFavoritesStore(this._settings);

  static const key = 'discovery.favoriteTargetIds.v1';
  final AppSettingsRepository _settings;

  @override
  Future<Set<String>> load() async {
    final value = await _settings.get(key);
    if (value == null) return <String>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().where((id) => id.isNotEmpty).toSet();
    } on FormatException {
      return <String>{};
    }
  }

  @override
  Future<void> save(Set<String> identifiers) async {
    final sorted = identifiers.toList()..sort();
    await _settings.put(key, jsonEncode(sorted));
  }
}

final discoveryCandidateSourceProvider = Provider<DiscoveryCandidateSource>((
  ref,
) {
  return LocalDiscoveryCandidateSource(
    ref.watch(celestialCatalogRepositoryProvider),
    ref.watch(appDatabaseProvider),
  );
});

final targetFavoritesStoreProvider = Provider<TargetFavoritesStore>((ref) {
  return SettingsTargetFavoritesStore(
    AppSettingsRepository(ref.watch(appDatabaseProvider)),
  );
});
