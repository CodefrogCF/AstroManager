import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/target_details_screen.dart';

const target = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6848,
  decDegrees: 41.2691,
  constellation: 'And',
  commonNames: 'Andromeda Galaxy',
  aliases: 'M31',
);
const site = ObservingLocation(
  id: 'site',
  name: 'Test Observatory',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

final class MemoryProjects implements PlannedProjectsRepository {
  final items = <PlannedImagingProject>[];
  @override
  Future<List<PlannedImagingProject>> load() async => List.unmodifiable(items);
  @override
  Future<void> save(PlannedImagingProject project) async {
    items.removeWhere((p) => p.id == project.id);
    items.add(project);
  }

  @override
  Future<void> remove(String id) async => items.removeWhere((p) => p.id == id);
}

void main() {
  testWidgets(
    'catalog details remain readable without optional data or observing sites',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TargetDetailsScreen(
              targetId: target.id,
              initialObject: target,
              initialLocalDate: DateTime(2026, 11, 2),
              testLocations: const [],
              testEquipment: EquipmentInventory(
                items: const [],
                profiles: const [],
              ),
              weatherLoader: (_) async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Messier number is intentionally absent from this catalog fixture.
      // The primary designation must still render and the M31 alias must remain visible.
      expect(find.text('NGC 224'), findsWidgets);
      expect(find.text('Identifiers: M31'), findsOneWidget);
      expect(find.textContaining('V magnitude: Unknown'), findsOneWidget);
      expect(find.textContaining('Add an observing location'), findsOneWidget);
      expect(find.byKey(const ValueKey('details-open-atlas')), findsOneWidget);
    },
  );

  testWidgets(
    'visibility graph, stale-safe weather and project save are accessible',
    (tester) async {
      final projects = MemoryProjects();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plannedProjectsRepositoryProvider.overrideWithValue(projects),
          ],
          child: MaterialApp(
            home: TargetDetailsScreen(
              targetId: target.id,
              initialObject: target,
              initialLocalDate: DateTime(2026, 11, 2),
              testLocations: const [site],
              testEquipment: EquipmentInventory(
                items: const [],
                profiles: const [],
              ),
              weatherLoader: (_) async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('target-altitude-graph')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('details-save-project')),
      );
      await tester.tap(find.byKey(const ValueKey('details-save-project')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('target-new-project')));
      await tester.pumpAndSettle();
      expect(projects.items, hasLength(1));
      expect(projects.items.single.targetIds, [target.id]);
      expect(projects.items.single.locationId, 'site');
      await tester.scrollUntilVisible(
        find.textContaining('No weather forecast available'),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('No weather forecast available'),
        findsOneWidget,
      );
    },
  );

  testWidgets('changing observing location refreshes the forecast request', (
    tester,
  ) async {
    final latitudes = <double>[];
    const second = ObservingLocation(
      id: 'second',
      name: 'Second Observatory',
      latitude: 40.0,
      longitude: -105.0,
      elevationMeters: 1600,
      timeZone: 'America/Denver',
      isDefault: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TargetDetailsScreen(
            targetId: target.id,
            initialObject: target,
            initialLocalDate: DateTime(2026, 11, 2),
            testLocations: const [site, second],
            testEquipment: EquipmentInventory(
              items: const [],
              profiles: const [],
            ),
            weatherLoader: (request) async {
              latitudes.add(request.latitudeDegrees);
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(latitudes, [47.48]);
    await tester.tap(find.byKey(const ValueKey('details-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Observatory').last);
    await tester.pumpAndSettle();
    expect(latitudes.last, 40.0);
    expect(find.text('Second Observatory'), findsOneWidget);
  });
}
