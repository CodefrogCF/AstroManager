import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/data/framing_repository.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/atlas/presentation/sky_atlas_screen.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/mosaic/domain/mosaic_plan.dart';

final inventory = EquipmentInventory(
  items: const [
    EquipmentItem(
      id: 'c',
      name: 'Camera',
      kind: EquipmentKind.camera,
      sensorWidthMm: 36,
      sensorHeightMm: 24,
      resolutionX: 6000,
      resolutionY: 4000,
    ),
    EquipmentItem(
      id: 'short',
      name: 'Short',
      kind: EquipmentKind.telescope,
      focalLengthMm: 200,
      apertureMm: 50,
    ),
    EquipmentItem(
      id: 'long',
      name: 'Long',
      kind: EquipmentKind.telescope,
      focalLengthMm: 1000,
      apertureMm: 100,
    ),
  ],
  profiles: const [
    OpticalProfile(
      id: 'wide',
      name: 'Wide',
      cameraId: 'c',
      opticId: 'short',
      focalMultiplier: 1,
    ),
    OpticalProfile(
      id: 'narrow',
      name: 'Narrow',
      cameraId: 'c',
      opticId: 'long',
      focalMultiplier: 1,
    ),
  ],
);

void main() {
  testWidgets(
    'project mosaic is delivered to atlas bridge and setup changes update dimensions',
    (tester) async {
      SkyAtlasController? controller;
      const plan = MosaicPlan(
        projectId: 'p1',
        targetId: 'm31',
        profileId: 'wide',
        center: SkyAtlasPosition(raDegrees: 10.6847, decDegrees: 41.2688),
        rows: 2,
        columns: 3,
        overlapPercent: 20,
        rotationDegrees: 15,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SkyAtlasScreen(
            initialMosaic: plan,
            equipmentInventory: inventory,
            framingRepository: MemoryCameraFramingRepository(),
            hostBuilder: (atlas) {
              controller = atlas;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Even with the compact atlas viewport, loading must not overflow.
      expect(tester.takeException(), isNull);
      // The injected host does not emit bridge events automatically. Model a
      // successful Aladin startup before waiting for settled widget animations.
      // Without this, the indeterminate loading spinner runs indefinitely.
      controller!.receive(
        '{"protocol":"astromanager.aladin","version":1,"type":"ready"}',
      );
      await tester.pump();
      expect(controller!.status, SkyAtlasStatus.ready);
      expect(controller!.mosaic, isNotNull);
      expect(controller!.mosaic!.panels, hasLength(6));
      final state = jsonDecode(controller!.stateJson) as Map<String, dynamic>;
      expect((state['mosaic'] as Map)['panels'], hasLength(6));
      final oldWidth = controller!.mosaic!.widthDegrees;
      await tester.tap(find.byKey(const ValueKey('frame-profile-wide')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Narrow').last);
      await tester.pump();
      expect(controller!.mosaic!.widthDegrees, lessThan(oldWidth));
      expect(
        find.byKey(const ValueKey('atlas-mosaic-summary')),
        findsOneWidget,
      );
    },
  );
}
