import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/equipment_models.dart';

class EquipmentEditorDialog extends StatefulWidget {
  const EquipmentEditorDialog({required this.kind, this.item, super.key});

  final EquipmentKind kind;
  final EquipmentItem? item;

  @override
  State<EquipmentEditorDialog> createState() => _EquipmentEditorDialogState();
}

class _EquipmentEditorDialogState extends State<EquipmentEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _sensorWidth;
  late final TextEditingController _sensorHeight;
  late final TextEditingController _resolutionX;
  late final TextEditingController _resolutionY;
  late final TextEditingController _focalLength;
  late final TextEditingController _aperture;
  late final TextEditingController _payload;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _name = TextEditingController(text: item?.name ?? '');
    _sensorWidth = TextEditingController(
      text: item?.sensorWidthMm?.toString() ?? '',
    );
    _sensorHeight = TextEditingController(
      text: item?.sensorHeightMm?.toString() ?? '',
    );
    _resolutionX = TextEditingController(
      text: item?.resolutionX?.toString() ?? '',
    );
    _resolutionY = TextEditingController(
      text: item?.resolutionY?.toString() ?? '',
    );
    _focalLength = TextEditingController(
      text: item?.focalLengthMm?.toString() ?? '',
    );
    _aperture = TextEditingController(text: item?.apertureMm?.toString() ?? '');
    _payload = TextEditingController(
      text: item?.payloadCapacityKg?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sensorWidth,
      _sensorHeight,
      _resolutionX,
      _resolutionY,
      _focalLength,
      _aperture,
      _payload,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _positiveNumber(String? input, {required double max}) {
    final number = _number(input ?? '');

    if (number == null || !number.isFinite || number <= 0 || number > max) {
      return 'Enter a value greater than 0 and at most $max.';
    }

    return null;
  }

  String? _positiveInteger(String? input) {
    final number = int.tryParse(input?.trim() ?? '');

    if (number == null || number < 1 || number > 100000) {
      return 'Enter a whole number from 1 to 100000.';
    }

    return null;
  }

  Widget _numberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required double max,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey(keyName),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        decoration: InputDecoration(labelText: label),
        validator: integer
            ? _positiveInteger
            : (value) => _positiveNumber(value, max: max),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final isCamera = widget.kind == EquipmentKind.camera;
    final isOptic = widget.kind.isOptic;
    final isMount = widget.kind == EquipmentKind.mount;

    final item = EquipmentItem(
      id: widget.item?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      kind: widget.kind,
      sensorWidthMm: isCamera ? _number(_sensorWidth.text) : null,
      sensorHeightMm: isCamera ? _number(_sensorHeight.text) : null,
      resolutionX: isCamera ? int.tryParse(_resolutionX.text) : null,
      resolutionY: isCamera ? int.tryParse(_resolutionY.text) : null,
      focalLengthMm: isOptic ? _number(_focalLength.text) : null,
      apertureMm: isOptic ? _number(_aperture.text) : null,
      payloadCapacityKg: isMount ? _number(_payload.text) : null,
    );

    item.validate();

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final isCamera = widget.kind == EquipmentKind.camera;
    final isOptic = widget.kind.isOptic;
    final isMount = widget.kind == EquipmentKind.mount;

    return AlertDialog(
      title: Text(
        widget.item == null
            ? 'Add ${widget.kind.label}'
            : 'Edit ${widget.kind.label}',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('equipment-name'),
                  controller: _name,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Equipment name',
                    hintText: 'e.g. Sony a7 II',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an equipment name.';
                    }
                    return null;
                  },
                ),

                if (isCamera) ...[
                  _numberField(
                    keyName: 'sensor-width',
                    label: 'Sensor width (mm)',
                    controller: _sensorWidth,
                    max: 100,
                  ),
                  _numberField(
                    keyName: 'sensor-height',
                    label: 'Sensor height (mm)',
                    controller: _sensorHeight,
                    max: 100,
                  ),
                  _numberField(
                    keyName: 'resolution-x',
                    label: 'Horizontal resolution (pixels)',
                    controller: _resolutionX,
                    max: 100000,
                    integer: true,
                  ),
                  _numberField(
                    keyName: 'resolution-y',
                    label: 'Vertical resolution (pixels)',
                    controller: _resolutionY,
                    max: 100000,
                    integer: true,
                  ),
                ],

                if (isOptic) ...[
                  _numberField(
                    keyName: 'focal-length',
                    label: 'Focal length (mm)',
                    controller: _focalLength,
                    max: 20000,
                  ),
                  _numberField(
                    keyName: 'aperture',
                    label: 'Clear aperture (mm)',
                    controller: _aperture,
                    max: 2500,
                  ),
                ],

                if (isMount)
                  _numberField(
                    keyName: 'payload-capacity',
                    label: 'Payload capacity (kg)',
                    controller: _payload,
                    max: 1000,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class OpticalProfileEditorDialog extends StatefulWidget {
  const OpticalProfileEditorDialog({
    required this.inventory,
    this.profile,
    super.key,
  });

  final EquipmentInventory inventory;
  final OpticalProfile? profile;

  @override
  State<OpticalProfileEditorDialog> createState() =>
      _OpticalProfileEditorDialogState();
}

class _OpticalProfileEditorDialogState
    extends State<OpticalProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _multiplier;

  String? _cameraId;
  String? _opticId;
  String? _mountId;

  @override
  void initState() {
    super.initState();

    final profile = widget.profile;

    _name = TextEditingController(text: profile?.name ?? '');
    _multiplier = TextEditingController(
      text: profile?.focalMultiplier.toString() ?? '1.0',
    );

    _cameraId = profile?.cameraId;
    _opticId = profile?.opticId;
    _mountId = profile?.mountId;
  }

  @override
  void dispose() {
    _name.dispose();
    _multiplier.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final multiplier = double.tryParse(
      _multiplier.text.trim().replaceAll(',', '.'),
    );

    if (_cameraId == null || _opticId == null || multiplier == null) {
      return;
    }

    final profile = OpticalProfile(
      id: widget.profile?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      cameraId: _cameraId!,
      opticId: _opticId!,
      mountId: _mountId,
      focalMultiplier: multiplier,
    );

    profile.validate();

    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = widget.inventory;

    return AlertDialog(
      title: Text(
        widget.profile == null
            ? 'Create Optical Profile'
            : 'Edit Optical Profile',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('profile-name'),
                  controller: _name,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Profile name',
                    hintText: 'e.g. Wide-field setup',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a profile name.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  key: const ValueKey('profile-camera'),
                  initialValue: _cameraId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Camera'),
                  items: [
                    for (final camera in inventory.cameras)
                      DropdownMenuItem(
                        value: camera.id,
                        child: Text(camera.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _cameraId = value);
                  },
                  validator: (value) =>
                      value == null ? 'Select a camera.' : null,
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  key: const ValueKey('profile-optic'),
                  initialValue: _opticId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lens or telescope',
                  ),
                  items: [
                    for (final optic in inventory.optics)
                      DropdownMenuItem(
                        value: optic.id,
                        child: Text('${optic.name} (${optic.kind.label})'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _opticId = value);
                  },
                  validator: (value) =>
                      value == null ? 'Select an optic.' : null,
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  key: const ValueKey('profile-mount'),
                  initialValue: _mountId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mount (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No mount selected'),
                    ),
                    for (final mount in inventory.mounts)
                      DropdownMenuItem(
                        value: mount.id,
                        child: Text(mount.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _mountId = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  key: const ValueKey('profile-multiplier'),
                  controller: _multiplier,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Optical multiplier',
                    helperText: '1.0 = native, 0.8 = reducer, 2.0 = Barlow',
                  ),
                  validator: (value) {
                    final factor = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );

                    if (factor == null ||
                        !factor.isFinite ||
                        factor < 0.1 ||
                        factor > 10) {
                      return 'Enter a factor from 0.1 to 10.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
