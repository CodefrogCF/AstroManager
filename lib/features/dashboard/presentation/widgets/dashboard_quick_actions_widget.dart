import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../l10n/app_text.dart';
import '../../../projects/data/observation_sessions_repository.dart';
import '../../../projects/data/planned_projects_repository.dart';
import '../../../projects/domain/observation_session.dart';
import '../../../projects/domain/planned_imaging_project.dart';
import '../../../projects/presentation/observation_session_editor_dialog.dart';
import '../../domain/dashboard_layout.dart';

/// The session picker is loaded only after the user explicitly selects the
/// corresponding quick action. All other actions remain offline shortcuts.
class DashboardQuickActionsWidget extends ConsumerWidget {
  const DashboardQuickActionsWidget({super.key, required this.instance});

  final DashboardWidgetInstance instance;

  bool enabled(String key, {required bool fallback}) =>
      instance.settings[key] is bool
      ? instance.settings[key] == true
      : fallback;

  Future<void> _logSession(BuildContext context, WidgetRef ref) async {
    final project = await showDialog<PlannedImagingProject>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (dialogContext, dialogRef, _) {
          final projects = dialogRef.watch(plannedProjectsListProvider);
          return AlertDialog(
            title: const AppText('Choose a project to log a session'),
            content: SizedBox(
              width: 400,
              height: 300,
              child: projects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const AppText('Unable to load projects.'),
                data: (items) {
                  final eligible = items
                      .where(
                        (project) =>
                            project.status != ImagingProjectStatus.archived,
                      )
                      .toList();
                  if (eligible.isEmpty) {
                    return const AppText(
                      'No projects available. Create a project first.',
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in eligible)
                        ListTile(
                          key: ValueKey('dashboard-log-project-${item.id}'),
                          title: Text(item.title),
                          onTap: () => Navigator.of(dialogContext).pop(item),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    if (project == null || !context.mounted) return;
    final session = await showDialog<ObservationSession>(
      context: context,
      builder: (_) => ObservationSessionEditorDialog(projectId: project.id),
    );
    if (session == null || !context.mounted) return;
    try {
      await ref.read(observationSessionsRepositoryProvider).save(session);
      if (!context.mounted) return;
      ref.invalidate(observationSessionsForProjectProvider(project.id));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: AppText('Observation session saved.')),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              '${appTranslate(context, 'Could not save session')}: $error',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = instance.settings['compact'] == true;
    final actions =
        <({String key, String label, IconData icon, VoidCallback action})>[
          if (enabled('showAtlas', fallback: true))
            (
              key: 'atlas',
              label: 'Sky Atlas',
              icon: Icons.public_outlined,
              action: () => context.go(AppRoutes.atlas),
            ),
          if (enabled('showPlanner', fallback: true))
            (
              key: 'planner',
              label: 'Night Planner',
              icon: Icons.calendar_month_outlined,
              action: () => context.go(AppRoutes.planner),
            ),
          if (enabled('showProjects', fallback: true))
            (
              key: 'projects',
              label: 'Projects',
              icon: Icons.folder_outlined,
              action: () => context.go(AppRoutes.projects),
            ),
          if (enabled('showSessions', fallback: true))
            (
              key: 'sessions',
              label: 'Log session',
              icon: Icons.add_a_photo_outlined,
              action: () => _logSession(context, ref),
            ),
          if (enabled('showTargets', fallback: false))
            (
              key: 'targets',
              label: 'Targets',
              icon: Icons.travel_explore_outlined,
              action: () => context.go(AppRoutes.targets),
            ),
          if (enabled('showEquipment', fallback: false))
            (
              key: 'equipment',
              label: 'Equipment',
              icon: Icons.camera_alt_outlined,
              action: () => context.go(AppRoutes.equipment),
            ),
        ];

    if (actions.isEmpty) {
      return const AppText(
        'Select at least one quick action in widget settings.',
      );
    }
    return Wrap(
      key: const ValueKey('dashboard-quick-actions'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          compact
              ? IconButton.outlined(
                  key: ValueKey('dashboard-quick-${action.key}'),
                  tooltip: appTranslate(context, action.label),
                  onPressed: action.action,
                  icon: Icon(action.icon),
                )
              : OutlinedButton.icon(
                  key: ValueKey('dashboard-quick-${action.key}'),
                  onPressed: action.action,
                  icon: Icon(action.icon, size: 18),
                  label: AppText(action.label),
                ),
      ],
    );
  }
}
