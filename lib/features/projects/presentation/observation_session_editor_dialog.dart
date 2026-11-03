import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../equipment/application/equipment_controller.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../domain/observation_session.dart';

class ObservationSessionEditorDialog extends ConsumerStatefulWidget {
  const ObservationSessionEditorDialog({
    super.key,
    required this.projectId,
    this.session,
  });

  final String projectId;
  final ObservationSession? session;

  @override
  ConsumerState<ObservationSessionEditorDialog> createState() =>
      _ObservationSessionEditorDialogState();
}

class _ObservationSessionEditorDialogState
    extends ConsumerState<ObservationSessionEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _exposure = TextEditingController();
  final _frames = TextEditingController();
  final _accepted = TextEditingController();
  final _rejected = TextEditingController();
  final _iso = TextEditingController();
  final _gain = TextEditingController();
  final _aperture = TextEditingController();
  final _binning = TextEditingController();
  final _filter = TextEditingController();
  final _temperature = TextEditingController();
  final _notes = TextEditingController();

  late DateTime _wallClock;
  late TimeOfDay _clock;
  late String _zoneId;
  String? _locationId;
  String? _cameraId;
  String? _opticId;
  String? _mountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _zoneId = session?.timeZoneId ?? 'UTC';
    final local = session == null
        ? tz.TZDateTime.from(
            DateTime.now().toUtc(),
            ObservationSession.zone('UTC'),
          )
        : tz.TZDateTime.from(
            session.startedAtUtc,
            ObservationSession.zone(_zoneId),
          );
    _wallClock = DateTime(local.year, local.month, local.day);
    _clock = TimeOfDay(hour: local.hour, minute: local.minute);
    _locationId = session?.locationId;
    _cameraId = session?.cameraId;
    _opticId = session?.opticId;
    _mountId = session?.mountId;
    _exposure.text = session?.exposureSeconds.toString() ?? '60';
    _frames.text = session?.frameCount.toString() ?? '1';
    _accepted.text = session?.acceptedFrames.toString() ?? '1';
    _rejected.text = session?.rejectedFrames.toString() ?? '0';
    _iso.text = session?.iso?.toString() ?? '';
    _gain.text = session?.gain?.toString() ?? '';
    _aperture.text = session?.apertureFNumber?.toString() ?? '';
    _binning.text = session?.binning.toString() ?? '1';
    _filter.text = session?.filterName ?? '';
    _temperature.text = session?.sensorTemperatureC?.toString() ?? '';
    _notes.text = session?.notes ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _exposure,
      _frames,
      _accepted,
      _rejected,
      _iso,
      _gain,
      _aperture,
      _binning,
      _filter,
      _temperature,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _wallClock,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date != null && mounted) setState(() => _wallClock = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _clock);
    if (time != null && mounted) setState(() => _clock = time);
  }

  int? _optionalInt(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? null
      : int.tryParse(controller.text.trim());
  double? _optionalDouble(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? null
      : double.tryParse(controller.text.trim());

  String? _numericValidator(
    String? input, {
    required bool integer,
    bool optional = false,
  }) {
    final value = (input ?? '').trim();
    if (value.isEmpty && optional) return null;
    final number = integer ? int.tryParse(value) : double.tryParse(value);
    return number == null || !number.isFinite ? 'Enter a valid number.' : null;
  }

  void _save() {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    try {
      final selectedLocation = ref.read(observingLocationsProvider).value ?? [];
      final equipment = ref.read(equipmentProvider).value;
      final instant = ObservationSession.utcFromWallClock(
        // Keep the user-selected wall time intact, even when the device's
        // own time zone has a DST gap at that moment.
        DateTime.utc(
          _wallClock.year,
          _wallClock.month,
          _wallClock.day,
          _clock.hour,
          _clock.minute,
        ),
        _zoneId,
      );
      // Preserve the historical name when the linked location is unchanged.
      String? locName = _locationId == widget.session?.locationId
          ? widget.session?.locationName
          : null;
      if (locName == null && _locationId != null) {
        for (final location in selectedLocation) {
          if (location.id == _locationId) locName = location.name;
        }
      }
      String? equipmentName(
        String? id,
        String? previousId,
        String? previousName,
      ) {
        if (id == null) return null;
        if (id == previousId) {
          return previousName ??
              equipment?.itemById(id)?.name ??
              '(unavailable)';
        }
        return equipment?.itemById(id)?.name ?? '(unavailable)';
      }

      final session = ObservationSession(
        id: widget.session?.id ?? const Uuid().v4(),
        projectId: widget.projectId,
        startedAtUtc: instant,
        endedAtUtc: widget.session?.endedAtUtc,
        timeZoneId: _zoneId,
        utcOffsetMinutes: ObservationSession.offsetAt(instant, _zoneId),
        locationId: _locationId,
        locationName: locName ?? (_locationId == null ? null : '(unavailable)'),
        cameraId: _cameraId,
        cameraName: equipmentName(
          _cameraId,
          widget.session?.cameraId,
          widget.session?.cameraName,
        ),
        opticId: _opticId,
        opticName: equipmentName(
          _opticId,
          widget.session?.opticId,
          widget.session?.opticName,
        ),
        mountId: _mountId,
        mountName: equipmentName(
          _mountId,
          widget.session?.mountId,
          widget.session?.mountName,
        ),
        exposureSeconds: double.parse(_exposure.text.trim()),
        frameCount: int.parse(_frames.text.trim()),
        acceptedFrames: int.parse(_accepted.text.trim()),
        rejectedFrames: int.parse(_rejected.text.trim()),
        iso: _optionalInt(_iso),
        gain: _optionalDouble(_gain),
        apertureFNumber: _optionalDouble(_aperture),
        binning: int.parse(_binning.text.trim()),
        filterName: _filter.text.trim(),
        sensorTemperatureC: _optionalDouble(_temperature),
        notes: _notes.text.trim(),
      );
      Navigator.pop(context, session);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Widget _number(
    String label,
    TextEditingController controller,
    String key, {
    bool integer = false,
    bool optional = false,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: localizeDecoration(context, InputDecoration(labelText: label)),
    validator: (text) =>
        _numericValidator(text, integer: integer, optional: optional),
  );

  Widget _equipmentField({
    required String label,
    required String keyName,
    required String? selectedId,
    required List<EquipmentItem> options,
    required String? oldName,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey(keyName),
    isExpanded: true,
    initialValue: selectedId ?? '__none__',
    decoration: localizeDecoration(context, InputDecoration(labelText: label)),
    items: [
      const DropdownMenuItem(value: '__none__', child: AppText('Not selected')),
      if (selectedId != null && !options.any((item) => item.id == selectedId))
        DropdownMenuItem(
          value: selectedId,
          child: AppText(
            '${oldName ?? selectedId} (unavailable)',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      for (final item in options)
        DropdownMenuItem(
          value: item.id,
          child: AppText(item.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) => onChanged(value == '__none__' ? null : value),
  );

  @override
  Widget build(BuildContext context) {
    final locations =
        ref.watch(observingLocationsProvider).value ?? <ObservingLocation>[];
    final equipment =
        ref.watch(equipmentProvider).value ??
        EquipmentInventory(items: [], profiles: []);
    return AlertDialog(
      title: AppText(
        widget.session == null
            ? 'New observation session'
            : 'Edit observation session',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('session-date'),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: AppText(
                        '${_wallClock.year}-${_wallClock.month.toString().padLeft(2, '0')}-${_wallClock.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('session-time'),
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: AppText(_clock.format(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const ValueKey('session-location'),
                  isExpanded: true,
                  initialValue: _locationId ?? '__none__',
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Observing location'),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '__none__',
                      child: AppText('Not selected (UTC)'),
                    ),
                    if (_locationId != null &&
                        !locations.any((item) => item.id == _locationId))
                      DropdownMenuItem(
                        value: _locationId,
                        child: AppText(
                          '${widget.session?.locationName ?? _locationId} (unavailable)',
                        ),
                      ),
                    for (final location in locations)
                      DropdownMenuItem(
                        value: location.id,
                        child: AppText(
                          location.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _locationId = value == '__none__' ? null : value;
                    if (_locationId == null) {
                      _zoneId = 'UTC';
                    } else {
                      for (final location in locations) {
                        if (location.id == _locationId) {
                          _zoneId = location.timeZone;
                        }
                      }
                    }
                  }),
                ),
                AppText(
                  'Time zone: $_zoneId (saved with UTC offset)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _equipmentField(
                  label: 'Camera',
                  keyName: 'session-camera',
                  selectedId: _cameraId,
                  options: equipment.cameras,
                  oldName: widget.session?.cameraName,
                  onChanged: (value) => setState(() => _cameraId = value),
                ),
                _equipmentField(
                  label: 'Optics',
                  keyName: 'session-optic',
                  selectedId: _opticId,
                  options: equipment.optics,
                  oldName: widget.session?.opticName,
                  onChanged: (value) => setState(() => _opticId = value),
                ),
                _equipmentField(
                  label: 'Mount',
                  keyName: 'session-mount',
                  selectedId: _mountId,
                  options: equipment.mounts,
                  oldName: widget.session?.mountName,
                  onChanged: (value) => setState(() => _mountId = value),
                ),
                const SizedBox(height: 12),
                _number(
                  'Exposure per frame (seconds) *',
                  _exposure,
                  'session-exposure',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _number(
                        'Total frames *',
                        _frames,
                        'session-frame-count',
                        integer: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _number(
                        'Accepted *',
                        _accepted,
                        'session-accepted',
                        integer: true,
                      ),
                    ),
                  ],
                ),
                _number(
                  'Rejected frames *',
                  _rejected,
                  'session-rejected',
                  integer: true,
                ),
                const AppText('Use either ISO or gain; leave the other empty.'),
                Row(
                  children: [
                    Expanded(
                      child: _number(
                        'ISO',
                        _iso,
                        'session-iso',
                        integer: true,
                        optional: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _number(
                        'Gain',
                        _gain,
                        'session-gain',
                        optional: true,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _number(
                        'Aperture f-number',
                        _aperture,
                        'session-aperture',
                        optional: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _number(
                        'Binning',
                        _binning,
                        'session-binning',
                        integer: true,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _filter,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Filter'),
                  ),
                ),
                _number(
                  'Sensor temperature (°C)',
                  _temperature,
                  'session-temp',
                  optional: true,
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Session notes'),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('session-save'),
          onPressed: _save,
          child: const AppText('Save session'),
        ),
      ],
    );
  }
}
