import '../../locations/domain/models/observing_location.dart';
import '../../terrain/data/terrain_profile_repository.dart';
import '../../terrain/domain/terrain_horizon.dart';

/// Read-only cached environmental context. Not a live site-quality score.
final class ObservingSiteConditions {
  const ObservingSiteConditions({
    required this.site,
    this.terrain,
    this.terrainStale = false,
    this.terrainCacheUnreadable = false,
  });

  final ObservingLocation site;
  final TerrainHorizonProfile? terrain;
  final bool terrainStale;
  final bool terrainCacheUnreadable;

  int get knownTerrainBearings => terrain?.knownBearings ?? 0;
  double? get terrainCoverage => terrain == null
      ? null
      : terrain!.knownBearings / terrain!.bearings.length;
}

/// Reads the saved terrain profile for the selected observing site.
final class ObservingSiteConditionsReader {
  const ObservingSiteConditionsReader({required this.terrainRepository});
  final TerrainProfileRepository terrainRepository;

  Future<ObservingSiteConditions> read(ObservingLocation site) async {
    try {
      final cached = await terrainRepository.cachedAnyForSite(site);
      return ObservingSiteConditions(
        site: site,
        terrain: cached?.profile,
        terrainStale: cached?.isStale ?? false,
      );
    } catch (_) {
      return ObservingSiteConditions(site: site, terrainCacheUnreadable: true);
    }
  }
}
