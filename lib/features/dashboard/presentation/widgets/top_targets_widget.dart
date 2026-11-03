import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/astronomy/astronomical_coordinates.dart';
import '../../../../core/astronomy/lunar_ephemeris.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../l10n/app_text.dart';
import '../../../discovery/domain/discovery_results.dart';
import '../../../intelligence/domain/models/suitability_score.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../../planner/data/night_plans_repository.dart';
import '../../../planner/domain/night_observation_block.dart';
import '../../../projects/data/planned_projects_repository.dart';
import '../../../projects/domain/planned_imaging_project.dart';
import '../../../weather/domain/models/weather_cache.dart';
import '../../../weather/application/weather_providers.dart';
import '../../application/top_targets_provider.dart';
import '../../domain/dashboard_layout.dart';
import '../../domain/top_targets.dart';
import 'dashboard_widget_state.dart';

/// A self-contained provider consumer: when hidden, no candidate, weather,
/// project or ranking requests are made. A failure does not affect the grid.
class TopTargetsWidget extends ConsumerWidget {
  const TopTargetsWidget({
    super.key,
    required this.location,
    required this.instance,
  });

  final ObservingLocation? location;
  final DashboardWidgetInstance instance;

  static Widget _unused(BuildContext context, Object data) =>
      const SizedBox.shrink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty('No observing location selected.'),
        dataBuilder: _unused,
      );
    }
    final sourceName =
        instance.settings['candidateSource'] as String? ?? 'combined';
    final durationName =
        instance.settings['minimumDurationMinutes'] as String? ?? '60';
    final query = (
      locationId: site.id,
      nightDate: DashboardTargetSelection.nightKey(
        DashboardTargetSelection.currentNight(site, DateTime.now().toUtc()),
      ),
      source: DashboardTargetSource.values.byName(sourceName),
      minimumDurationMinutes: int.parse(durationName),
    );
    final results = ref.watch(topTargetsProvider(query));
    return results.when(
      loading: () => const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.loading(),
        dataBuilder: _unused,
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Unable to calculate target recommendations.'),
          const SizedBox(height: 6),
          TextButton.icon(
            key: const ValueKey('dashboard-target-retry'),
            onPressed: () => ref.invalidate(topTargetsProvider(query)),
            icon: const Icon(Icons.refresh),
            label: const AppText('Retry'),
          ),
        ],
      ),
      data: (data) => _TopTargetsContent(
        site: site,
        data: data,
        onRefresh: () => ref.invalidate(topTargetsProvider(query)),
      ),
    );
  }
}

class _TopTargetsContent extends ConsumerWidget {
  const _TopTargetsContent({
    required this.site,
    required this.data,
    required this.onRefresh,
  });
  final ObservingLocation site;
  final TopTargetsResult data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = data.weather;
    final freshnessPolicy = ref.watch(weatherCachePolicyProvider);
    final stale =
        snapshot == null ||
        snapshot.isStale ||
        snapshot.isStaleAt(DateTime.now().toUtc(), freshnessPolicy) ||
        snapshot.origin == WeatherForecastOrigin.staleCache ||
        snapshot.origin == WeatherForecastOrigin.staleFallback;
    return Column(
      key: const ValueKey('dashboard-top-targets'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppText(
              DashboardTargetSelection.nightKey(data.nightDate),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (snapshot == null)
              const AppText('Weather unavailable · provisional scores')
            else ...[
              Text(
                snapshot.forecast.provider.name,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (stale) const AppText('Stale weather · provisional scores'),
              if (snapshot.isOfflineFallback) const AppText('Offline cache'),
            ],
            IconButton(
              key: const ValueKey('dashboard-target-refresh'),
              tooltip: appTranslate(context, 'Recalculate recommendations'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
        if (data.ranked.isEmpty) ...[
          const SizedBox(height: 8),
          AppText(
            data.considered == 0
                ? 'No candidate targets. Add projects or favorites, or select Catalog.'
                : 'No qualifying targets for this night and minimum duration.',
          ),
        ],
        for (var index = 0; index < data.ranked.length; index++) ...[
          if (index > 0) const Divider(height: 10),
          _TargetEntry(
            rank: index + 1,
            value: data.ranked[index],
            site: site,
            result: data,
            onPlan: () =>
                _addNightBlock(context, ref, site, data, data.ranked[index]),
          ),
        ],
        if (data.ranked.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${data.considered} ${appTranslate(context, 'candidates evaluated')} · '
            '${appTranslate(context, 'Top 3 use the existing suitability model.')}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}

class _TargetEntry extends StatelessWidget {
  const _TargetEntry({
    required this.rank,
    required this.value,
    required this.site,
    required this.result,
    required this.onPlan,
  });
  final int rank;
  final RankedDiscoveryTarget value;
  final ObservingLocation site;
  final TopTargetsResult result;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final window = value.window;
    final object = value.object;
    final instant =
        window.bestAltitudeAtUtc ??
        window.startUtc.add(
          Duration(microseconds: window.duration.inMicroseconds ~/ 2),
        );
    final observer = ObserverPosition(
      latitudeDegrees: site.latitude,
      longitudeDegrees: site.longitude,
      elevationMeters: site.elevationMeters,
    );
    final j2000 = EquatorialPosition(
      raDegrees: object.raDegrees,
      decDegrees: object.decDegrees,
    );
    final moon = LunarEphemeris.conditionsForTarget(
      at: instant,
      observer: observer,
      targetJ2000: j2000,
    );
    final target = AstronomicalCoordinates.calculateJ2000(
      j2000: j2000,
      observer: observer,
      time: instant,
    );
    final azimuth = target.horizontal.azimuthDegrees;
    final horizon = azimuth == null
        ? null
        : result.terrain?.altitudeAt(azimuth);
    final blocked =
        horizon != null && target.horizontal.altitudeDegrees < horizon;
    final obstructionNote = blocked
        ? ' · ${appTranslate(context, 'possible obstruction')}'
        : '';
    final zone = SolarEvents.timeZone(site.timeZone);
    String clock(DateTime time) => SolarEvents.formatLocal(
      tz.TZDateTime.from(time, zone),
      includeDate: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$rank.', style: Theme.of(context).textTheme.titleMedium),
            Text(
              object.displayTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${window.score.score.round()}/100',
              key: ValueKey('top-target-score-${object.id}'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (window.isProvisional) const AppText('Provisional'),
          ],
        ),
        Text(
          '${clock(window.startUtc)} – ${clock(window.endUtc)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 3,
          children: [
            Text(
              '${appTranslate(context, 'Peak altitude')}: '
              '${window.bestAltitudeDegrees?.toStringAsFixed(0) ?? '—'}°',
            ),
            Text(
              '${appTranslate(context, 'Moon separation')}: '
              '${moon.targetSeparationDegrees.toStringAsFixed(0)}°',
            ),
          ],
        ),
        if (horizon == null)
          const AppText('Terrain horizon not available; not included in score.')
        else
          Text(
            '${appTranslate(context, 'Cached terrain at peak bearing')}: '
            '${horizon.toStringAsFixed(1)}°'
            '$obstructionNote'
            ' · ${appTranslate(context, 'not included in score.')}',
          ),
        Wrap(
          spacing: 5,
          runSpacing: 2,
          children: [
            TextButton.icon(
              key: ValueKey('top-target-atlas-${object.id}'),
              onPressed: () => context.push(AppRoutes.atlas, extra: object),
              icon: const Icon(Icons.public, size: 17),
              label: const AppText('Sky Atlas'),
            ),
            TextButton.icon(
              key: ValueKey('top-target-plan-${object.id}'),
              onPressed: onPlan,
              icon: const Icon(Icons.event_available_outlined, size: 17),
              label: const AppText('Plan observation'),
            ),
          ],
        ),
        ExpansionTile(
          key: ValueKey('top-target-explanation-${object.id}'),
          title: const AppText('Why this score?'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final factor in SuitabilityFactor.values)
              if (window.score.factors.containsKey(factor))
                ListTile(
                  dense: true,
                  title: AppText(factor.label),
                  subtitle: AppText(window.score.factors[factor]!.explanation),
                  trailing: Text(
                    window.score.factors[factor]!.rawScore == null
                        ? '—'
                        : '${window.score.factors[factor]!.rawScore!.round()}/100',
                  ),
                ),
            if (window.score.constraints.isNotEmpty)
              for (final reason in window.score.constraints) AppText(reason),
            AppText(window.explanation),
            Text(
              '${appTranslate(context, 'Weather coverage')}: '
              '${(window.weatherTimeCoverage * 100).round()}% · '
              '${appTranslate(context, window.weatherStatus.name)}',
            ),
          ],
        ),
      ],
    );
  }
}

/// Store a plan via the existing night-plan repository, never a parallel store.
/// The UI requires an explicit choice of an existing linked project, or an
/// explicit decision to create a new project for this target.
Future<void> _addNightBlock(
  BuildContext context,
  WidgetRef ref,
  ObservingLocation site,
  TopTargetsResult data,
  RankedDiscoveryTarget ranked,
) async {
  final now = DateTime.now().toUtc();
  final start = ranked.window.startUtc.isAfter(now)
      ? ranked.window.startUtc
      : now;
  if (!ranked.window.endUtc.isAfter(start)) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: AppText('This observing window has ended.')),
      );
    }
    return;
  }
  try {
    final all = await ref.read(plannedProjectsListProvider.future);
    final eligible = all
        .where(
          (project) =>
              (project.status == ImagingProjectStatus.planned ||
                  project.status == ImagingProjectStatus.inProgress) &&
              project.targetIds.contains(ranked.object.id) &&
              (project.locationId == null || project.locationId == site.id),
        )
        .toList();
    if (!context.mounted) {
      return;
    }
    final selection = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Plan observation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              '${ranked.object.displayTitle} · '
              '${DashboardTargetSelection.nightKey(data.nightDate)}',
            ),
            const SizedBox(height: 8),
            const AppText('Choose a project for this target:'),
            for (final project in eligible)
              TextButton(
                key: ValueKey('top-target-project-${project.id}'),
                onPressed: () => Navigator.pop(dialogContext, project.id),
                child: Text(project.title),
              ),
            TextButton.icon(
              key: const ValueKey('top-target-new-project'),
              onPressed: () => Navigator.pop(dialogContext, '__new__'),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const AppText('Create a new imaging project and plan'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Cancel'),
          ),
        ],
      ),
    );
    if (selection == null || !context.mounted) {
      return;
    }
    PlannedImagingProject project;
    final createsProject = selection == '__new__';
    if (createsProject) {
      final created = DateTime.now().toUtc();
      project = PlannedImagingProject(
        id: const Uuid().v4(),
        title: ranked.object.displayTitle,
        targetIds: [ranked.object.id],
        createdAtUtc: created,
        locationId: site.id,
      );
    } else {
      project = eligible.firstWhere((project) => project.id == selection);
    }
    final key = NightPlanKey(
      site.id,
      DashboardTargetSelection.nightKey(data.nightDate),
    );
    final block = NightObservationBlock(
      id: const Uuid().v4(),
      locationId: site.id,
      nightDate: key.nightDate,
      timeZoneId: site.timeZone,
      projectId: project.id,
      targetId: ranked.object.id,
      projectName: project.title,
      targetName: ranked.object.displayTitle,
      startUtc: start,
      endUtc: ranked.window.endUtc,
    );
    final repo = ref.read(nightPlansRepositoryProvider);
    final existing = await repo.forNight(key);
    final conflicts = NightPlanConflicts.detect([...existing, block]);
    if (conflicts[block.id]?.isNotEmpty == true && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Overlapping observation'),
          content: const AppText(
            'This block overlaps another plan. Save it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Save'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }
    if (createsProject) {
      await ref.read(plannedProjectsRepositoryProvider).save(project);
    }
    await repo.save(block);
    if (createsProject) {
      ref.invalidate(plannedProjectsListProvider);
    }
    ref.invalidate(nightPlansProvider(key));
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: AppText('Observation added to Night Planner.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${appTranslate(context, 'Could not save observation')}: $error',
          ),
        ),
      );
    }
  }
}
