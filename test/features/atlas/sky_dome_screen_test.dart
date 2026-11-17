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

  testWidgets(
    'both modes show the live field of view and restore the detail zoom',
    (tester) async {
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
      final atlas = controller!;
      int viewRevision() => jsonDecode(atlas.stateJson)['viewRevision'] as int;
      void reportView(double fov, int revision) => atlas.receive(
        jsonEncode({
          'protocol': SkyAtlasProtocol.identifier,
          'version': SkyAtlasProtocol.version,
          'type': 'viewChanged',
          'ra': 84,
          'dec': 20,
          'fov': fov,
          'viewRevision': revision,
        }),
      );
      final detailRevision = viewRevision();
      expect(atlas.projectionMode, SkyAtlasProjectionMode.detail);
      expect(find.text('FOV 3.00°'), findsOneWidget);
      reportView(1.257, detailRevision);
      await tester.pump();
      expect(find.text('FOV 1.26°'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('atlas-mode-dome')));
      await tester.pump();
      expect(atlas.projectionMode, SkyAtlasProjectionMode.skyDome);
      expect(atlas.fieldOfViewDegrees, 180);
      expect(atlas.dome!.horizon.length, 121);
      final state = jsonDecode(atlas.stateJson) as Map<String, dynamic>;
      expect(state['projection'], 'dome');
      expect((state['dome'] as Map)['minimumAltitudeDegrees'], 25);
      expect(find.text('Test Observatory'), findsOneWidget);
      expect(find.text('FOV 180.00°'), findsOneWidget);
      reportView(1.25, detailRevision);
      expect(atlas.fieldOfViewDegrees, 180);
      reportView(147.35, viewRevision());
      await tester.pump();
      expect(find.text('FOV 147.35°'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('atlas-mode-detail')));
      await tester.pump();
      expect(atlas.projectionMode, SkyAtlasProjectionMode.detail);
      expect(atlas.dome, isNull);
      expect(atlas.fieldOfViewDegrees, 1.257);
      expect(atlas.position.raDegrees, 84);
      expect(find.text('FOV 1.26°'), findsOneWidget);
    },
  );

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
