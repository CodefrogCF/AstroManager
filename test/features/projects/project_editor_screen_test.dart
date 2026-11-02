import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:astromanager/features/projects/presentation/project_editor_dialog.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';

const object = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6847,
  decDegrees: 41.2688,
  constellation: 'And',
  commonNames: 'Andromeda Galaxy',
  aliases: 'M31',
);

void main() {
  testWidgets('project editor validates title and integration time', (
    tester,
  ) async {
    PlannedImagingProject? saved;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showDialog<PlannedImagingProject>(
                    context: context,
                    builder: (context) => ProjectEditorDialog(
                      testTargets: const [object],
                      testEquipment: EquipmentInventory(
                        items: const [],
                        profiles: const [],
                      ),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-confirm-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a project title.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('project-title')),
      'Andromeda',
    );
    await tester.enterText(
      find.byKey(const ValueKey('project-integration')),
      '-1',
    );
    await tester.tap(find.byKey(const ValueKey('project-confirm-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid non-negative whole number.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('project-integration')),
      '180',
    );
    final addTarget = find.byKey(const ValueKey('project-add-target'));
    await tester.ensureVisible(addTarget);
    await tester.pumpAndSettle();
    await tester.tap(addTarget);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-catalog-query')),
      'Andromeda',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGC 224').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-confirm-save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.title, 'Andromeda');
    expect(saved!.targetIds, ['NGC0224']);
    expect(saved!.plannedIntegrationSeconds, 10800);
    expect(saved!.status, ImagingProjectStatus.planned);
  });

  testWidgets('editing an archived project restores all optional fields', (
    tester,
  ) async {
    final existing = PlannedImagingProject(
      id: 'p1',
      title: 'Old',
      targetIds: const ['NGC0224'],
      createdAtUtc: DateTime.utc(2026, 11, 2),
      description: 'Original',
      notes: 'Original notes',
      imagingGoal: 'Color',
      opticalProfileId: 'deleted-equipment',
      plannedIntegrationSeconds: 3600,
      status: ImagingProjectStatus.archived,
    );
    PlannedImagingProject? saved;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showDialog<PlannedImagingProject>(
                    context: context,
                    builder: (context) => ProjectEditorDialog(
                      project: existing,
                      testTargets: const [object],
                      testEquipment: EquipmentInventory(
                        items: const [],
                        profiles: const [],
                      ),
                    ),
                  );
                },
                child: const Text('Edit existing'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit existing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-confirm-save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.status, ImagingProjectStatus.archived);
    expect(saved!.opticalProfileId, 'deleted-equipment');
    expect(saved!.targetIds, ['NGC0224']);
    expect(saved!.description, 'Original');
    expect(saved!.notes, 'Original notes');
  });
}
