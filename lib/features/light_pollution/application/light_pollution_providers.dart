import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../locations/domain/models/observing_location.dart';
import '../data/arcgis_viirs_provider.dart';
import '../data/light_pollution_repository.dart';
import '../domain/light_pollution.dart';

final lightPollutionProvider = Provider<LightPollutionProvider>((ref) {
  final provider = ArcGisViirsProvider();
  ref.onDispose(provider.close);
  return provider;
});

final lightPollutionRepositoryProvider = Provider<LightPollutionRepository>(
  (ref) =>
      LightPollutionRepository(provider: ref.watch(lightPollutionProvider)),
);

/// A family request is stable for a coordinate and independent of site ID.
typedef LightPollutionRequest = ({double latitude, double longitude});

LightPollutionRequest lightPollutionRequest(ObservingLocation site) =>
    (latitude: site.latitude, longitude: site.longitude);

final lightPollutionSnapshotProvider =
    FutureProvider.family<LightPollutionSnapshot, LightPollutionRequest>(
      (ref, point) => ref
          .watch(lightPollutionRepositoryProvider)
          .load(latitude: point.latitude, longitude: point.longitude),
      retry: (retryCount, error) => null,
    );
