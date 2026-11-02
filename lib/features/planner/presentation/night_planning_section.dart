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

  String get _nightDate =>
      '${widget.date.year.toString().padLeft(4, '0')}-'
      '${widget.date.month.toString().padLeft(2, '0')}-'
      '${widget.date.day.toString().padLeft(2, '0')}';

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to save night plan: $error')),
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
          title: const Text('Project unavailable'),
          content: Text(
            'The saved project "${existing.projectName}" is no longer '
            'available. This block can be removed without changing other plans.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete block'),
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
    final visible = <String, TargetVisibilityResult>{};
    final uniqueTargets = available.expand((p) => p.targetIds).toSet().take(12);
    for (final id in uniqueTargets) {
      final target = targets[id];
      if (target == null) {
        continue;
      }
      visible[target.displayTitle] = NightTargetVisibility.calculate(
        timeline: timeline,
        site: widget.location,
        raDegrees: target.raDegrees,
        decDegrees: target.decDegrees,
      );
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
              label: const Text('Schedule target'),
            ),
            if (forecastEligible && available.isEmpty)
              OutlinedButton.icon(
                onPressed: () => setState(() => _weatherRequested = true),
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Show weather'),
              ),
            const Text('Timeline zoom'),
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
            Text(
              '${timeline.duration.inHours} h · ${widget.location.timeZone}',
            ),
          ],
        ),
        if (_saving) const LinearProgressIndicator(),
        if (available.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Create an imaging project with a target to schedule observing blocks.',
            ),
          ),
        if (projects.expand((p) => p.targetIds).toSet().length > 12)
          const Text('Displaying the first 12 linked target altitude tracks.'),
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
          Text(
            'Schedule conflict: ${conflicts.length} overlapping block(s) highlighted in red.',
            key: const ValueKey('night-plan-conflict'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Text(
          'Altitude curves show geometric target height; shaded intervals are '
          'above 30° during astronomical darkness. The horizon is unobstructed '
          'and terrain is not modeled.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (forecastEligible && forecast == null)
          const Text('Weather forecast available on request.')
        else if (!forecastEligible)
          const Text(
            'Weather: no forecast for this date (outside the supported future window).',
          )
        else if (forecast?.isLoading ?? false)
          const Text('Loading weather forecast…')
        else if (forecast?.hasError ?? false)
          const Text('Weather unavailable; observation planning works offline.')
        else if (snapshot != null)
          Text(
            'Weather: ${snapshot.forecast.provider.name} · '
            '${snapshot.isStaleAt(now, policy) ? 'STALE cached data' : 'current forecast'}'
            ' · fetched ${snapshot.forecast.fetchedAtUtc.toIso8601String()} UTC.',
          ),
        const SizedBox(height: 8),
        if (blocks.isNotEmpty)
          Text(
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
            Text(
              'Interactive night timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Local noon → next local noon · scroll horizontally to inspect the full night.',
            ),
            projects.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Projects unavailable: $error'),
              data: (items) => blocks.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) =>
                    Text('Saved schedule unavailable: $error'),
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
