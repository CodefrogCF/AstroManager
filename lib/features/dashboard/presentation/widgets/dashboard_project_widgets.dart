import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_text.dart';
import '../../../projects/domain/integration_time_calculator.dart';
import '../../../projects/presentation/project_detail_screen.dart';
import '../../application/dashboard_project_activity_provider.dart';
import '../../domain/dashboard_project_activity.dart';

/// No repository subscription exists until this widget is actually mounted.
class DashboardActiveProjectsWidget extends ConsumerWidget {
  const DashboardActiveProjectsWidget({super.key, this.limit = 3});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dashboardProjectActivityProvider);
    return activity.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const AppText('Unable to load project progress.'),
      data: (snapshot) {
        if (snapshot.activeProjects.isEmpty) {
          return const AppText(
            'No active imaging projects. Create one in Projects.',
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 310;
            return Column(
              key: const ValueKey('dashboard-active-projects'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in snapshot.activeProjects.take(limit))
                  _ProjectRow(entry: entry, compact: compact),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.entry, required this.compact});
  final DashboardProjectProgress entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final project = entry.project;
    final summary = entry.integration;
    final accepted = IntegrationTimeFormatter.format(summary.acceptedSeconds);
    final planned = summary.hasTarget
        ? IntegrationTimeFormatter.format(summary.targetSeconds)
        : null;
    final remaining = summary.remainingSeconds;
    return Semantics(
      label:
          '${project.title}, ${appTranslate(context, 'Accepted integration')}: $accepted',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              key: ValueKey('dashboard-project-${project.id}'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ProjectDetailScreen(project: project),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (summary.hasTarget) ...[
              LinearProgressIndicator(
                key: ValueKey('dashboard-project-progress-${project.id}'),
                value: summary.progressFraction,
                semanticsLabel: appTranslate(context, 'Integration progress'),
              ),
              const SizedBox(height: 3),
              Text(
                '$accepted / $planned · ${summary.progressPercent!.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!compact)
                Text(
                  '${appTranslate(context, 'Remaining')}: '
                  '${IntegrationTimeFormatter.format(remaining!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ] else ...[
              Text(
                '${appTranslate(context, 'Accepted integration')}: $accepted',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!compact)
                const AppText(
                  'No integration goal set.',
                  style: TextStyle(fontSize: 12),
                ),
            ],
            if (!compact)
              Text(
                '${appTranslate(context, project.status.label)} · '
                '${summary.sessionCount} ${appTranslate(context, 'sessions')}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class DashboardRecentSessionsWidget extends ConsumerWidget {
  const DashboardRecentSessionsWidget({super.key, this.limit = 4});
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dashboardProjectActivityProvider);
    return activity.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const AppText('Unable to load recent sessions.'),
      data: (snapshot) {
        if (snapshot.recentSessions.isEmpty) {
          return const AppText('No observation sessions recorded yet.');
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 310;
            return Column(
              key: const ValueKey('dashboard-recent-sessions'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final activity in snapshot.recentSessions.take(limit))
                  _SessionRow(activity: activity, compact: narrow),
              ],
            );
          },
        );
      },
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.activity, required this.compact});
  final DashboardSessionActivity activity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final session = activity.session;
    // Use the offset recorded with the session, not the device's time zone.
    final local = session.startedAtUtc.add(
      Duration(minutes: session.utcOffsetMinutes),
    );
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${two(local.day)}.${two(local.month)}.${local.year}'
        ' ${two(local.hour)}:${two(local.minute)}';
    final duration = IntegrationTimeFormatter.format(activity.acceptedSeconds);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.projectTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '$date · $duration',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!compact)
            Text(
              '${session.acceptedFrames} ${appTranslate(context, 'accepted frames')} · '
              '${session.rejectedFrames} ${appTranslate(context, 'rejected frames')}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
