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

final terrainProfileRepositoryProvider = Provider<TerrainProfileRepository>((
  ref,
) {
  final repository = TerrainProfileRepository(
    provider: ref.watch(terrainElevationProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final cachedTerrainProfileProvider = FutureProvider.autoDispose
    .family<
      ({TerrainHorizonProfile profile, bool isStale})?,
      ObservingLocation
    >((ref, site) {
      final repository = ref.watch(terrainProfileRepositoryProvider);
      final changes = repository
          .changesFor(site)
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.cachedAnyForSite(site);
    }, retry: (count, error) => null);

/// A record is used to give the provider stable family equality semantics.
typedef TerrainRequest = ({
  ObservingLocation site,
  int azimuthStep,
  int rangeMeters,
  int distanceStep,
});

final terrainHorizonProvider = AsyncNotifierProvider.autoDispose
    .family<TerrainHorizonController, TerrainHorizonProfile, TerrainRequest>(
      TerrainHorizonController.new,
      retry: (count, error) => null,
    );

final class TerrainHorizonController
    extends AsyncNotifier<TerrainHorizonProfile> {
  TerrainHorizonController(this.request);

  final TerrainRequest request;

  TerrainHorizonOptions get _options => TerrainHorizonOptions(
    azimuthStepDegrees: request.azimuthStep,
    maximumDistanceMeters: request.rangeMeters,
    distanceStepMeters: request.distanceStep,
  );

  @override
  Future<TerrainHorizonProfile> build() =>
      ref.watch(terrainProfileRepositoryProvider).load(request.site, _options);

  Future<void> refreshProfile() async {
    if (state.isLoading) return;
    final refreshRef = ref;
    final repository = refreshRef.read(terrainProfileRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => repository.load(request.site, _options, forceRefresh: true),
    );
    if (refreshRef.mounted) state = result;
  }
}
