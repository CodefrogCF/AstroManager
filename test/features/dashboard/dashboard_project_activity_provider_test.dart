import 'package:astromanager/features/dashboard/application/dashboard_project_activity_provider.dart';
import 'package:astromanager/features/projects/data/observation_sessions_repository.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'project goal and session changes invalidate the shared summary',
    () async {
      var project = PlannedImagingProject(
        id: 'p1',
        title: 'Orion',
        targetIds: const [],
        createdAtUtc: DateTime.utc(2026, 10, 1),
        plannedIntegrationSeconds: 3600,
      );
      var sessions = <ObservationSession>[];
      final container = ProviderContainer(
        overrides: [
          plannedProjectsListProvider.overrideWith((ref) async => [project]),
          observationSessionsForProjectProvider.overrideWith(
            (ref, id) async => sessions,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        dashboardProjectActivityProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final initial = await container.read(
        dashboardProjectActivityProvider.future,
      );
      expect(initial.activeProjects.single.integration.acceptedSeconds, 0);
      expect(initial.activeProjects.single.integration.targetSeconds, 3600);

      sessions = [
        ObservationSession(
          id: 's1',
          projectId: 'p1',
          startedAtUtc: DateTime.utc(2026, 11, 1),
          timeZoneId: 'Etc/UTC',
          utcOffsetMinutes: 0,
          exposureSeconds: 90,
          frameCount: 10,
          acceptedFrames: 8,
          rejectedFrames: 2,
        ),
      ];
      container.invalidate(observationSessionsForProjectProvider('p1'));
      final withSessions = await container.read(
        dashboardProjectActivityProvider.future,
      );
      expect(
        withSessions.activeProjects.single.integration.acceptedSeconds,
        720,
      );
      expect(withSessions.recentSessions, hasLength(1));

      project = project.copyWith(
        plannedIntegrationSeconds: 1800,
        updatedAtUtc: DateTime.utc(2026, 11, 3),
      );
      container.invalidate(plannedProjectsListProvider);
      final withGoal = await container.read(
        dashboardProjectActivityProvider.future,
      );
      expect(withGoal.activeProjects.single.integration.targetSeconds, 1800);
    },
  );
}
