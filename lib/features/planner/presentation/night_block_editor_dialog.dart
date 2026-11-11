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
  const NightPlanDelete(this.block);
  final NightObservationBlock block;
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
    this.initialProjectId,
    this.initialTargetId,
  });
  final ObservingLocation location;
  final NightTimeline timeline;
  final List<PlannedImagingProject> projects;
  final Map<String, CelestialObject> targets;
  final NightObservationBlock? existing;
  final DateTime? suggestedUtc;
  final String? initialProjectId;
  final String? initialTargetId;

  @override
  State<NightBlockEditorDialog> createState() => _NightBlockEditorDialogState();
}

class _NightBlockEditorDialogState extends State<NightBlockEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _minutes = TextEditingController();
  final _notes = TextEditingController();
  late final Map<String, PlannedImagingProject> _projects;
  late final List<String> _projectIds;
  late final int _initialMinutes;
  late String _projectId;
  late String _targetId;
  late TimeOfDay _time;
  String? _error;
  DateTime? _foldChoiceUtc;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final start =
        existing?.startUtc ?? widget.suggestedUtc ?? _suggestedStart();
    final local = tz.TZDateTime.from(
      start,
      SolarEvents.timeZone(widget.location.timeZone),
    );
    _foldChoiceUtc = _minuteUtc(start);
    _time = TimeOfDay(hour: local.hour, minute: local.minute);
    _projects = {for (final project in widget.projects) project.id: project};
    _projectIds = [
      ..._projects.keys,
      if (existing != null && !_projects.containsKey(existing.projectId))
        existing.projectId,
    ];
    final initialProject = widget.initialProjectId;
    _projectId =
        existing?.projectId ??
        (_projects.containsKey(initialProject)
            ? initialProject!
            : _projectIds.first);
    final initialTarget = widget.initialTargetId;
    final targets = _targetsFor(_projectId);
    _targetId =
        existing?.targetId ??
        (targets.contains(initialTarget) ? initialTarget! : targets.first);
    const microsPerMinute = Duration.microsecondsPerMinute;
    _initialMinutes = existing == null
        ? 60
        : (existing.duration.inMicroseconds + microsPerMinute - 1) ~/
              microsPerMinute;
    _minutes.text = _initialMinutes.toString();
    _notes.text = existing?.notes ?? '';
  }

  DateTime _suggestedStart() {
    final timeline = widget.timeline;
    final darkness = timeline.day.astronomicalDarkness.firstOrNull;
    if (darkness != null) {
      final minute = _minuteUtc(darkness.startUtc);
      final start = minute.isBefore(darkness.startUtc)
          ? minute.add(const Duration(minutes: 1))
          : minute;
      if (timeline.contains(start, start.add(const Duration(hours: 1)))) {
        return start;
      }
    }
    return timeline.startUtc.add(const Duration(hours: 8));
  }

  DateTime _minuteUtc(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
  );

  List<String> _targetsFor(String projectId) {
    final current = _projects[projectId]?.targetIds ?? const <String>[];
    final existing = widget.existing;
    return existing != null &&
            existing.projectId == projectId &&
            !current.contains(existing.targetId)
        ? [existing.targetId, ...current]
        : current;
  }

  String _projectName(String id) =>
      _projects[id]?.title ?? widget.existing!.projectName;

  String _targetName(String id) =>
      widget.targets[id]?.displayTitle ??
      (id == widget.existing?.targetId ? widget.existing!.targetName : id);

  @override
  void dispose() {
    _minutes.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _startDate {
    final date = widget.timeline.day.localDate;
    // Each wall-clock time belongs to one date in a noon-to-noon night.
    return DateTime.utc(
      date.year,
      date.month,
      date.day + (_time.hour < 12 ? 1 : 0),
    );
  }

  List<DateTime> get _clockCandidates {
    final day = _startDate;
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
    final minute = candidates.contains(_foldChoiceUtc)
        ? _foldChoiceUtc!
        : candidates.first;
    final existing = widget.existing;
    final start = existing != null && _minuteUtc(existing.startUtc) == minute
        ? existing.startUtc
        : minute;
    final minutes = int.parse(_minutes.text.trim());
    final duration = existing != null && minutes == _initialMinutes
        ? existing.duration
        : Duration(minutes: minutes);
    final end = start.add(duration);
    if (!widget.timeline.contains(start, end)) {
      setState(
        () => _error = 'Block must fit inside the selected noon-to-noon night.',
      );
      return;
    }
    final block = NightObservationBlock(
      id: widget.existing?.id ?? const Uuid().v4(),
      locationId: widget.location.id,
      nightDate: widget.timeline.day.localDate.toIso8601String().substring(
        0,
        10,
      ),
      timeZoneId: widget.location.timeZone,
      projectId: _projectId,
      targetId: _targetId,
      projectName: _projectName(_projectId),
      targetName: _targetName(_targetId),
      startUtc: start,
      endUtc: end,
      notes: _notes.text.trim(),
    );
    Navigator.pop(context, NightPlanSave(block));
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _clockCandidates;
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
                    for (final id in _projectIds)
                      DropdownMenuItem(
                        value: id,
                        child: AppText(
                          _projectName(id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _projectId = value;
                      _targetId = _targetsFor(value).first;
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('night-block-target-$_projectId'),
                  initialValue: _targetId,
                  isExpanded: true,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Celestial target'),
                  ),
                  items: [
                    for (final id in _targetsFor(_projectId))
                      DropdownMenuItem(
                        value: id,
                        child: AppText(
                          _targetName(id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _targetId = value);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  '${appTranslate(context, 'Start time')} · ${widget.location.timeZone}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                OutlinedButton.icon(
                  key: const ValueKey('night-block-start'),
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(_startDate)} · ${_time.format(context)}',
                  ),
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (mounted && value != null && value != _time) {
                      setState(() {
                        _time = value;
                        _foldChoiceUtc = null;
                      });
                    }
                  },
                ),
                if (candidates.length > 1)
                  DropdownButtonFormField<DateTime>(
                    key: ValueKey(
                      'night-fold-$_startDate-${_time.hour}-${_time.minute}',
                    ),
                    initialValue: candidates.contains(_foldChoiceUtc)
                        ? _foldChoiceUtc
                        : candidates.first,
                    decoration: localizeDecoration(
                      context,
                      const InputDecoration(
                        labelText: 'Repeated hour: choose UTC offset',
                      ),
                    ),
                    items: [
                      for (final candidate in candidates)
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
                Navigator.pop(context, NightPlanDelete(widget.existing!)),
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
