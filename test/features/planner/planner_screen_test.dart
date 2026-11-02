import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/locations/domain/repositories/observing_location_repository.dart';
import 'package:astromanager/features/planner/presentation/planner_screen.dart';
import 'package:astromanager/features/planner/data/night_plans_repository.dart';
import 'package:astromanager/features/planner/domain/night_observation_block.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';

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
class _EmptyProjects implements PlannedProjectsRepository {
  @override
  Future<List<PlannedImagingProject>> load() async => [];

  @override
  Future<void> save(PlannedImagingProject project) async {}

  @override
  Future<void> remove(String id) async {}
}

class _EmptyNightPlans implements NightPlansRepository {
  @override
  Future<List<NightObservationBlock>> forNight(NightPlanKey key) async => [];

  @override
  Future<void> save(NightObservationBlock block) async {}

  @override
  Future<void> remove(NightPlanKey key, String id) async {}
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
    List<ObservingLocation> locations,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingLocationRepositoryProvider.overrideWithValue(
            _FakeLocations(locations),
          ),
          plannedProjectsRepositoryProvider.overrideWithValue(_EmptyProjects()),
          nightPlansRepositoryProvider.overrideWithValue(_EmptyNightPlans()),
        ],
        child: const MaterialApp(home: Scaffold(body: PlannerScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

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
