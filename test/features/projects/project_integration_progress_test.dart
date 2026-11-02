import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/core/providers/database_providers.dart';
import 'package:astromanager/features/projects/data/observation_sessions_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:astromanager/features/projects/presentation/project_integration_progress.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedImagingProject _project(int target) => PlannedImagingProject(
  id: 'm31',
  title: 'M31',
  targetIds: const ['NGC0224'],
  createdAtUtc: DateTime.utc(2026, 11, 2),
  plannedIntegrationSeconds: target,
);

ObservationSession _session(String id, int accepted) => ObservationSession(
  id: id,
  projectId: 'm31',
  startedAtUtc: DateTime.utc(2026, 11, 2),
  timeZoneId: 'UTC',
  utcOffsetMinutes: 0,
  exposureSeconds: 60,
  frameCount: accepted + 10,
  acceptedFrames: accepted,
  rejectedFrames: 10,
);

Future<void> _pumpWithData(WidgetTester tester) async {
  // The provider fetches SQLite asynchronously, then renders the summary.
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('project progress refreshes after session changes', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftPlannedProjectsRepository(
      db,
      AppSettingsRepository(db),
    ).save(_project(10800));
    final repository = DriftObservationSessionsRepository(db);
    await repository.save(_session('a', 60));
    await repository.save(_session('b', 90));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: ProjectIntegrationProgress(project: _project(10800)),
          ),
        ),
      ),
    );
    await _pumpWithData(tester);
    expect(find.text('Usable integration: 2.5 h'), findsOneWidget);
    expect(find.textContaining('83.3%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('project-integration-bar')),
          )
          .value,
      closeTo(5 / 6, 0.00001),
    );

    await repository.save(_session('b', 30));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProjectIntegrationProgress)),
    );
    container.invalidate(observationSessionsForProjectProvider('m31'));
    await _pumpWithData(tester);
    expect(find.text('Usable integration: 1.5 h'), findsOneWidget);
    expect(find.textContaining('50.0%'), findsOneWidget);

    await repository.remove('a');
    container.invalidate(observationSessionsForProjectProvider('m31'));
    await _pumpWithData(tester);
    expect(find.text('Usable integration: 30 min'), findsOneWidget);
    expect(find.textContaining('16.7%'), findsOneWidget);

    // Changing the project goal recomputes the same integration total.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: ProjectIntegrationProgress(project: _project(1800)),
          ),
        ),
      ),
    );
    await _pumpWithData(tester);
    expect(find.text('Usable integration: 30 min'), findsOneWidget);
    expect(find.textContaining('100.0%'), findsOneWidget);
    expect(find.text('Integration target reached.'), findsOneWidget);
  });

  testWidgets('a target-less project shows usable time without progress bar', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftPlannedProjectsRepository(
      db,
      AppSettingsRepository(db),
    ).save(_project(0));
    await DriftObservationSessionsRepository(db).save(_session('a', 60));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: ProjectIntegrationProgress(project: _project(0)),
          ),
        ),
      ),
    );
    await _pumpWithData(tester);
    expect(find.text('Usable integration: 1 h'), findsOneWidget);
    expect(find.textContaining('No integration target set'), findsOneWidget);
    expect(find.byKey(const ValueKey('project-integration-bar')), findsNothing);
  });
}
