import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../discovery/domain/discovery_results.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../projects/domain/planned_imaging_project.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../terrain/domain/terrain_horizon.dart';
import '../../weather/domain/models/weather_cache.dart';

/// Candidate policy is deliberately independent of the ranking engine.
enum DashboardTargetSource { combined, catalog, projects, favorites }

/// Immutable family key: changing the site, night or options produces a new
/// cache entry, while ordinary widget rebuilds reuse the same evaluation.
typedef TopTargetsQuery = ({
  String locationId,
  String nightDate,
  DashboardTargetSource source,
  int minimumDurationMinutes,
});

final class TopTargetsResult {
  const TopTargetsResult({
    required this.nightDate,
    required this.considered,
    required this.candidates,
    required this.ranked,
    this.weather,
    this.terrain,
    this.weatherError,
  });

  final DateTime nightDate;
  final int considered;
  final List<CelestialObject> candidates;
  final List<RankedDiscoveryTarget> ranked;
  final WeatherForecastSnapshot? weather;
  final TerrainHorizonProfile? terrain;
  final String? weatherError;
}

abstract final class DashboardTargetSelection {
  static const int maximumCandidates = 24;

  /// The chosen local observing night begins at noon. After local dawn the
  /// next night is selected; during post-midnight darkness the previous date
  /// is retained. This is independent of the device time zone and DST.
  static DateTime currentNight(ObservingLocation site, DateTime nowUtc) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc');
    }
    final local = tz.TZDateTime.from(
      nowUtc,
      SolarEvents.timeZone(site.timeZone),
    );
    final today = DateTime.utc(local.year, local.month, local.day);
    if (local.hour >= 12) {
      return today;
    }
    final yesterday = today.subtract(const Duration(days: 1));
    final prior = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: yesterday,
    );
    if (prior.astronomicalDarkness.any(
      (interval) =>
          interval.endUtc.isAfter(nowUtc) && !interval.startUtc.isAfter(nowUtc),
    )) {
      return yesterday;
    }
    return today;
  }

  static String nightKey(DateTime night) =>
      '${night.year.toString().padLeft(4, '0')}-'
      '${night.month.toString().padLeft(2, '0')}-'
      '${night.day.toString().padLeft(2, '0')}';

  /// Deterministic, de-duplicated selection. Prefer targets already linked to
  /// active projects, then favorites, followed by the local bright-first
  /// catalog. Unknown/deleted catalog links cannot become fake candidates.
  static List<CelestialObject> candidates({
    required DashboardTargetSource source,
    required String locationId,
    required List<PlannedImagingProject> projects,
    required Iterable<CelestialObject> catalog,
    required Set<String> favorites,
    int limit = maximumCandidates,
  }) {
    if (limit < 1 || limit > 60) {
      throw ArgumentError.value(limit, 'limit');
    }
    final catalogById = {for (final object in catalog) object.id: object};
    final selected = <String, CelestialObject>{};
    final projectIds = <String>{};
    for (final project in projects) {
      if (project.status != ImagingProjectStatus.planned &&
          project.status != ImagingProjectStatus.inProgress) {
        continue;
      }
      if (project.locationId != null && project.locationId != locationId) {
        continue;
      }
      projectIds.addAll(project.targetIds);
    }
    void addIds(Iterable<String> ids) {
      for (final id in ids) {
        final target = catalogById[id];
        if (target != null && selected.length < limit) {
          selected.putIfAbsent(id, () => target);
        }
      }
    }

    if (source == DashboardTargetSource.combined ||
        source == DashboardTargetSource.projects) {
      addIds(projectIds.toList()..sort());
    }
    if (source == DashboardTargetSource.combined ||
        source == DashboardTargetSource.favorites) {
      addIds(favorites.toList()..sort());
    }
    if (source == DashboardTargetSource.combined ||
        source == DashboardTargetSource.catalog) {
      addIds(catalogById.keys);
    }
    return List.unmodifiable(selected.values);
  }

  /// One recommendation per object. Existing Discovery ranking implements
  /// stable score, provisional, duration, time and target-id tie breaking.
  static List<RankedDiscoveryTarget> topThree(
    Iterable<RankedDiscoveryTarget> evaluated,
    DateTime nowUtc,
  ) {
    final unique = <String, RankedDiscoveryTarget>{};
    for (final value in rankDiscoveryTargets(evaluated)) {
      if (!value.window.endUtc.isAfter(nowUtc)) {
        continue;
      }
      unique.putIfAbsent(value.object.id, () => value);
      if (unique.length == 3) {
        break;
      }
    }
    return List.unmodifiable(unique.values);
  }
}
