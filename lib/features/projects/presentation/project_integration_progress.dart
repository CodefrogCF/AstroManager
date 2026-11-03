import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/observation_sessions_repository.dart';
import '../domain/integration_time_calculator.dart';
import '../domain/planned_imaging_project.dart';

/// The repository-backed session provider is shared with the session editor.
/// Invalidating it after add/edit/delete also refreshes the project totals.
class ProjectIntegrationProgress extends ConsumerWidget {
  const ProjectIntegrationProgress({super.key, required this.project});

  final PlannedImagingProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(
      observationSessionsForProjectProvider(project.id),
    );
    return switch (sessions) {
      AsyncData(value: final data) => _IntegrationProgressDetails(
        key: ValueKey('project-integration-${project.id}'),
        summary: IntegrationTimeCalculator.forProject(project, data),
      ),
      AsyncError(:final error) => AppText('Integration unavailable: $error'),
      _ => const LinearProgressIndicator(),
    };
  }
}

class _IntegrationProgressDetails extends StatelessWidget {
  const _IntegrationProgressDetails({super.key, required this.summary});

  final ProjectIntegrationSummary summary;

  @override
  Widget build(BuildContext context) {
    final achieved = IntegrationTimeFormatter.format(summary.acceptedSeconds);
    final target = IntegrationTimeFormatter.format(summary.targetSeconds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Usable integration: $achieved',
          key: const ValueKey('project-integration-accepted'),
        ),
        AppText(
          'Sessions: ${summary.sessionCount} · '
          'Accepted frames: ${summary.acceptedFrames} · '
          'Rejected frames excluded: ${summary.rejectedFrames}',
        ),
        if (!summary.hasTarget)
          const AppText(
            'No integration target set; all usable time is still tracked.',
          ),
        if (summary.hasTarget) ...[
          AppText(
            'Goal: $target · Progress: '
            '${summary.progressPercent!.toStringAsFixed(1)}%',
            key: const ValueKey('project-integration-percent'),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const ValueKey('project-integration-bar'),
            value: summary.progressFraction,
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          AppText(
            summary.targetReached
                ? 'Integration target reached.'
                : 'Remaining: ${IntegrationTimeFormatter.format(summary.remainingSeconds!)}',
          ),
        ],
      ],
    );
  }
}

/// Compact reactive readout for each project in the overview list.
class ProjectIntegrationListSummary extends ConsumerWidget {
  const ProjectIntegrationListSummary({super.key, required this.project});

  final PlannedImagingProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(
      observationSessionsForProjectProvider(project.id),
    );
    return switch (sessions) {
      AsyncData(value: final data) => Builder(
        builder: (context) {
          final summary = IntegrationTimeCalculator.forProject(project, data);
          final formatted = IntegrationTimeFormatter.format(
            summary.acceptedSeconds,
          );
          return AppText(
            summary.hasTarget
                ? 'Integration: $formatted / '
                      '${IntegrationTimeFormatter.format(summary.targetSeconds)} '
                      '(${summary.progressPercent!.toStringAsFixed(1)}%)'
                : 'Integration: $formatted · No target',
            key: ValueKey('project-list-integration-${project.id}'),
          );
        },
      ),
      AsyncError() => const AppText('Integration unavailable'),
      _ => const AppText('Loading integration…'),
    };
  }
}
