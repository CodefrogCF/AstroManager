import 'package:astromanager/features/dashboard/domain/top_targets.dart';
import 'package:astromanager/features/discovery/domain/discovery_results.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = ObservingLocation(
  id: 'home',
  name: 'Home',
  latitude: 47.4,
  longitude: 8.3,
  elevationMeters: 450,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
CelestialObject object(String id) => CelestialObject(
  id: id,
  designation: id,
  category: CelestialCategory.galaxy,
  sourceType: 'test',
  raDegrees: 12,
  decDegrees: 60,
  constellation: 'And',
  commonNames: '',
  aliases: '',
);
PlannedImagingProject project(
  String id,
  List<String> ids, {
  ImagingProjectStatus status = ImagingProjectStatus.inProgress,
  String? locationId,
}) => PlannedImagingProject(
  id: id,
  title: id,
  targetIds: ids,
  createdAtUtc: DateTime.utc(2026),
  status: status,
  locationId: locationId,
);
RankedDiscoveryTarget ranked(
  String id,
  int points,
  DateTime endUtc, {
  bool provisional = false,
}) {
  final start = endUtc.subtract(const Duration(hours: 1));
  return RankedDiscoveryTarget(
    object: object(id),
    window: ObservationWindow(
      targetId: id,
      targetDesignation: id,
      startUtc: start,
      endUtc: endUtc,
      bestAltitudeDegrees: 50,
      bestAltitudeAtUtc: start,
      weatherStatus: provisional
          ? WindowWeatherStatus.missing
          : WindowWeatherStatus.complete,
      weatherTimeCoverage: provisional ? 0 : 1,
      weatherParameterCoverage: provisional ? 0 : 1,
      explanation: 'test',
      score: TargetSuitabilityScore(
        targetId: id,
        startUtc: start,
        endUtc: endUtc,
        score: points.toDouble(),
        dataCoverage: 1,
        isProvisional: provisional,
        visibleDuration: const Duration(hours: 1),
        astronomicalDarkDuration: const Duration(hours: 1),
        usableDuration: const Duration(hours: 1),
        bestUsableAltitudeDegrees: 50,
        factors: const {},
        constraints: const [],
      ),
    ),
  );
}

void main() {
  test('candidate scopes are stable, site-filtered and de-duplicated', () {
    final catalog = [object('a'), object('b'), object('c'), object('d')];
    final projects = [
      project('active', ['c', 'a'], locationId: 'home'),
      project('elsewhere', ['b'], locationId: 'other'),
      project('archived', ['d'], status: ImagingProjectStatus.archived),
    ];
    List<String> select(DashboardTargetSource source) =>
        DashboardTargetSelection.candidates(
          source: source,
          locationId: 'home',
          projects: projects,
          catalog: catalog,
          favorites: {'d', 'a'},
        ).map((item) => item.id).toList();
    expect(select(DashboardTargetSource.projects), ['a', 'c']);
    expect(select(DashboardTargetSource.favorites), ['a', 'd']);
    expect(select(DashboardTargetSource.catalog), ['a', 'b', 'c', 'd']);
    expect(select(DashboardTargetSource.combined), ['a', 'c', 'd', 'b']);
    expect(
      DashboardTargetSelection.candidates(
        source: DashboardTargetSource.combined,
        locationId: 'home',
        projects: projects,
        catalog: catalog,
        favorites: const {},
        limit: 2,
      ).length,
      2,
    );
  });

  test('top three is stable, unique and excludes elapsed windows', () {
    final now = DateTime.utc(2026, 11, 3, 18);
    final values = [
      ranked('d', 90, now.subtract(const Duration(minutes: 1))),
      ranked('b', 85, now.add(const Duration(hours: 5))),
      ranked('a', 85, now.add(const Duration(hours: 4))),
      ranked('c', 70, now.add(const Duration(hours: 6))),
      ranked('b', 60, now.add(const Duration(hours: 8))),
      ranked('e', 20, now.add(const Duration(hours: 9))),
    ];
    expect(
      DashboardTargetSelection.topThree(
        values,
        now,
      ).map((item) => item.object.id),
      ['a', 'b', 'c'],
    );
  });

  test(
    'observing-night date follows the site zone after midnight and dawn',
    () {
      // UTC+1: 00:30 on November 4 is still November 3's night.
      final duringDarkness = DashboardTargetSelection.currentNight(
        _site,
        DateTime.utc(2026, 11, 3, 23, 30),
      );
      expect(DashboardTargetSelection.nightKey(duringDarkness), '2026-11-03');
      final afterDawn = DashboardTargetSelection.currentNight(
        _site,
        DateTime.utc(2026, 11, 4, 10),
      );
      expect(DashboardTargetSelection.nightKey(afterDawn), '2026-11-04');
    },
  );
}
