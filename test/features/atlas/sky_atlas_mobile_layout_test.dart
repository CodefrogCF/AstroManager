import 'dart:convert';

import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/data/framing_repository.dart';
import 'package:astromanager/features/atlas/presentation/sky_atlas_screen.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final mobileInventory = EquipmentInventory(
  items: const [
    EquipmentItem(
      id: 'mobile-camera',
      name: 'Camera',
      kind: EquipmentKind.camera,
      sensorWidthMm: 36,
      sensorHeightMm: 24,
      resolutionX: 6000,
      resolutionY: 4000,
    ),
    EquipmentItem(
      id: 'mobile-optic',
      name: 'Telescope',
      kind: EquipmentKind.telescope,
      focalLengthMm: 400,
      apertureMm: 80,
    ),
  ],
  profiles: const [
    OpticalProfile(
      id: 'mobile-profile',
      name: 'Mobile setup',
      cameraId: 'mobile-camera',
      opticId: 'mobile-optic',
      focalMultiplier: 1,
    ),
  ],
);

void main() {
  testWidgets('phone screen prioritizes the atlas and collapses controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SkyAtlasController? atlas;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          equipmentInventory: mobileInventory,
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
    atlas!.receive(
      jsonEncode({
        'protocol': SkyAtlasProtocol.identifier,
        'version': 1,
        'type': 'ready',
      }),
    );
    await tester.pump();

    final viewport = tester.getSize(
      find.byKey(const ValueKey('atlas-mobile-viewport')),
    );
    expect(viewport.height, greaterThan(600));
    expect(find.byKey(const ValueKey('atlas-mobile-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('atlas-mobile-fov-label')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('frame-save')), findsNothing);
    expect(tester.takeException(), isNull);

    // Credits remain accessible without a large permanent text block.
    await tester.tap(find.byKey(const ValueKey('atlas-mobile-info')));
    await tester.pumpAndSettle();
    expect(find.text('Data sources'), findsOneWidget);
    expect(find.textContaining('OpenNGC'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('atlas-mobile-controls-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('atlas-mobile-view-section')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('atlas-mobile-view-section')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('atlas-fov-0.5')));
    await tester.pump();
    expect(atlas!.fieldOfViewDegrees, 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop keeps visible legacy controls', (tester) async {
    SkyAtlasController? atlas;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          equipmentInventory: mobileInventory,
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
    expect(atlas, isNotNull);
    expect(find.byKey(const ValueKey('atlas-mobile-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('frame-save')), findsOneWidget);
  });
}
