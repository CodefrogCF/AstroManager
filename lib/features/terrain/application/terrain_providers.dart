import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../locations/domain/models/observing_location.dart';
import '../data/open_topo_data_provider.dart';
import '../data/terrain_profile_repository.dart';
import '../domain/terrain_horizon.dart';

final terrainElevationProvider = Provider<TerrainElevationProvider>((ref) {
  final provider = OpenTopoDataElevationProvider();
  ref.onDispose(provider.close);
  return provider;
});

final terrainProfileRepositoryProvider = Provider<TerrainProfileRepository>(
  (ref) =>
      TerrainProfileRepository(provider: ref.watch(terrainElevationProvider)),
);

/// A record is used to give the provider stable family equality semantics.
typedef TerrainRequest = ({
  ObservingLocation site,
  int azimuthStep,
  int rangeMeters,
  int distanceStep,
});

final terrainHorizonProvider =
    FutureProvider.family<TerrainHorizonProfile, TerrainRequest>(
      (ref, request) => ref
          .watch(terrainProfileRepositoryProvider)
          .load(
            request.site,
            TerrainHorizonOptions(
              azimuthStepDegrees: request.azimuthStep,
              maximumDistanceMeters: request.rangeMeters,
              distanceStepMeters: request.distanceStep,
            ),
          ),
      retry: (count, error) => null,
    );
