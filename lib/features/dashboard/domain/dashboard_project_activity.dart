import '../../projects/domain/integration_time_calculator.dart';
import '../../projects/domain/observation_session.dart';
import '../../projects/domain/planned_imaging_project.dart';

/// Independent, deterministic aggregation shared by the project and activity
/// widgets. Reuses the same accepted-frame calculator as project details.
final class DashboardProjectProgress {
  const DashboardProjectProgress({
    required this.project,
    required this.integration,
  });

  final PlannedImagingProject project;
  final ProjectIntegrationSummary integration;
}

final class DashboardSessionActivity {
  const DashboardSessionActivity({
    required this.session,
    required this.projectTitle,
  });

  final ObservationSession session;
  final String projectTitle;
  double get acceptedSeconds =>
      IntegrationTimeCalculator.acceptedSeconds(session);
}

final class DashboardProjectActivity {
  const DashboardProjectActivity({
    required this.activeProjects,
    required this.recentSessions,
  });

  final List<DashboardProjectProgress> activeProjects;
  final List<DashboardSessionActivity> recentSessions;

  static DashboardProjectActivity aggregate({
    required Iterable<PlannedImagingProject> projects,
    required Map<String, List<ObservationSession>> sessionsByProject,
  }) {
    final projectsList = projects.toList();
    final active = <DashboardProjectProgress>[];
    final activities = <DashboardSessionActivity>[];

    for (final project in projectsList) {
      final sessions =
          sessionsByProject[project.id] ?? const <ObservationSession>[];
      if (project.status == ImagingProjectStatus.planned ||
          project.status == ImagingProjectStatus.inProgress) {
        active.add(
          DashboardProjectProgress(
            project: project,
            integration: IntegrationTimeCalculator.forProject(
              project,
              sessions,
            ),
          ),
        );
      }
      for (final session in sessions) {
        if (session.projectId != project.id) continue;
        activities.add(
          DashboardSessionActivity(
            session: session,
            projectTitle: project.title,
          ),
        );
      }
    }

    active.sort((a, b) {
      final byUpdated = b.project.updatedAtUtc.compareTo(
        a.project.updatedAtUtc,
      );
      return byUpdated != 0 ? byUpdated : a.project.id.compareTo(b.project.id);
    });
    activities.sort((a, b) {
      final byDate = b.session.startedAtUtc.compareTo(a.session.startedAtUtc);
      return byDate != 0 ? byDate : a.session.id.compareTo(b.session.id);
    });
    return DashboardProjectActivity(
      activeProjects: List.unmodifiable(active),
      recentSessions: List.unmodifiable(activities),
    );
  }
}
