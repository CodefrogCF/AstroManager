import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/app/router/app_router.dart';
import 'package:astromanager/features/equipment/application/equipment_controller.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/locations/domain/repositories/observing_location_repository.dart';
import 'package:astromanager/features/mosaic/data/mosaic_repository.dart';
import 'package:astromanager/features/planner/presentation/planner_screen.dart';
import 'package:astromanager/features/planner/data/night_plans_repository.dart';
import 'package:astromanager/features/planner/domain/night_observation_block.dart';
import 'package:astromanager/features/projects/data/observation_sessions_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:astromanager/features/targets/application/celestial_catalog_controller.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/domain/repositories/celestial_catalog_repository.dart';

import '../../support/catalog_navigation_test_override.dart';

class _FakeLocations implements ObservingLocationRepository {
  _FakeLocations(this.locations);

  final List<ObservingLocation> locations;

  @override
  Future<List<ObservingLocation>> getAll() async => locations;

  @override
  Future<void> save(ObservingLocation location) async {}

  @override
  Future<void> setDefault(String id) async {}

  @override
  Future<void> delete(String id) async {}
}

// The planner now watches project and night-plan data as well as locations.
// Use deterministic repositories in the widget test: loading the real Drift
// database and the OpenNGC catalog is not part of the solar-events test.
class _Projects implements PlannedProjectsRepository {
  _Projects([this.items = const []]);

  final List<PlannedImagingProject> items;

  @override
  Future<List<PlannedImagingProject>> load() async => items;

  @override
  Future<void> save(PlannedImagingProject project) async {}

  @override
  Future<void> remove(String id) async {}
}

class _NightPlans implements NightPlansRepository {
  final blocks = <String, NightObservationBlock>{};

  @override
  Future<List<NightObservationBlock>> forNight(NightPlanKey key) async => [
    for (final block in blocks.values)
      if (block.locationId == key.locationId &&
          block.nightDate == key.nightDate)
        block,
  ];

  @override
  Future<void> save(NightObservationBlock block) async {
    blocks[block.id] = block;
  }

  @override
  Future<void> remove(NightPlanKey key, String id) async {
    blocks.remove(id);
  }
}

class _Catalog extends Fake implements CelestialCatalogRepository {
  @override
  Future<CelestialObject?> findById(String id) async => null;
}

const _zurich = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

const _tromso = ObservingLocation(
  id: 'tromso',
  name: 'Tromso',
  latitude: 69.6492,
  longitude: 18.9553,
  elevationMeters: 10,
  timeZone: 'Europe/Oslo',
  isDefault: false,
);

void main() {
  Future<void> pumpPlanner(
    WidgetTester tester,
    List<ObservingLocation> locations, {
    _NightPlans? plans,
    DateTime? date,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingLocationRepositoryProvider.overrideWithValue(
            _FakeLocations(locations),
          ),
          plannedProjectsRepositoryProvider.overrideWithValue(_Projects()),
          nightPlansRepositoryProvider.overrideWithValue(
            plans ?? _NightPlans(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: PlannerScreen(initialDate: date)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final control = find.byKey(ValueKey(key));
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'project target can be scheduled, edited and deleted in the night overview',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final router = createAppRouter(initialLocation: AppRoutes.projects);
      addTearDown(router.dispose);
      final plans = _NightPlans();
      final project = PlannedImagingProject(
        id: 'winter',
        title: 'Winter mosaic',
        targetIds: const ['M31', 'M42'],
        locationId: _tromso.id,
        observingDate: '2025-02-01',
        createdAtUtc: DateTime.utc(2025),
      );
      final other = PlannedImagingProject(
        id: 'other',
        title: 'Other project',
        targetIds: const ['M45'],
        createdAtUtc: DateTime.utc(2025),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            observingLocationRepositoryProvider.overrideWithValue(
              _FakeLocations([_zurich, _tromso]),
            ),
            plannedProjectsRepositoryProvider.overrideWithValue(
              _Projects([other, project]),
            ),
            nightPlansRepositoryProvider.overrideWithValue(plans),
            equipmentProvider.overrideWithBuild(
              (ref, notifier) => EquipmentInventory(items: [], profiles: []),
            ),
            mosaicPlansRepositoryProvider.overrideWithValue(
              MemoryMosaicPlansRepository(),
            ),
            observationSessionsForProjectProvider.overrideWith(
              (ref, id) async => [],
            ),
            createCatalogNavigationTestOverride(),
            celestialCatalogRepositoryProvider.overrideWithValue(_Catalog()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'project-winter');
      await tapKey(tester, 'project-schedule-M42');
      expect(find.text('Night overview'), findsOneWidget);
      expect(find.byKey(const ValueKey('planner-site-tromso')), findsOneWidget);
      expect(find.textContaining('February 1, 2025'), findsWidgets);
      expect(find.text('Winter mosaic · M42'), findsOneWidget);

      await tapKey(tester, 'planner-site-tromso');
      await tester.tap(find.text('Zurich').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'planner-date');
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('2'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('night-planning-section')),
          matching: find.textContaining('Zurich ·'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('February 2, 2025'), findsWidgets);
      expect(find.text('Astronomical darkness'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('darkness-'),
        ),
        findsWidgets,
      );

      await tapKey(tester, 'night-plan-add');
      expect(
        find.byKey(const ValueKey('night-block-target-winter')),
        findsOneWidget,
      );
      await tapKey(tester, 'night-block-save');
      final block = plans.blocks.values.single;
      expect(block.projectId, project.id);
      expect(block.targetId, 'M42');
      expect(block.locationId, _zurich.id);
      expect(block.nightDate, '2025-02-02');
      expect(block.duration, const Duration(hours: 1));
      expect(find.text('Scheduled targets'), findsOneWidget);
      expect(find.textContaining('Unscheduled darkness'), findsOneWidget);
      final row = find.byKey(ValueKey('night-schedule-${block.id}'));
      expect(
        find.descendant(of: row, matching: find.text('M42')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining(' – ')),
        findsOneWidget,
      );

      await tapKey(tester, 'night-schedule-edit-${block.id}');
      final duration = find.byKey(const ValueKey('night-block-duration'));
      await tester.ensureVisible(duration);
      await tester.enterText(duration, '90');
      await tester.pumpAndSettle();
      await tapKey(tester, 'night-block-save');
      expect(plans.blocks[block.id]!.duration, const Duration(minutes: 90));
      expect(plans.blocks[block.id]!.startUtc, block.startUtc);

      await tapKey(tester, 'night-schedule-delete-${block.id}');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(plans.blocks, hasLength(1));
      await tapKey(tester, 'night-schedule-delete-${block.id}');
      await tapKey(tester, 'night-block-confirm-delete');
      expect(plans.blocks, isEmpty);
      expect(find.text('No targets scheduled.'), findsOneWidget);
    },
  );

  testWidgets('an orphaned block keeps its target and exact time when edited', (
    tester,
  ) async {
    final original = NightObservationBlock(
      id: 'history',
      locationId: _zurich.id,
      nightDate: '2024-10-26',
      timeZoneId: _zurich.timeZone,
      projectId: 'removed',
      targetId: 'M31',
      projectName: 'Old project',
      targetName: 'Andromeda',
      startUtc: DateTime.utc(2024, 10, 27, 1, 30, 15),
      endUtc: DateTime.utc(2024, 10, 27, 1, 30, 55),
    );
    final plans = _NightPlans()..blocks[original.id] = original;
    await pumpPlanner(
      tester,
      [_zurich],
      plans: plans,
      date: DateTime(2024, 10, 26),
    );
    expect(find.textContaining('UTC+01:00'), findsWidgets);
    await tapKey(tester, 'night-schedule-edit-history');
    final notes = find.byType(TextFormField).last;
    await tester.ensureVisible(notes);
    await tester.enterText(notes, 'Updated from the overview');
    await tapKey(tester, 'night-block-save');
    final saved = plans.blocks.values.single;
    expect(saved.projectId, original.projectId);
    expect(saved.targetName, original.targetName);
    expect(saved.startUtc, original.startUtc);
    expect(saved.endUtc, original.endUtc);
    expect(saved.notes, 'Updated from the overview');
  });

  testWidgets('no observing sites gives clear guidance', (tester) async {
    await pumpPlanner(tester, []);
    expect(find.textContaining('Add an observing location'), findsOneWidget);
  });

  testWidgets('shows solar events using the default location', (tester) async {
    await pumpPlanner(tester, [_zurich, _tromso]);
    expect(find.text('Night Planner'), findsOneWidget);
    expect(find.text('Zurich'), findsOneWidget);
    expect(find.textContaining('Solar events'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('night-planning-section')),
      findsOneWidget,
    );
    expect(find.text('Interactive night timeline'), findsOneWidget);
    expect(find.textContaining('Local time: Europe/Zurich'), findsOneWidget);
    expect(find.textContaining('Astronomical darkness'), findsOneWidget);
    expect(find.textContaining('Lunar conditions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planner-lunar-conditions')),
      findsOneWidget,
    );
    expect(find.textContaining('Moon phase:'), findsOneWidget);
    expect(find.textContaining('Illumination:'), findsOneWidget);
  });
}
