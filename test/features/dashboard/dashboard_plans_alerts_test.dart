import 'package:astromanager/features/alerts/data/observation_alert_store.dart';
import 'package:astromanager/features/alerts/domain/observation_alert.dart';
import 'package:astromanager/features/dashboard/application/dashboard_plans_provider.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_plans_and_alerts.dart';
import 'package:astromanager/features/dashboard/presentation/dashboard_widget_registry.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/planner/data/night_plans_repository.dart';
import 'package:astromanager/features/planner/domain/night_observation_block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const site = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.4,
  longitude: 8.5,
  elevationMeters: 420,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

NightObservationBlock planned(
  String id,
  DateTime start,
  DateTime end, {
  String night = '2026-10-24',
  String locationId = 'zurich',
}) => NightObservationBlock(
  id: id,
  locationId: locationId,
  nightDate: night,
  timeZoneId: 'Europe/Zurich',
  projectId: 'project',
  targetId: id,
  projectName: 'Project',
  targetName: 'Target $id',
  startUtc: start,
  endUtc: end,
);

final class FakeNightPlansRepository implements NightPlansRepository {
  final data = <NightPlanKey, List<NightObservationBlock>>{};
  final fetched = <NightPlanKey>[];
  @override
  Future<List<NightObservationBlock>> forNight(NightPlanKey key) async {
    fetched.add(key);
    return List.unmodifiable(data[key] ?? const []);
  }

  @override
  Future<void> save(NightObservationBlock block) async {
    final key = NightPlanKey(block.locationId, block.nightDate);
    data.putIfAbsent(key, () => []).add(block);
  }

  @override
  Future<void> remove(NightPlanKey key, String id) async {
    data[key]?.removeWhere((entry) => entry.id == id);
  }
}

void main() {
  test('planner and alert widgets are registered independently', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(dashboardWidgetRegistryProvider);
    final plans = registry.byType('upcoming-plans');
    final alerts = registry.byType('observation-alerts');
    expect(plans, isNotNull);
    expect(alerts, isNotNull);
    expect(
      plans!.settings.map((entry) => entry.key),
      containsAll(['horizonNights', 'limit']),
    );
    expect(
      alerts!.settings.map((entry) => entry.key),
      containsAll(['limit', 'showHistory']),
    );
  });

  test('local-noon night keys cross midnight and DST without duplicates', () {
    expect(
      DashboardUpcomingPlans.dateKey(
        DashboardUpcomingPlans.currentNight(
          site,
          DateTime.utc(2026, 10, 25, 8),
        ),
      ),
      '2026-10-24',
    );
    final keys = DashboardUpcomingPlans.keys(
      locationId: site.id,
      firstNight: DateTime.utc(2026, 10, 24),
      nights: 3,
    );
    expect(keys.map((key) => key.nightDate), [
      '2026-10-24',
      '2026-10-25',
      '2026-10-26',
    ]);
    expect(
      () => DashboardUpcomingPlans.keys(
        locationId: site.id,
        firstNight: DateTime.utc(2026),
        nights: 15,
      ),
      throwsArgumentError,
    );
  });

  test('upcoming plans sort by UTC, exclude ended and highlight overlaps', () {
    final first = planned(
      'a',
      DateTime.utc(2026, 10, 24, 22),
      DateTime.utc(2026, 10, 25, 1),
    );
    final overlap = planned(
      'b',
      DateTime.utc(2026, 10, 25, 0),
      DateTime.utc(2026, 10, 25, 2),
    );
    final later = planned(
      'c',
      DateTime.utc(2026, 10, 25, 2),
      DateTime.utc(2026, 10, 25, 4),
    );
    final otherSite = planned(
      'd',
      DateTime.utc(2026, 10, 25, 0),
      DateTime.utc(2026, 10, 25, 2),
      locationId: 'elsewhere',
    );
    final ended = planned(
      'old',
      DateTime.utc(2026, 10, 24, 15),
      DateTime.utc(2026, 10, 24, 17),
    );
    final result = DashboardUpcomingPlans.aggregate(
      blocks: [later, otherSite, ended, overlap, first],
      nowUtc: DateTime.utc(2026, 10, 24, 21),
    );
    expect(result.map((e) => e.block.id), ['a', 'b', 'd', 'c']);
    expect(result.first.conflictingIds, {'b'});
    expect(result[1].conflictingIds, {'a'});
    expect(result[2].hasConflict, false);
    expect(result.last.hasConflict, false); // touching half-open bounds
  });

  test('dashboard provider observes existing per-night repository', () async {
    final fake = FakeNightPlansRepository();
    final firstNight = DateTime.utc(2026, 10, 24);
    final key = NightPlanKey('zurich', '2026-10-24');
    fake.data[key] = [
      planned(
        'a',
        DateTime.utc(2026, 10, 24, 22),
        DateTime.utc(2026, 10, 25, 1),
      ),
    ];
    final container = ProviderContainer(
      overrides: [nightPlansRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final request = (locationId: 'zurich', firstNight: firstNight, nights: 3);
    final first = await container.read(
      dashboardUpcomingPlansProvider(request).future,
    );
    expect(first.map((e) => e.id), ['a']);
    expect(fake.fetched.length, 3);
    fake.data[key]!.add(
      planned(
        'b',
        DateTime.utc(2026, 10, 25, 1),
        DateTime.utc(2026, 10, 25, 3),
      ),
    );
    container.invalidate(nightPlansProvider(key));
    final next = await container.read(
      dashboardUpcomingPlansProvider(request).future,
    );
    expect(next.length, 2);
  });

  test(
    'alerts distinguish enabled rules from delivered notification history',
    () {
      const enabled = ObservationAlertRule(
        id: 'enabled',
        targetId: 'm31',
        targetName: 'M31',
        locationId: 'zurich',
      );
      const disabled = ObservationAlertRule(
        id: 'disabled',
        targetId: 'm42',
        targetName: 'M42',
        locationId: 'zurich',
        enabled: false,
      );
      const foreign = ObservationAlertRule(
        id: 'foreign',
        targetId: 'm45',
        targetName: 'M45',
        locationId: 'other',
      );
      final now = DateTime.utc(2026, 11, 3, 12);
      final state = ObservationAlertState(
        enabled: true,
        rules: [enabled, disabled, foreign],
        delivered: {
          'enabled|2026-11-02T15:00:00.000Z': now.subtract(
            const Duration(days: 1),
          ),
          'enabled|2026-10-20T15:00:00.000Z': now.subtract(
            const Duration(days: 10),
          ),
          'disabled|2026-11-02T15:00:00.000Z': now.subtract(
            const Duration(hours: 1),
          ),
          'foreign|2026-11-02T15:00:00.000Z': now.subtract(
            const Duration(hours: 1),
          ),
        },
      );
      final result = DashboardAlertOverview.fromState(
        state: state,
        locationId: 'zurich',
        nowUtc: now,
      );
      expect(result.rules.length, 2);
      expect(result.monitoredRules.map((rule) => rule.id), ['enabled']);
      expect(result.recentNotifications.map((item) => item.rule.id), [
        'enabled',
      ]);
      final off = DashboardAlertOverview.fromState(
        state: state.copyWith(enabled: false),
        locationId: 'zurich',
        nowUtc: now,
      );
      expect(off.monitoredRules, isEmpty);
      expect(off.recentNotifications, isEmpty);
    },
  );

  test('alert state provider reloads after explicit settings change', () async {
    final store = MemoryObservationAlertStore();
    final container = ProviderContainer(
      overrides: [observationAlertStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(observationAlertStateProvider.future)).enabled,
      false,
    );
    await store.save(ObservationAlertState(enabled: true));
    container.invalidate(observationAlertStateProvider);
    expect(
      (await container.read(observationAlertStateProvider.future)).enabled,
      true,
    );
  });
}
