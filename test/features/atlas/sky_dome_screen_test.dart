import 'dart:convert';

import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/atlas/presentation/sky_atlas_screen.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const site = ObservingLocation(
    id: 'test-site',
    name: 'Test Observatory',
    latitude: 47,
    longitude: 8,
    elevationMeters: 400,
    timeZone: 'Europe/Zurich',
    isDefault: true,
  );

  testWidgets('switching projections preserves the original detail view', (
    tester,
  ) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          observingLocations: const [site],
          initialObservationUtc: DateTime.utc(2026, 11, 2, 22),
          hostBuilder: (value) {
            controller = value;
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
    await tester.pump();
    final initialRa = controller!.position.raDegrees;
    expect(controller!.projectionMode, SkyAtlasProjectionMode.detail);
    await tester.tap(find.byKey(const ValueKey('atlas-mode-dome')));
    await tester.pump();
    expect(controller!.projectionMode, SkyAtlasProjectionMode.skyDome);
    expect(controller!.fieldOfViewDegrees, 180);
    expect(controller!.dome!.horizon.length, 121);
    final state = jsonDecode(controller!.stateJson) as Map<String, dynamic>;
    expect(state['projection'], 'dome');
    expect((state['dome'] as Map)['minimumAltitudeDegrees'], 25);
    expect(find.text('Test Observatory'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('atlas-mode-detail')));
    await tester.pump();
    expect(controller!.projectionMode, SkyAtlasProjectionMode.detail);
    expect(controller!.dome, isNull);
    expect(controller!.fieldOfViewDegrees, 3);
    expect(controller!.position.raDegrees, initialRa);
  });

  testWidgets('minimum altitude changes the horizon overlay', (tester) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          observingLocations: const [site],
          initialObservationUtc: DateTime.utc(2026, 11, 2, 22),
          hostBuilder: (value) {
            controller = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('atlas-mode-dome')));
    await tester.pump();
    final revision = controller!.revision;
    final slider = find.byKey(const ValueKey('dome-min-altitude'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(50, 0));
    await tester.pump();
    expect(controller!.revision, greaterThan(revision));
    expect(controller!.dome!.minimumAltitudeDegrees, isNot(25));
  });
}
