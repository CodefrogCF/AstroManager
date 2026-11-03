import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/astronomy/solar_events.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../projects/domain/planned_imaging_project.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../domain/night_observation_block.dart';
import '../domain/night_timeline.dart';

sealed class NightPlanEditResult {
  const NightPlanEditResult();
}

final class NightPlanSave extends NightPlanEditResult {
  const NightPlanSave(this.block);
  final NightObservationBlock block;
}

final class NightPlanDelete extends NightPlanEditResult {
  const NightPlanDelete(this.id);
  final String id;
}

/// The selected local date and starting clock are converted at the site,
/// not in the device's own timezone. Duration is an elapsed UTC duration.
class NightBlockEditorDialog extends StatefulWidget {
  const NightBlockEditorDialog({
    super.key,
    required this.location,
    required this.timeline,
    required this.projects,
    required this.targets,
    this.existing,
    this.suggestedUtc,
  });
  final ObservingLocation location;
  final NightTimeline timeline;
  final List<PlannedImagingProject> projects;
  final Map<String, CelestialObject> targets;
  final NightObservationBlock? existing;
  final DateTime? suggestedUtc;

  @override
  State<NightBlockEditorDialog> createState() => _NightBlockEditorDialogState();
}

class _NightBlockEditorDialogState extends State<NightBlockEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _minutes = TextEditingController(text: '60');
  final _notes = TextEditingController();
  late String _projectId;
  late String _targetId;
  late TimeOfDay _time;
  late bool _nextDay;
  String? _error;
  DateTime? _foldChoiceUtc;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final start =
        existing?.startUtc ??
        widget.suggestedUtc ??
        widget.timeline.startUtc.add(const Duration(hours: 8));
    final local = tz.TZDateTime.from(
      start,
      SolarEvents.timeZone(widget.location.timeZone),
    );
    final night = widget.timeline.day.localDate;
    _foldChoiceUtc = existing?.startUtc;
    _nextDay = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).isAfter(DateTime.utc(night.year, night.month, night.day));
    _time = TimeOfDay(hour: local.hour, minute: local.minute);
    final initial = widget.projects.first;
    _projectId =
        existing != null &&
            widget.projects.any((p) => p.id == existing.projectId)
        ? existing.projectId
        : initial.id;
    final project = widget.projects.firstWhere((p) => p.id == _projectId);
    _targetId =
        existing != null && project.targetIds.contains(existing.targetId)
        ? existing.targetId
        : project.targetIds.first;
    _minutes.text = existing?.duration.inMinutes.toString() ?? '60';
    _notes.text = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _minutes.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<DateTime> get _clockCandidates {
    final date = widget.timeline.day.localDate;
    final day = DateTime.utc(
      date.year,
      date.month,
      date.day + (_nextDay ? 1 : 0),
    );
    return NightLocalClock.candidates(
      timeZoneId: widget.location.timeZone,
      year: day.year,
      month: day.month,
      day: day.day,
      hour: _time.hour,
      minute: _time.minute,
    );
  }

  void _save() {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) {
      return;
    }
    final candidates = _clockCandidates;
    if (candidates.isEmpty) {
      setState(
        () => _error = 'This local time does not exist at the selected site.',
      );
      return;
    }
    final start = candidates.contains(_foldChoiceUtc)
        ? _foldChoiceUtc!
        : candidates.first;
    final end = start.add(Duration(minutes: int.parse(_minutes.text.trim())));
    if (!widget.timeline.contains(start, end)) {
      setState(
        () => _error = 'Block must fit inside the selected noon-to-noon night.',
      );
      return;
    }
    final project = widget.projects.firstWhere((p) => p.id == _projectId);
    final target = widget.targets[_targetId];
    final block = NightObservationBlock(
      id: widget.existing?.id ?? const Uuid().v4(),
      locationId: widget.location.id,
      nightDate: widget.timeline.day.localDate.toIso8601String().substring(
        0,
        10,
      ),
      timeZoneId: widget.location.timeZone,
      projectId: project.id,
      targetId: _targetId,
      projectName: project.title,
      targetName: target?.displayTitle ?? _targetId,
      startUtc: start,
      endUtc: end,
      notes: _notes.text.trim(),
    );
    Navigator.pop(context, NightPlanSave(block));
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.projects.firstWhere((p) => p.id == _projectId);
    return AlertDialog(
      title: AppText(
        widget.existing == null
            ? 'Add observation block'
            : 'Edit observation block',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('night-block-project'),
                  initialValue: _projectId,
                  isExpanded: true,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Imaging project'),
                  ),
                  items: [
                    for (final p in widget.projects)
                      DropdownMenuItem(
                        value: p.id,
                        child: AppText(
                          p.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    final next = widget.projects.firstWhere(
                      (p) => p.id == value,
                    );
                    setState(() {
                      _projectId = value;
                      _targetId = next.targetIds.first;
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('night-block-target-${project.id}'),
                  initialValue: _targetId,
                  isExpanded: true,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Celestial target'),
                  ),
                  items: [
                    for (final id in project.targetIds)
                      DropdownMenuItem(
                        value: id,
                        child: AppText(
                          widget.targets[id]?.displayTitle ?? id,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _targetId = value);
                  },
                ),
                const SizedBox(height: 10),
                AppText(
                  'Start · ${widget.location.timeZone}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const AppText('Evening (night date)'),
                      selected: !_nextDay,
                      onSelected: (_) => setState(() {
                        _nextDay = false;
                        _foldChoiceUtc = null;
                      }),
                    ),
                    ChoiceChip(
                      label: const AppText('Next morning'),
                      selected: _nextDay,
                      onSelected: (_) => setState(() {
                        _nextDay = true;
                        _foldChoiceUtc = null;
                      }),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('night-block-start'),
                      icon: const Icon(Icons.schedule),
                      label: AppText(_time.format(context)),
                      onPressed: () async {
                        final value = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (mounted && value != null) {
                          setState(() {
                            _time = value;
                            _foldChoiceUtc = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (_clockCandidates.length > 1)
                  DropdownButtonFormField<DateTime>(
                    key: ValueKey(
                      'night-fold-${_nextDay ? 'next' : 'same'}-${_time.hour}-${_time.minute}',
                    ),
                    initialValue: _clockCandidates.contains(_foldChoiceUtc)
                        ? _foldChoiceUtc
                        : _clockCandidates.first,
                    decoration: localizeDecoration(
                      context,
                      const InputDecoration(
                        labelText: 'Repeated hour: choose UTC offset',
                      ),
                    ),
                    items: [
                      for (final candidate in _clockCandidates)
                        DropdownMenuItem<DateTime>(
                          value: candidate,
                          child: AppText(widget.timeline.clockLabel(candidate)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _foldChoiceUtc = value),
                  ),
                TextFormField(
                  key: const ValueKey('night-block-duration'),
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Duration (minutes)'),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed <= 0 || parsed > 1440
                        ? 'Enter 1–1440 minutes.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const AppText(
                  'Overlapping blocks are flagged on the timeline. '
                  'Times are saved as UTC instants.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton.icon(
            key: const ValueKey('night-block-delete'),
            onPressed: () =>
                Navigator.pop(context, NightPlanDelete(widget.existing!.id)),
            icon: const Icon(Icons.delete_outline),
            label: const AppText('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('night-block-save'),
          onPressed: _save,
          child: const AppText('Save block'),
        ),
      ],
    );
  }
}
