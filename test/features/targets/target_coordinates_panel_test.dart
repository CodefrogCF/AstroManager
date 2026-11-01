import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/locations/domain/repositories/observing_location_repository.dart';

import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/target_coordinates_panel.dart';

class FakeCoordinatesLocationRepository implements ObservingLocationRepository {
  FakeCoordinatesLocationRepository(this.locations);

  final List<ObservingLocation> locations;

  @override
  Future<List<ObservingLocation>> getAll() async =>
      List.unmodifiable(locations);

  @override
  Future<void> save(ObservingLocation location) async {}

  @override
  Future<void> setDefault(String id) async {}

  @override
  Future<void> delete(String id) async {}
}

const testObject = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6848,
  decDegrees: 41.2691,
  constellation: 'And',
  visualMagnitude: 3.44,
  messierNumber: 31,
  commonNames: 'Andromeda Galaxy',
  aliases: 'M31',
);

void main() {
  Future<void> pumpPanel(
    WidgetTester tester,
    List<ObservingLocation> locations,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingLocationRepositoryProvider.overrideWithValue(
            FakeCoordinatesLocationRepository(locations),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: TargetCoordinatesPanel(object: testObject),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows guidance when no observing location exists', (
    tester,
  ) async {
    await pumpPanel(tester, []);

    expect(
      find.textContaining('Add an observing location in Settings'),
      findsOneWidget,
    );
  });

  testWidgets('calculates coordinates using saved observing site', (
    tester,
  ) async {
    await pumpPanel(tester, [
      const ObservingLocation(
        id: 'test-location',
        name: 'Test Observatory',
        latitude: 47.48,
        longitude: 8.21,
        elevationMeters: 400,
        timeZone: 'Europe/Zurich',
        isDefault: true,
      ),
    ]);

    expect(
      find.byKey(const ValueKey('target-coordinates-panel')),
      findsOneWidget,
    );

    expect(find.text('Test Observatory'), findsWidgets);

    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('Azimuth'), findsOneWidget);
    expect(find.text('Airmass'), findsOneWidget);

    expect(find.text('Local sidereal time'), findsOneWidget);

    expect(find.text('UTC date'), findsOneWidget);

    expect(find.text('UTC time'), findsOneWidget);
  });
}
