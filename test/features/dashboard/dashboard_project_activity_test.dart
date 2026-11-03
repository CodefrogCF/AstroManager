import 'package:astromanager/features/dashboard/domain/dashboard_project_activity.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedImagingProject project(
  String id, {
  int goal = 3600,
  ImagingProjectStatus status = ImagingProjectStatus.inProgress,
}) => PlannedImagingProject(
  id: id,
  title: 'Project $id',
  targetIds: const [],
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 11, 1),
  status: status,
  plannedIntegrationSeconds: goal,
);

ObservationSession session(
  String id,
  String projectId, {
  int accepted = 12,
  int rejected = 8,
  int day = 2,
}) => ObservationSession(
  id: id,
  projectId: projectId,
  startedAtUtc: DateTime.utc(2026, 11, day, 20),
  timeZoneId: 'Etc/UTC',
  utcOffsetMinutes: 0,
  exposureSeconds: 30.5,
  frameCount: accepted + rejected,
  acceptedFrames: accepted,
  rejectedFrames: rejected,
);

void main() {
  test('project totals include accepted frames, not rejected frames', () {
    final result = DashboardProjectActivity.aggregate(
      projects: [project('p')],
      sessionsByProject: {
        'p': [session('s1', 'p'), session('s2', 'p', accepted: 4, rejected: 6)],
      },
    );
    final total = result.activeProjects.single.integration;
    expect(total.acceptedSeconds, (12 + 4) * 30.5);
    expect(total.acceptedFrames, 16);
    expect(total.rejectedFrames, 14);
    expect(total.targetSeconds, 3600);
    expect(total.remainingSeconds, 3600 - 16 * 30.5);
    expect(total.progressFraction, closeTo(16 * 30.5 / 3600, 0.00001));
  });

  test(
    'projects without a goal show integration without an arbitrary percent',
    () {
      final result = DashboardProjectActivity.aggregate(
        projects: [project('p', goal: 0)],
        sessionsByProject: {
          'p': [session('s', 'p')],
        },
      );
      final total = result.activeProjects.single.integration;
      expect(total.acceptedSeconds, 12 * 30.5);
      expect(total.progressPercent, isNull);
      expect(total.remainingSeconds, isNull);
      expect(total.progressFraction, isNull);
    },
  );

  test(
    'sessions are sorted by UTC instant; archived projects remain in history',
    () {
      final result = DashboardProjectActivity.aggregate(
        projects: [
          project('active'),
          project('archived', status: ImagingProjectStatus.archived),
        ],
        sessionsByProject: {
          'active': [session('old', 'active', day: 1)],
          'archived': [session('new', 'archived', day: 3)],
        },
      );
      expect(result.activeProjects.map((e) => e.project.id), ['active']);
      expect(result.recentSessions.map((e) => e.session.id), ['new', 'old']);
      expect(result.recentSessions.first.projectTitle, 'Project archived');
    },
  );

  test(
    'sessions from another project are never counted in a project total',
    () {
      final result = DashboardProjectActivity.aggregate(
        projects: [project('p')],
        sessionsByProject: {
          'p': [session('foreign', 'other')],
        },
      );
      expect(result.activeProjects.single.integration.acceptedSeconds, 0);
    },
  );
}
