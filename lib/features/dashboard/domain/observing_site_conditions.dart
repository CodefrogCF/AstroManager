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
    ({TerrainHorizonProfile profile, bool isStale})? terrain;
    LightPollutionSnapshot? lights;
    try {
      terrain = await terrainRepository.cachedAnyForSite(site);
    } catch (_) {
      // Unreadable or inaccessible cache is shown as unavailable.
    }
    try {
      lights = await lightPollutionRepository.cachedOnly(
        latitude: site.latitude,
        longitude: site.longitude,
      );
    } catch (_) {
      // The terrain status is still useful if the light cache is unavailable.
    }
    return ObservingSiteConditions(
      site: site,
      terrain: terrain?.profile,
      terrainStale: terrain?.isStale ?? false,
      nightLights: lights,
    );
  }
}
