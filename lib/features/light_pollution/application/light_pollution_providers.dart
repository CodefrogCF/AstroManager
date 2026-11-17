import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../locations/domain/models/observing_location.dart';
import '../data/arcgis_viirs_provider.dart';
import '../data/bortle_estimate_grid.dart';
import '../data/light_pollution_repository.dart';
import '../domain/light_pollution.dart';

final lightPollutionProvider = Provider<LightPollutionProvider>((ref) {
  final provider = ArcGisViirsProvider();
  ref.onDispose(provider.close);
  return provider;
});

final lightPollutionRepositoryProvider = Provider<LightPollutionRepository>((
  ref,
) {
  final repository = LightPollutionRepository(
    provider: ref.watch(lightPollutionProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// A family request is stable for a coordinate and independent of site ID.
typedef LightPollutionRequest = ({double latitude, double longitude});

LightPollutionRequest lightPollutionRequest(ObservingLocation site) =>
    (latitude: site.latitude, longitude: site.longitude);

final _bortleEstimateGridProvider = FutureProvider<BortleEstimateGrid>((
  ref,
) async {
  final bytes = await rootBundle.load('assets/light_pollution/bortle_2024.zip');
  return BortleEstimateGrid.fromZip(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
}, retry: (count, error) => null);

typedef BortleEstimate = ({int classCode, int datasetYear});

final bortleEstimateProvider = FutureProvider.autoDispose
    .family<BortleEstimate?, LightPollutionRequest>((ref, point) async {
      final grid = await ref.watch(_bortleEstimateGridProvider.future);
      final value = grid.classAt(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      return value == null
          ? null
          : (classCode: value, datasetYear: grid.datasetYear);
    }, retry: (count, error) => null);

final lightPollutionSnapshotProvider =
    FutureProvider.family<LightPollutionSnapshot, LightPollutionRequest>(
      (ref, point) => ref
          .watch(lightPollutionRepositoryProvider)
          .load(latitude: point.latitude, longitude: point.longitude),
      retry: (retryCount, error) => null,
    );

/// Rankings reuse a saved reading without starting a satellite request.
final cachedNightLightsProvider = FutureProvider.autoDispose
    .family<LightPollutionSnapshot?, LightPollutionRequest>((ref, point) async {
      try {
        final repository = ref.watch(lightPollutionRepositoryProvider);
        final subscription = repository
            .changesFor(latitude: point.latitude, longitude: point.longitude)
            .listen((_) => ref.invalidateSelf());
        ref.onDispose(subscription.cancel);
        return await repository.cachedOnly(
          latitude: point.latitude,
          longitude: point.longitude,
        );
      } catch (_) {
        // An unavailable cache is a missing input, not a ranking failure.
        return null;
      }
    }, retry: (count, error) => null);
