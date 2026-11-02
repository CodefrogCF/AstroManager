import 'dart:convert';

import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/data/framing_repository.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/atlas/presentation/sky_atlas_screen.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const target = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6847,
  decDegrees: 41.2688,
  constellation: 'And',
  messierNumber: 31,
  majorAxisArcmin: 190,
  commonNames: 'Andromeda Galaxy',
  aliases: 'M31',
);

final equipment = EquipmentInventory(
  items: const [
    EquipmentItem(
      id: 'camera',
      name: 'Full-frame camera',
      kind: EquipmentKind.camera,
      sensorWidthMm: 36,
      sensorHeightMm: 24,
      resolutionX: 6000,
      resolutionY: 4000,
    ),
    EquipmentItem(
      id: 'wide',
      name: '100 mm refractor',
      kind: EquipmentKind.telescope,
      focalLengthMm: 100,
      apertureMm: 50,
    ),
    EquipmentItem(
      id: 'narrow',
      name: '1000 mm telescope',
      kind: EquipmentKind.telescope,
      focalLengthMm: 1000,
      apertureMm: 100,
    ),
  ],
  profiles: const [
    OpticalProfile(
      id: 'wide',
      name: 'Widefield',
      cameraId: 'camera',
      opticId: 'wide',
      focalMultiplier: 1,
    ),
    OpticalProfile(
      id: 'narrow',
      name: 'Narrowband',
      cameraId: 'camera',
      opticId: 'narrow',
      focalMultiplier: 1,
    ),
  ],
);

void main() {
  testWidgets(
    'equipment change updates the footprint and warns for large objects',
    (tester) async {
      SkyAtlasController? atlas;
      await tester.pumpWidget(
        MaterialApp(
          home: SkyAtlasScreen(
            target: target,
            equipmentInventory: equipment,
            framingRepository: MemoryCameraFramingRepository(),
            hostBuilder: (controller) {
              atlas = controller;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final wide = atlas!.cameraFrame!;
      expect(wide.horizontalFovDegrees, greaterThan(10));
      await tester.tap(find.byKey(const ValueKey('frame-profile-wide')));
      await tester.pump();
      await tester.tap(find.text('Narrowband').last);
      await tester.pump();
      expect(atlas!.cameraFrame!.horizontalFovDegrees, lessThan(3));
      expect(atlas!.cameraFrame!.configuration.profileId, 'narrow');
      expect(find.byKey(const ValueKey('frame-too-small')), findsOneWidget);
    },
  );

  testWidgets('rotation, pan-center and save/restore are retained', (
    tester,
  ) async {
    final repo = MemoryCameraFramingRepository();
    SkyAtlasController? atlas;
    Widget screen() => MaterialApp(
      home: SkyAtlasScreen(
        target: target,
        equipmentInventory: equipment,
        framingRepository: repo,
        hostBuilder: (controller) {
          atlas = controller;
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    atlas!.receive(
      jsonEncode({
        'protocol': SkyAtlasProtocol.identifier,
        'version': 1,
        'type': 'viewChanged',
        'ra': 14.5,
        'dec': 43.2,
        'fov': 3,
      }),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('frame-use-atlas-center')));
    await tester.pump();
    expect(atlas!.cameraFrame!.configuration.center.raDegrees, 14.5);
    await tester.drag(
      find.byKey(const ValueKey('frame-rotation')),
      const Offset(65, 0),
    );
    await tester.pump();
    final rotation = atlas!.cameraFrame!.configuration.rotationDegrees;
    expect(rotation, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('frame-save')));
    await tester.pump();
    await tester.pump();
    expect(repo.records['NGC0224']!.center.raDegrees, 14.5);
    expect(repo.records['NGC0224']!.rotationDegrees, rotation);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(atlas!.cameraFrame!.configuration.center.raDegrees, 14.5);
    expect(atlas!.cameraFrame!.configuration.rotationDegrees, rotation);
  });
}
