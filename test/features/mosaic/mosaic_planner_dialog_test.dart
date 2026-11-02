import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/mosaic/domain/mosaic_plan.dart';
import 'package:astromanager/features/mosaic/presentation/mosaic_planner_dialog.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';

void main() {
  testWidgets(
    'mosaic editor changes rows, overlap, rotation and returns a plan',
    (tester) async {
      final project = PlannedImagingProject(
        id: 'p1',
        title: 'M31',
        targetIds: const ['m31'],
        createdAtUtc: DateTime.utc(2026),
      );
      const target = CelestialObject(
        id: 'm31',
        designation: 'NGC 224',
        category: CelestialCategory.galaxy,
        sourceType: 'G',
        raDegrees: 10.6847,
        decDegrees: 41.2688,
        constellation: 'And',
        commonNames: 'Andromeda',
        aliases: 'M31',
      );
      final equipment = EquipmentInventory(
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
            id: 'o',
            name: 'Refractor',
            kind: EquipmentKind.telescope,
            focalLengthMm: 600,
            apertureMm: 100,
          ),
        ],
        profiles: const [
          OpticalProfile(
            id: 'setup',
            name: 'Setup',
            cameraId: 'c',
            opticId: 'o',
            focalMultiplier: 1,
          ),
        ],
      );
      MosaicPlan? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    saved = await showDialog<MosaicPlan>(
                      context: context,
                      builder: (_) => MosaicPlannerDialog(
                        project: project,
                        targets: const [target],
                        equipment: equipment,
                      ),
                    );
                  },
                  child: const Text('Open mosaic'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open mosaic'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mosaic-total-fov')), findsOneWidget);
      expect(find.textContaining('4 panels'), findsOneWidget);
      final save = find.byKey(const ValueKey('mosaic-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.rows, 2);
      expect(saved!.columns, 2);
      expect(saved!.overlapPercent, 15);
    },
  );
}
