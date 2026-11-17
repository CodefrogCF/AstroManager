import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final terrainRepository = ref.watch(terrainProfileRepositoryProvider);
      final changes = terrainRepository
          .changesFor(site)
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return ObservingSiteConditionsReader(terrainRepository: terrainRepository)
          .read(site);
    }, retry: (count, error) => null);
