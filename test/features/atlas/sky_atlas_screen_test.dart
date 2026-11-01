import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/presentation/sky_atlas_screen.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = CelestialObject(
    id: 'NGC0224',
    designation: 'NGC 224',
    category: CelestialCategory.galaxy,
    sourceType: 'G',
    raDegrees: 10.6847,
    decDegrees: 41.2688,
    constellation: 'And',
    commonNames: 'Andromeda',
    aliases: 'M31',
    messierNumber: 31,
  );

  testWidgets('a selected catalog target is centered in the atlas model', (
    tester,
  ) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          target: target,
          hostBuilder: (value) {
            controller = value;
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
    expect(find.textContaining('Sky Atlas · M 31'), findsOneWidget);
    expect(controller!.position.raDegrees, closeTo(10.6847, 1e-8));
    expect(controller!.markers.single.id, 'NGC0224');
    await tester.tap(find.byKey(const ValueKey('atlas-fov-0.5')));
    await tester.pump();
    expect(controller!.fieldOfViewDegrees, 0.5);
    await tester.tap(find.byKey(const ValueKey('atlas-recenter')));
    await tester.pump();
    expect(controller!.position.decDegrees, closeTo(41.2688, 1e-8));
  });

  testWidgets('a bridge error exposes retry without navigation', (
    tester,
  ) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          hostBuilder: (value) {
            controller = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    controller!.reportError('Network is offline');
    await tester.pump();
    expect(find.text('Sky atlas unavailable'), findsOneWidget);
    expect(find.text('Network is offline'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('atlas-retry')));
    await tester.pump();
    expect(controller!.status, SkyAtlasStatus.loading);
    expect(find.text('Loading Aladin Lite sky survey...'), findsOneWidget);
  });
}
