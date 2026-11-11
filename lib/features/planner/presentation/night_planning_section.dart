import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../../core/astronomy/target_visibility.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../projects/data/planned_projects_repository.dart';
import '../../projects/domain/planned_imaging_project.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../weather/application/weather_providers.dart';
import '../../terrain/application/terrain_providers.dart';
import '../../terrain/domain/terrain_horizon.dart';
import '../../terrain/presentation/terrain_horizon_chart.dart';
import '../../weather/domain/providers/weather_provider.dart';
import '../data/night_plans_repository.dart';
import '../domain/night_observation_block.dart';
import '../domain/night_timeline.dart';
import 'night_block_editor_dialog.dart';
import 'night_timeline_chart.dart';

final _plannerTargetsProvider = FutureProvider<Map<String, CelestialObject>>((
  ref,
) async {
  final projects = await ref.watch(plannedProjectsListProvider.future);
  if (projects.isEmpty) {
    return {};
  }
  // Offline catalog first; if unavailable retain historical IDs and allow editing.
  try {
    await ref.watch(celestialCatalogProvider.future);
    final catalog = ref.watch(celestialCatalogRepositoryProvider);
    final ids = projects.expand((p) => p.targetIds).toSet();
    final found = <String, CelestialObject>{};
    for (final id in ids) {
      final object = await catalog.findById(id);
      if (object != null) {
        found[id] = object;
      }
    }
    return found;
  } catch (_) {
    return {};
  }
}, retry: (count, error) => null);

class NightPlanningSection extends ConsumerStatefulWidget {
  const NightPlanningSection({
    super.key,
    required this.location,
    required this.day,
    this.initialProjectId,
    this.initialTargetId,
  });
  final ObservingLocation location;
  final SolarDayEvents day;
  final String? initialProjectId;
  final String? initialTargetId;

  @override
  ConsumerState<NightPlanningSection> createState() =>
      _NightPlanningSectionState();
}

class _NightPlanningSectionState extends ConsumerState<NightPlanningSection> {
  double _pixelsPerHour = 70;
  bool _saving = false;
  bool _weatherRequested = false;
  bool _terrainEnabled = false;
  int _terrainAzimuthStep = 10;
  int _terrainRangeMeters = 15000;
  int _terrainDistanceStepMeters = 1000;
  double _minimumTargetAltitude = 30;

  NightPlanKey get _nightKey => NightPlanKey(
    widget.location.id,
    widget.day.localDate.toIso8601String().split('T').first,
  );

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${appTranslate(context, 'Unable to save night plan')}\n$error',
        ),
      ),
    );
  }

  Future<void> _persist(
    NightPlanKey key,
    Future<void> Function(NightPlansRepository) change,
  ) async {
    if (_saving) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _saving = true);
    try {
      await change(container.read(nightPlansRepositoryProvider));
      container.invalidate(nightPlansProvider(key));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBlock(NightObservationBlock block) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete observation block?'),
        content: Text('${block.targetName} · ${block.projectName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('night-block-confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete block'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final key = NightPlanKey(block.locationId, block.nightDate);
    await _persist(key, (repository) => repository.remove(key, block.id));
  }

  Future<void> _editBlock({
    required NightTimeline timeline,
    required List<PlannedImagingProject> projects,
    required Map<String, CelestialObject> targets,
    NightObservationBlock? existing,
    DateTime? suggestedUtc,
  }) async {
    if (_saving) return;
    final available = projects
        .where(
          (p) =>
              p.targetIds.isNotEmpty &&
              (p.status != ImagingProjectStatus.archived ||
                  p.id == existing?.projectId),
        )
        .toList();
    if (available.isEmpty && existing == null) return;
    final location = widget.location;
    final initialProjectId = widget.initialProjectId;
    final initialTargetId = widget.initialTargetId;
    final result = await showDialog<NightPlanEditResult>(
      context: context,
      builder: (context) => NightBlockEditorDialog(
        location: location,
        timeline: timeline,
        projects: available,
        targets: targets,
        existing: existing,
        suggestedUtc: suggestedUtc,
        initialProjectId: initialProjectId,
        initialTargetId: initialTargetId,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    switch (result) {
      case NightPlanSave(:final block):
        final key = NightPlanKey(block.locationId, block.nightDate);
        await _persist(key, (repository) => repository.save(block));
      case NightPlanDelete(:final block):
        await _deleteBlock(block);
    }
  }

  String _slotLabel(NightTimeline timeline, DateTime start, DateTime end) {
    final zone = SolarEvents.timeZone(timeline.day.timeZone);
    final date = timeline.day.localDate;
    final showOffset =
        tz.TZDateTime.from(timeline.startUtc, zone).timeZoneOffset !=
        tz.TZDateTime.from(timeline.endUtc, zone).timeZoneOffset;
    final labels = MaterialLocalizations.of(context);
    String label(DateTime instant) {
      final local = tz.TZDateTime.from(instant, zone);
      final clock = showOffset
          ? SolarEvents.formatLocal(local)
          : TimeOfDay.fromDateTime(local).format(context);
      return local.year == date.year &&
              local.month == date.month &&
              local.day == date.day
          ? clock
          : '${labels.formatShortMonthDay(local)} $clock';
    }

    return '${label(start)} – ${label(end)}';
  }

  String _durationLabel(Duration duration) =>
      '${duration.inHours} h ${duration.inMinutes.remainder(60)} min';

  Widget _scheduledBlocks(
    NightTimeline timeline,
    List<PlannedImagingProject> projects,
    List<NightObservationBlock> blocks,
    Map<String, CelestialObject> targets,
    Map<String, Set<String>> conflicts,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        AppText('Scheduled targets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (blocks.isEmpty) const AppText('No targets scheduled.'),
        for (final block in blocks) ...[
          const Divider(),
          Row(
            key: ValueKey('night-schedule-${block.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(block.targetName, style: theme.textTheme.titleSmall),
                    Text(block.projectName, style: theme.textTheme.bodySmall),
                    Text(_slotLabel(timeline, block.startUtc, block.endUtc)),
                    if (conflicts.containsKey(block.id))
                      AppText(
                        'Overlapping block',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('night-schedule-edit-${block.id}'),
                tooltip: appTranslate(context, 'Edit block'),
                onPressed: _saving
                    ? null
                    : () => _editBlock(
                        timeline: timeline,
                        projects: projects,
                        targets: targets,
                        existing: block,
                      ),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('night-schedule-delete-${block.id}'),
                tooltip: appTranslate(context, 'Delete block'),
                onPressed: _saving ? null : () => _deleteBlock(block),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _content(
    NightTimeline timeline,
    List<PlannedImagingProject> projects,
    List<NightObservationBlock> blocks,
    Map<String, CelestialObject> targets, {
    required bool projectsLoaded,
  }) {
    final available = projects
        .where(
          (p) =>
              p.status != ImagingProjectStatus.archived &&
              p.targetIds.isNotEmpty,
        )
        .toList();
    final linked = available
        .where(
          (project) =>
              project.id == widget.initialProjectId &&
              project.targetIds.contains(widget.initialTargetId),
        )
        .firstOrNull;
    final terrainRequest = (
      site: widget.location,
      azimuthStep: _terrainAzimuthStep,
      rangeMeters: _terrainRangeMeters,
      distanceStep: _terrainDistanceStepMeters,
    );
    final terrainState = _terrainEnabled
        ? ref.watch(terrainHorizonProvider(terrainRequest))
        : null;
    final terrainProfile = terrainState?.value;
    final visible = <String, TargetVisibilityResult>{};
    var terrainObstructedTargets = 0;
    final uniqueTargets = available.expand((p) => p.targetIds).toSet().take(12);
    for (final id in uniqueTargets) {
      final target = targets[id];
      if (target == null) {
        continue;
      }
      final calculated = NightTargetVisibility.calculate(
        timeline: timeline,
        site: widget.location,
        raDegrees: target.raDegrees,
        decDegrees: target.decDegrees,
        minimumAltitudeDegrees: _minimumTargetAltitude,
        terrainHorizon: terrainProfile,
      );
      visible[target.displayTitle] = calculated;
      if (terrainProfile != null) {
        final unobstructed = NightTargetVisibility.calculate(
          timeline: timeline,
          site: widget.location,
          raDegrees: target.raDegrees,
          decDegrees: target.decDegrees,
          minimumAltitudeDegrees: _minimumTargetAltitude,
        );
        if (calculated.totalVisibleDuration <
            unobstructed.totalVisibleDuration) {
          terrainObstructedTargets++;
        }
      }
    }
    final now = DateTime.now().toUtc();
    // Weather providers cannot return historical or arbitrarily distant hours.
    final forecastEligible =
        timeline.endUtc.isAfter(now) &&
        timeline.startUtc.isBefore(now.add(const Duration(days: 14)));
    final request = WeatherForecastRequest(
      latitudeDegrees: widget.location.latitude,
      longitudeDegrees: widget.location.longitude,
      startUtc: timeline.startUtc,
      endUtc: timeline.endUtc,
    );
    final forecast =
        forecastEligible && (available.isNotEmpty || _weatherRequested)
        ? ref.watch(weatherForecastSnapshotProvider(request))
        : null;
    final policy = ref.watch(weatherCachePolicyProvider);
    final snapshot = forecast?.value;
    final conflicts = NightPlanConflicts.detect(blocks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (linked != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${linked.title} · ${targets[widget.initialTargetId]?.displayTitle ?? widget.initialTargetId}',
              key: const ValueKey('night-plan-selected-target'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        FilledButton.icon(
          key: const ValueKey('night-plan-add'),
          onPressed: _saving || available.isEmpty
              ? null
              : () => _editBlock(
                  timeline: timeline,
                  projects: projects,
                  targets: targets,
                ),
          icon: const Icon(Icons.add),
          label: const AppText('Schedule target'),
        ),
        if (projectsLoaded && available.isEmpty)
          const AppText(
            'Create an imaging project with a target to schedule observing blocks.',
          ),
        if (_saving) const LinearProgressIndicator(),
        if (blocks.isNotEmpty && timeline.day.astronomicalDarkness.isNotEmpty)
          Text(
            '${appTranslate(context, 'Unscheduled darkness')} · '
            '${_durationLabel(timeline.unscheduledDarkness(blocks))}',
          ),
        _scheduledBlocks(timeline, projects, blocks, targets, conflicts),
        const Divider(height: 28),
        AppText(
          'Interactive night timeline',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const AppText(
          'Local noon → next local noon · scroll horizontally to inspect the full night.',
        ),
        const SizedBox(height: 8),
        NightTimelineChart(
          timeline: timeline,
          location: widget.location,
          visibility: Map.unmodifiable(visible),
          blocks: blocks,
          weather: snapshot,
          pixelsPerHour: _pixelsPerHour,
          onEdit: (block) => _editBlock(
            timeline: timeline,
            projects: projects,
            targets: targets,
            existing: block,
          ),
          onCreateAt: (instant) => _editBlock(
            timeline: timeline,
            projects: projects,
            targets: targets,
            suggestedUtc: instant,
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const AppText('Timeline options'),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (forecastEligible && available.isEmpty)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _weatherRequested = true),
                    icon: const Icon(Icons.cloud_outlined),
                    label: const AppText('Show weather'),
                  ),
                const AppText('Timeline zoom'),
                SizedBox(
                  width: 140,
                  child: Slider(
                    key: const ValueKey('night-timeline-zoom'),
                    min: 48,
                    max: 120,
                    divisions: 6,
                    value: _pixelsPerHour,
                    onChanged: (value) =>
                        setState(() => _pixelsPerHour = value),
                  ),
                ),
                AppText(
                  '${timeline.duration.inHours} h · ${widget.location.timeZone}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppText(
                  'Minimum target altitude: ${_minimumTargetAltitude.toStringAsFixed(0)}°',
                ),
                SizedBox(
                  width: 180,
                  child: Slider(
                    key: const ValueKey('night-minimum-altitude'),
                    min: 0,
                    max: 60,
                    divisions: 12,
                    value: _minimumTargetAltitude,
                    onChanged: (value) =>
                        setState(() => _minimumTargetAltitude = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  key: const ValueKey('night-terrain-toggle'),
                  label: const AppText('Use terrain horizon'),
                  selected: _terrainEnabled,
                  onSelected: (enabled) =>
                      setState(() => _terrainEnabled = enabled),
                ),
                const AppText('Azimuth step'),
                DropdownButton<int>(
                  key: const ValueKey('night-terrain-azimuth-step'),
                  value: _terrainAzimuthStep,
                  items: [5, 10, 15, 30]
                      .map(
                        (step) => DropdownMenuItem(
                          value: step,
                          child: AppText('$step°'),
                        ),
                      )
                      .toList(),
                  onChanged: (step) {
                    if (step != null) {
                      setState(() => _terrainAzimuthStep = step);
                    }
                  },
                ),
                const AppText('Range'),
                DropdownButton<int>(
                  key: const ValueKey('night-terrain-range'),
                  value: _terrainRangeMeters,
                  items: [5000, 15000, 25000]
                      .map(
                        (range) => DropdownMenuItem(
                          value: range,
                          child: AppText('${range ~/ 1000} km'),
                        ),
                      )
                      .toList(),
                  onChanged: (range) {
                    if (range != null) {
                      setState(() => _terrainRangeMeters = range);
                    }
                  },
                ),
                const AppText('Radial step'),
                DropdownButton<int>(
                  key: const ValueKey('night-terrain-distance-step'),
                  value: _terrainDistanceStepMeters,
                  items: [1000, 2000, 5000]
                      .map(
                        (step) => DropdownMenuItem(
                          value: step,
                          child: AppText('${step ~/ 1000} km'),
                        ),
                      )
                      .toList(),
                  onChanged: (step) {
                    if (step != null) {
                      setState(() => _terrainDistanceStepMeters = step);
                    }
                  },
                ),
              ],
            ),
            if (_terrainEnabled) ...[
              if (terrainState?.isLoading ?? false)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      AppText(
                        'Calculating terrain horizon (online fetch or local cache)…',
                      ),
                    ],
                  ),
                ),
              if (terrainState?.hasError ?? false)
                const AppText(
                  'Terrain elevation unavailable. Existing geometric visibility remains active. '
                  'Try again when connected; previous night plans are not affected.',
                ),
              if (terrainProfile != null) ...[
                const SizedBox(height: 8),
                TerrainHorizonChart(profile: terrainProfile),
                AppText(
                  'Elevation source: ${terrainProfile.sourceId} · '
                  '${terrainProfile.knownBearings}/${terrainProfile.bearings.length} bearings covered · '
                  'profile ${terrainProfile.createdAtUtc.toIso8601String()} UTC.',
                ),
                AppText(
                  'Terrain obstruction reduces visible time for $terrainObstructedTargets '
                  'of ${visible.length} displayed target(s).',
                ),
                if (!terrainProfile.isComplete)
                  const AppText(
                    'Incomplete DEM coverage: visibility is uncertain at missing bearings.',
                  ),
                TextButton.icon(
                  key: const ValueKey('night-terrain-refresh'),
                  onPressed: () async {
                    await ref
                        .read(terrainProfileRepositoryProvider)
                        .remove(
                          widget.location,
                          TerrainHorizonOptions(
                            azimuthStepDegrees: _terrainAzimuthStep,
                            maximumDistanceMeters: _terrainRangeMeters,
                            distanceStepMeters: _terrainDistanceStepMeters,
                          ),
                        );
                    if (mounted) {
                      ref.invalidate(terrainHorizonProvider(terrainRequest));
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const AppText('Refresh terrain profile'),
                ),
              ],
              const AppText(
                'Approximate terrain-only horizon: buildings, trees and small obstacles '
                'are excluded. This is not a guaranteed line-of-sight prediction.',
              ),
            ],
          ],
        ),
        if (projects.expand((p) => p.targetIds).toSet().length > 12)
          const AppText(
            'Displaying the first 12 linked target altitude tracks.',
          ),
        AppText(
          'Altitude curves show geometric target height. Visibility windows are '
          'above ${_minimumTargetAltitude.toStringAsFixed(0)}° in astronomical darkness'
          '${terrainProfile == null ? ' (unobstructed mathematical horizon).' : ' and above the sampled terrain horizon.'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (forecastEligible && forecast == null)
          const AppText('Weather forecast available on request.')
        else if (!forecastEligible)
          const AppText(
            'Weather: no forecast for this date (outside the supported future window).',
          )
        else if (forecast?.isLoading ?? false)
          const AppText('Loading weather forecast…')
        else if (forecast?.hasError ?? false)
          const AppText(
            'Weather unavailable; observation planning works offline.',
          )
        else if (snapshot != null)
          AppText(
            'Weather: ${snapshot.forecast.provider.name} · '
            '${snapshot.isStaleAt(now, policy) ? 'STALE cached data' : 'current forecast'}'
            ' · fetched ${snapshot.forecast.fetchedAtUtc.toIso8601String()} UTC.',
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final timeline = NightTimeline(day);
    final projects = ref.watch(plannedProjectsListProvider);
    final blocks = ref.watch(nightPlansProvider(_nightKey));
    final targets = ref.watch(_plannerTargetsProvider);
    return Card(
      key: const ValueKey('night-planning-section'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Night overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.location.name} · ${MaterialLocalizations.of(context).formatFullDate(day.localDate)}',
            ),
            const SizedBox(height: 12),
            AppText(
              'Astronomical darkness',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (day.astronomicalDarkness.isEmpty)
              const AppText('No astronomical darkness during this night.'),
            for (final interval in day.astronomicalDarkness)
              Text(
                '${_slotLabel(timeline, interval.startUtc, interval.endUtc)} · '
                '${_durationLabel(interval.duration)}',
                key: ValueKey(
                  'darkness-${interval.startUtc.toIso8601String()}',
                ),
              ),
            if (projects.isLoading && !projects.hasValue)
              const LinearProgressIndicator(),
            if (projects.hasError)
              AppText('Projects unavailable: ${projects.error}'),
            blocks.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) =>
                  AppText('Saved schedule unavailable: $error'),
              data: (planned) => _content(
                timeline,
                projects.value ?? const <PlannedImagingProject>[],
                planned,
                targets.value ?? const <String, CelestialObject>{},
                projectsLoaded: projects.hasValue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
