import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.date,
  });
  final ObservingLocation location;
  final DateTime date;

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

  String get _nightDate =>
      '${widget.date.year.toString().padLeft(4, '0')}-'
      '${widget.date.month.toString().padLeft(2, '0')}-'
      '${widget.date.day.toString().padLeft(2, '0')}';

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText('Unable to save night plan: $error')),
    );
  }

  Future<void> _editBlock({
    required NightTimeline timeline,
    required List<PlannedImagingProject> projects,
    required Map<String, CelestialObject> targets,
    NightObservationBlock? existing,
    DateTime? suggestedUtc,
  }) async {
    final available = projects
        .where(
          (p) =>
              p.targetIds.isNotEmpty &&
              (p.status != ImagingProjectStatus.archived ||
                  p.id == existing?.projectId),
        )
        .toList();
    if (existing != null && !available.any((p) => p.id == existing.projectId)) {
      // Keep deleted/renamed project snapshots intact. A missing project
      // cannot be silently replaced with an unrelated one during editing.
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('Project unavailable'),
          content: AppText(
            'The saved project "${existing.projectName}" is no longer '
            'available. This block can be removed without changing other plans.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Delete block'),
            ),
          ],
        ),
      );
      if (remove != true || !mounted) {
        return;
      }
      final key = NightPlanKey(widget.location.id, _nightDate);
      try {
        await ref.read(nightPlansRepositoryProvider).remove(key, existing.id);
        ref.invalidate(nightPlansProvider(key));
      } catch (error) {
        _showError(error);
      }
      return;
    }
    if (available.isEmpty) {
      return;
    }
    final result = await showDialog<NightPlanEditResult>(
      context: context,
      builder: (context) => NightBlockEditorDialog(
        location: widget.location,
        timeline: timeline,
        projects: available,
        targets: targets,
        existing: existing,
        suggestedUtc: suggestedUtc,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final key = NightPlanKey(widget.location.id, _nightDate);
    setState(() => _saving = true);
    try {
      final repository = ref.read(nightPlansRepositoryProvider);
      switch (result) {
        case NightPlanSave(:final block):
          await repository.save(block);
        case NightPlanDelete(:final id):
          await repository.remove(key, id);
      }
      ref.invalidate(nightPlansProvider(key));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _content(
    NightTimeline timeline,
    List<PlannedImagingProject> projects,
    List<NightObservationBlock> blocks,
    Map<String, CelestialObject> targets,
  ) {
    final available = projects
        .where(
          (p) =>
              p.status != ImagingProjectStatus.archived &&
              p.targetIds.isNotEmpty,
        )
        .toList();
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
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
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
                onChanged: (value) => setState(() => _pixelsPerHour = value),
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
                    (step) =>
                        DropdownMenuItem(value: step, child: AppText('$step°')),
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
        if (_saving) const LinearProgressIndicator(),
        if (available.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: AppText(
              'Create an imaging project with a target to schedule observing blocks.',
            ),
          ),
        if (projects.expand((p) => p.targetIds).toSet().length > 12)
          const AppText(
            'Displaying the first 12 linked target altitude tracks.',
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
        const SizedBox(height: 8),
        if (conflicts.isNotEmpty)
          AppText(
            'Schedule conflict: ${conflicts.length} overlapping block(s) highlighted in red.',
            key: const ValueKey('night-plan-conflict'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        if (blocks.isNotEmpty)
          AppText(
            'Tap a scheduled bar to edit or remove it. Adjacent blocks do not conflict.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = SolarEvents.calculateForLocalDate(
      location: widget.location,
      localDate: widget.date,
    );
    final timeline = NightTimeline(day);
    final projects = ref.watch(plannedProjectsListProvider);
    final blocks = ref.watch(
      nightPlansProvider(NightPlanKey(widget.location.id, _nightDate)),
    );
    final targets = ref.watch(_plannerTargetsProvider);
    return Card(
      key: const ValueKey('night-planning-section'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Interactive night timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const AppText(
              'Local noon → next local noon · scroll horizontally to inspect the full night.',
            ),
            projects.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => AppText('Projects unavailable: $error'),
              data: (items) => blocks.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) =>
                    AppText('Saved schedule unavailable: $error'),
                data: (planned) => _content(
                  timeline,
                  items,
                  planned,
                  targets.value ?? const <String, CelestialObject>{},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
