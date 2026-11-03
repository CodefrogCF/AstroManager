import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../light_pollution/application/light_pollution_providers.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../terrain/application/terrain_providers.dart';
import '../domain/observing_site_conditions.dart';

/// This family is only watched when the Observing Site tile is visible.
/// It never triggers remote calls, even when cached data is absent or stale.
final observingSiteConditionsProvider =
    FutureProvider.family<ObservingSiteConditions, ObservingLocation>((
      ref,
      site,
    ) {
      return ObservingSiteConditionsReader(
        terrainRepository: ref.watch(terrainProfileRepositoryProvider),
        lightPollutionRepository: ref.watch(lightPollutionRepositoryProvider),
      ).read(site);
    }, retry: (count, error) => null);
