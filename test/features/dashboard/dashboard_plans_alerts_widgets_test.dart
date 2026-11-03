import 'package:astromanager/app/router/app_router.dart';
import 'package:astromanager/features/alerts/data/observation_alert_store.dart';
import 'package:astromanager/features/alerts/domain/observation_alert.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/dashboard_plans_alerts_widgets.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/planner/data/night_plans_repository.dart';
import 'package:astromanager/features/planner/domain/night_observation_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _site = ObservingLocation(
  id: 'site',
  name: 'Home site',
  latitude: 47.4,
  longitude: 8.5,
  elevationMeters: 420,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
final _now = DateTime.utc(2026, 11, 3, 17);

final class _Plans implements NightPlansRepository {
  final data = <NightPlanKey, List<NightObservationBlock>>{};
  @override
  Future<List<NightObservationBlock>> forNight(NightPlanKey key) async =>
      data[key] ?? const [];
  @override
  Future<void> save(NightObservationBlock block) async {
    data
        .putIfAbsent(NightPlanKey(block.locationId, block.nightDate), () => [])
        .add(block);
  }

  @override
  Future<void> remove(NightPlanKey key, String id) async {
    data[key]?.removeWhere((block) => block.id == id);
  }
}

NightObservationBlock _block(String id, int hour, {String target = 'M31'}) =>
    NightObservationBlock(
      id: id,
      locationId: 'site',
      nightDate: '2026-11-03',
      timeZoneId: 'Europe/Zurich',
      projectId: 'project',
      targetId: target,
      projectName: 'Winter imaging',
      targetName: target,
      startUtc: DateTime.utc(2026, 11, 3, hour),
      endUtc: DateTime.utc(2026, 11, 3, hour + 2),
    );

void main() {
  testWidgets('upcoming plans show location-local times and overlap warning', (
    tester,
  ) async {
    final repo = _Plans();
    repo.data[NightPlanKey('site', '2026-11-03')] = [
      _block('one', 18),
      _block('two', 19, target: 'M42'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nightPlansRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 550,
              child: DashboardUpcomingPlansWidget(
                location: _site,
                referenceUtc: _now,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-upcoming-plans')),
      findsOneWidget,
    );
    expect(find.text('M31'), findsOneWidget);
    expect(find.text('M42'), findsOneWidget);
    // Zurich is UTC+1 in November.
    expect(find.textContaining('03.11.2026 19:00'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-plan-conflict-one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-plan-conflict-two')),
      findsOneWidget,
    );
  });

  testWidgets('DST fall-back local times remain distinguishable', (
    tester,
  ) async {
    final repo = _Plans();
    repo.data[NightPlanKey('site', '2026-10-24')] = [
      NightObservationBlock(
        id: 'before',
        locationId: 'site',
        nightDate: '2026-10-24',
        timeZoneId: 'Europe/Zurich',
        projectId: 'project',
        targetId: 'before',
        projectName: 'Imaging',
        targetName: 'Before',
        startUtc: DateTime.utc(2026, 10, 25, 0, 15),
        endUtc: DateTime.utc(2026, 10, 25, 0, 45),
      ),
      NightObservationBlock(
        id: 'after',
        locationId: 'site',
        nightDate: '2026-10-24',
        timeZoneId: 'Europe/Zurich',
        projectId: 'project',
        targetId: 'after',
        projectName: 'Imaging',
        targetName: 'After',
        startUtc: DateTime.utc(2026, 10, 25, 1, 15),
        endUtc: DateTime.utc(2026, 10, 25, 1, 45),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nightPlansRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardUpcomingPlansWidget(
              location: _site,
              referenceUtc: DateTime.utc(2026, 10, 24, 19),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The wall clock repeats 02:xx, but the UTC offset / abbreviation changes.
    expect(find.textContaining('CEST'), findsWidgets);
    expect(find.textContaining('CET'), findsWidgets);
  });

  testWidgets('plan action opens the selected location and observing night', (
    tester,
  ) async {
    final repo = _Plans();
    repo.data[NightPlanKey('site', '2026-11-03')] = [_block('one', 18)];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: DashboardUpcomingPlansWidget(
              location: _site,
              referenceUtc: _now,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.planner,
          builder: (context, state) => Scaffold(
            body: Text(
              'site=${state.uri.queryParameters['location']};'
              'night=${state.uri.queryParameters['night']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nightPlansRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-plan-one')));
    await tester.pumpAndSettle();
    expect(find.text('site=site;night=2026-11-03'), findsOneWidget);
  });

  testWidgets('alerts show only enabled rules and notified history', (
    tester,
  ) async {
    final store = MemoryObservationAlertStore();
    await store.save(
      ObservationAlertState(
        enabled: true,
        rules: const [
          ObservationAlertRule(
            id: 'active',
            targetId: 'm31',
            targetName: 'M31',
            locationId: 'site',
            minimumScore: 70,
          ),
          ObservationAlertRule(
            id: 'off',
            targetId: 'm42',
            targetName: 'M42',
            locationId: 'site',
            enabled: false,
          ),
        ],
        delivered: {
          'active|2026-11-03T14:00:00.000Z': _now.subtract(
            const Duration(hours: 1),
          ),
          'off|2026-11-03T14:00:00.000Z': _now.subtract(
            const Duration(hours: 1),
          ),
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [observationAlertStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 500,
              child: DashboardObservationAlertsWidget(
                location: _site,
                referenceUtc: _now,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-alert-rule-active')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-alert-rule-off')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('dashboard-alert-delivered-active')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-alert-delivered-off')),
      findsNothing,
    );
    expect(
      find.textContaining('no continuous background monitoring'),
      findsOneWidget,
    );
  });

  testWidgets('disabled alert switch does not imply active monitoring', (
    tester,
  ) async {
    final store = MemoryObservationAlertStore();
    await store.save(
      ObservationAlertState(
        rules: const [
          ObservationAlertRule(
            id: 'inactive',
            targetId: 'm31',
            targetName: 'M31',
            locationId: 'site',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [observationAlertStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardObservationAlertsWidget(
              location: _site,
              referenceUtc: _now,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Opportunity notifications are disabled.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-alert-rule-inactive')),
      findsNothing,
    );
  });
}
