import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/astronomy/solar_events.dart';
import '../../discovery/application/discovery_evaluator.dart';
import '../../discovery/data/discovery_repositories.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../projects/data/planned_projects_repository.dart';
import '../../projects/domain/planned_imaging_project.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../terrain/application/terrain_providers.dart';
import '../../terrain/domain/terrain_horizon.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../../weather/domain/providers/weather_provider.dart';
import '../domain/top_targets.dart';

/// Cache results by site/night/options while visible. Auto-dispose prevents
/// hidden dashboard widgets from running or retaining expensive evaluations.
final topTargetsProvider = FutureProvider.autoDispose
    .family<TopTargetsResult, TopTargetsQuery>((ref, query) async {
      final locationsFuture = ref.watch(observingLocationsProvider.future);
      final catalogFuture = ref.read(celestialCatalogProvider.future);
      final projectsFuture = ref.watch(plannedProjectsListProvider.future);
      final candidateSource = ref.watch(discoveryCandidateSourceProvider);
      ref.watch(targetFavoritesRevisionProvider);
      final favoritesStore = ref.watch(targetFavoritesStoreProvider);
      final evaluator = ref.watch(discoveryEvaluatorProvider);
      final terrainRepository = ref.watch(terrainProfileRepositoryProvider);
      final catalogRepository = ref.watch(celestialCatalogRepositoryProvider);

      final locations = await locationsFuture;
      final matching = locations.where((site) => site.id == query.locationId);
      if (matching.isEmpty) {
        throw StateError(
          'The selected observing location is no longer available.',
        );
      }
      final site = matching.first;
      final localDate = DateTime.tryParse(query.nightDate);
      if (localDate == null ||
          query.minimumDurationMinutes < 30 ||
          query.minimumDurationMinutes > 180) {
        throw const FormatException('Invalid target recommendation options.');
      }
      await catalogFuture; // Ensure the bundled offline catalog is initialized.
      final projects = await projectsFuture;
      final favorites = await favoritesStore.load();
      final candidates = <CelestialObject>[
        ...await candidateSource.load(
          query: '',
          category: null,
          favoriteIds: favorites,
          favoritesOnly: false,
          limit: 60,
        ),
      ];
      // Projects may reference objects outside the discovery shortlist. Resolve
      // those via the existing local repository, never a network catalog.
      final seen = {for (final object in candidates) object.id};
      for (final project in projects) {
        if (project.status != ImagingProjectStatus.planned &&
            project.status != ImagingProjectStatus.inProgress) {
          continue;
        }
        if (project.locationId != null && project.locationId != site.id) {
          continue;
        }
        for (final id in project.targetIds) {
          if (seen.add(id)) {
            final object = await catalogRepository.findById(id);
            if (object != null) {
              candidates.add(object);
            }
          }
        }
      }
      for (final id in favorites) {
        if (seen.add(id)) {
          final object = await catalogRepository.findById(id);
          if (object != null) {
            candidates.add(object);
          }
        }
      }
      final chosen = DashboardTargetSelection.candidates(
        source: query.source,
        locationId: site.id,
        projects: projects,
        catalog: candidates,
        favorites: favorites,
      );
      if (chosen.isEmpty) {
        return TopTargetsResult(
          nightDate: localDate,
          considered: 0,
          candidates: chosen,
          ranked: const [],
        );
      }
      final night = SolarEvents.calculateForLocalDate(
        location: site,
        localDate: localDate,
      );
      final now = DateTime.now().toUtc();
      WeatherForecastSnapshot? weather;
      String? weatherError;
      // Existing weather cache/provider performs freshness checks. Offline or
      // unsupported forecasts yield deliberately provisional astronomy scores.
      if (night.nightEndUtc.isAfter(now) &&
          night.nightStartUtc.isBefore(now.add(const Duration(days: 14)))) {
        try {
          weather = await ref.read(
            weatherForecastSnapshotProvider(
              WeatherForecastRequest(
                latitudeDegrees: site.latitude,
                longitudeDegrees: site.longitude,
                startUtc: night.nightStartUtc,
                endUtc: night.nightEndUtc,
              ),
            ).future,
          );
        } catch (error) {
          weatherError = error.toString();
        }
      } else {
        weatherError = 'No current forecast covers this observing night.';
      }
      TerrainHorizonProfile? terrain;
      try {
        terrain = await terrainRepository.cached(
          site,
          const TerrainHorizonOptions(),
        );
      } catch (_) {
        // Terrain data is optional. Never fetch a new network terrain profile
        // just because the dashboard becomes visible.
      }
      final evaluated = await evaluator.evaluate(
        targets: chosen,
        location: site,
        localDate: localDate,
        evaluatedAtUtc: now,
        minimumDurationMinutes: query.minimumDurationMinutes,
        minimumAltitudeDegrees: 30,
        weather: weather,
        optics: null,
        isCurrent: () => ref.mounted,
      );
      if (!ref.mounted) {
        throw StateError('Recommendation evaluation cancelled.');
      }
      return TopTargetsResult(
        nightDate: localDate,
        considered: chosen.length,
        candidates: chosen,
        ranked: DashboardTargetSelection.topThree(evaluated, now),
        weather: weather,
        terrain: terrain,
        weatherError: weatherError,
      );
    }, retry: (count, error) => null);
