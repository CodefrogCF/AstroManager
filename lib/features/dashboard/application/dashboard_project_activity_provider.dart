import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/data/observation_sessions_repository.dart';
import '../../projects/data/planned_projects_repository.dart';
import '../../projects/domain/observation_session.dart';
import '../domain/dashboard_project_activity.dart';

/// Shared by both dashboard activity widgets. Watches existing providers so
/// session edits and project-goal updates invalidate the aggregation. It is
/// evaluated only while at least one consumer widget is visible.
final dashboardProjectActivityProvider =
    FutureProvider.autoDispose<DashboardProjectActivity>((ref) async {
      final projects = await ref.watch(plannedProjectsListProvider.future);
      final results = await Future.wait([
        for (final project in projects)
          ref.watch(observationSessionsForProjectProvider(project.id).future),
      ]);
      final sessionsByProject = <String, List<ObservationSession>>{
        for (var i = 0; i < projects.length; i++) projects[i].id: results[i],
      };
      return DashboardProjectActivity.aggregate(
        projects: projects,
        sessionsByProject: sessionsByProject,
      );
    }, retry: (count, error) => null);
