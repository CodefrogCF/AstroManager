import '../../light_pollution/data/light_pollution_repository.dart';
import '../../light_pollution/domain/light_pollution.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../terrain/data/terrain_profile_repository.dart';
import '../../terrain/domain/terrain_horizon.dart';

/// Read-only cached environmental context. Not a live site-quality score.
final class ObservingSiteConditions {
  const ObservingSiteConditions({
    required this.site,
    this.terrain,
    this.terrainStale = false,
    this.nightLights,
  });

  final ObservingLocation site;
  final TerrainHorizonProfile? terrain;
  final bool terrainStale;
  final LightPollutionSnapshot? nightLights;

  int get knownTerrainBearings => terrain?.knownBearings ?? 0;
  double? get terrainCoverage => terrain == null
      ? null
      : terrain!.knownBearings / terrain!.bearings.length;
  LightPollutionReading? get nightLightReading => nightLights?.reading;
}

/// Reads only local caches, not the underlying elevation or VIIRS services.
/// A cache failure from one source cannot suppress the other.
final class ObservingSiteConditionsReader {
  const ObservingSiteConditionsReader({
    required this.terrainRepository,
    required this.lightPollutionRepository,
  });
  final TerrainProfileRepository terrainRepository;
  final LightPollutionRepository lightPollutionRepository;

  Future<ObservingSiteConditions> read(ObservingLocation site) async {
    // Both repositories read local caches only. Independent failures must
    // never suppress the other data source, and neither read needs to block
    // the other (important when multiple dashboard widgets mount together).
    Future<({TerrainHorizonProfile profile, bool isStale})?>
    readTerrain() async {
      try {
        return await terrainRepository.cachedAnyForSite(site);
      } catch (_) {
        return null;
      }
    }

    Future<LightPollutionSnapshot?> readNightLights() async {
      try {
        return await lightPollutionRepository.cachedOnly(
          latitude: site.latitude,
          longitude: site.longitude,
        );
      } catch (_) {
        return null;
      }
    }

    final terrainFuture = readTerrain();
    final lightsFuture = readNightLights();
    final terrain = await terrainFuture;
    final lights = await lightsFuture;
    return ObservingSiteConditions(
      site: site,
      terrain: terrain?.profile,
      terrainStale: terrain?.isStale ?? false,
      nightLights: lights,
    );
  }
}
