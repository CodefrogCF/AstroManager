import 'package:flutter/material.dart';

import '../../atlas/domain/sky_atlas_models.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../projects/domain/planned_imaging_project.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../domain/mosaic_plan.dart';

/// Editable composition; updates the calculated footprint on every change.
class MosaicPlannerDialog extends StatefulWidget {
  const MosaicPlannerDialog({
    super.key,
    required this.project,
    required this.targets,
    required this.equipment,
    this.existing,
  });

  final PlannedImagingProject project;
  final List<CelestialObject> targets;
  final EquipmentInventory equipment;
  final MosaicPlan? existing;

  @override
  State<MosaicPlannerDialog> createState() => _MosaicPlannerDialogState();
}

class _MosaicPlannerDialogState extends State<MosaicPlannerDialog> {
  late String _targetId;
  late String _profileId;
  late int _rows;
  late int _columns;
  late double _overlap;
  late double _rotation;
  late final TextEditingController _ra;
  late final TextEditingController _dec;
  String? _validation;

  @override
  void initState() {
    super.initState();
    final original = widget.existing;
    _targetId = original?.targetId ?? widget.targets.first.id;
    _profileId =
        original?.profileId ??
        widget.project.opticalProfileId ??
        widget.equipment.profiles.first.id;
    _rows = original?.rows ?? 2;
    _columns = original?.columns ?? 2;
    _overlap = original?.overlapPercent ?? 15;
    _rotation = original?.rotationDegrees ?? 0;
    final target = widget.targets.firstWhere(
      (t) => t.id == _targetId,
      orElse: () => widget.targets.first,
    );
    _ra = TextEditingController(
      text: (original?.center.raDegrees ?? target.raDegrees).toStringAsFixed(5),
    );
    _dec = TextEditingController(
      text: (original?.center.decDegrees ?? target.decDegrees).toStringAsFixed(
        5,
      ),
    );
  }

  @override
  void dispose() {
    _ra.dispose();
    _dec.dispose();
    super.dispose();
  }

  MosaicPlan _currentPlan() {
    final ra = double.tryParse(_ra.text.trim());
    final dec = double.tryParse(_dec.text.trim());
    if (ra == null || dec == null) {
      throw const FormatException('Enter numeric RA and Dec in degrees.');
    }
    final plan = MosaicPlan(
      projectId: widget.project.id,
      targetId: _targetId,
      profileId: _profileId,
      center: SkyAtlasPosition(raDegrees: ra, decDegrees: dec),
      rows: _rows,
      columns: _columns,
      overlapPercent: _overlap,
      rotationDegrees: _rotation,
    );
    plan.validate();
    return plan;
  }

  MosaicFootprint _footprint() {
    final plan = _currentPlan();
    final profile = widget.equipment.profiles.firstWhere(
      (p) => p.id == plan.profileId,
    );
    return MosaicGeometry.calculate(
      plan: plan,
      optics: widget.equipment.metricsFor(profile),
    );
  }

  void _selectTarget(String? targetId) {
    if (targetId == null) {
      return;
    }
    final target = widget.targets.firstWhere((t) => t.id == targetId);
    setState(() {
      _targetId = targetId;
      _ra.text = target.raDegrees.toStringAsFixed(5);
      _dec.text = target.decDegrees.toStringAsFixed(5);
      _validation = null;
    });
  }

  void _save() {
    try {
      final plan = _currentPlan();
      _footprint(); // Also validate the combined angular extent.
      Navigator.of(context).pop(plan);
    } catch (error) {
      setState(() => _validation = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    MosaicFootprint? preview;
    String? error;
    try {
      preview = _footprint();
    } catch (e) {
      error = e.toString();
    }
    return AlertDialog(
      title: const Text('Mosaic planner'),
      content: SizedBox(
        width: 590,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('mosaic-target'),
                initialValue: _targetId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project target'),
                items: [
                  for (final t in widget.targets)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        t.displayTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _selectTarget,
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('mosaic-profile-$_profileId'),
                initialValue: _profileId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Imaging setup'),
                items: [
                  for (final p in widget.equipment.profiles)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _profileId = value);
                  }
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('mosaic-ra'),
                      controller: _ra,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Center RA (°)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('mosaic-dec'),
                      controller: _dec,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Center Dec (°)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('mosaic-rows'),
                      initialValue: _rows,
                      decoration: const InputDecoration(labelText: 'Rows'),
                      items: [
                        for (var i = 1; i <= 10; i++)
                          DropdownMenuItem(value: i, child: Text('$i')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _rows = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('mosaic-columns'),
                      initialValue: _columns,
                      decoration: const InputDecoration(labelText: 'Columns'),
                      items: [
                        for (var i = 1; i <= 10; i++)
                          DropdownMenuItem(value: i, child: Text('$i')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _columns = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Panel overlap ${_overlap.round()}%'),
              Slider(
                key: const ValueKey('mosaic-overlap'),
                value: _overlap,
                min: 0,
                max: 80,
                divisions: 80,
                onChanged: (v) => setState(() => _overlap = v),
              ),
              Text('Rotation ${_rotation.round()}° clockwise'),
              Slider(
                key: const ValueKey('mosaic-rotation'),
                value: _rotation,
                min: 0,
                max: 359,
                divisions: 359,
                onChanged: (v) => setState(() => _rotation = v),
              ),
              if (preview != null) ...[
                Text(
                  '${preview.panels.length} panels · '
                  '${preview.widthDegrees.toStringAsFixed(2)}° × '
                  '${preview.heightDegrees.toStringAsFixed(2)}° total',
                  key: const ValueKey('mosaic-total-fov'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 185,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _MosaicPreviewPainter(
                      rows: _rows,
                      columns: _columns,
                      overlap: _overlap,
                      rotation: _rotation,
                    ),
                  ),
                ),
                ExpansionTile(
                  title: const Text('Panel pointing coordinates'),
                  children: [
                    for (final p in preview.panels)
                      ListTile(
                        dense: true,
                        title: Text(p.label),
                        subtitle: Text(
                          'RA ${p.center.raDegrees.toStringAsFixed(5)}° · '
                          'Dec ${p.center.decDegrees.toStringAsFixed(5)}°',
                        ),
                      ),
                  ],
                ),
              ] else
                Text(
                  error ?? 'Invalid mosaic configuration',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_validation != null)
                Text(
                  _validation!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                'ICRS/J2000 planning geometry; account separately for '
                'field rotation, distortion, framing margins and mount limits.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('mosaic-save'),
          onPressed: preview == null ? null : _save,
          child: const Text('Save mosaic'),
        ),
      ],
    );
  }
}

class _MosaicPreviewPainter extends CustomPainter {
  const _MosaicPreviewPainter({
    required this.rows,
    required this.columns,
    required this.overlap,
    required this.rotation,
  });
  final int rows;
  final int columns;
  final double overlap;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final panelW = 1.0;
    final panelH = 1.0;
    final step = 1 - overlap / 100;
    final totalW = 1 + (columns - 1) * step;
    final totalH = 1 + (rows - 1) * step;
    final scale =
        0.80 *
        (size.width / totalW).clamp(0.0, size.height / totalH).toDouble();
    final paint = Paint()
      ..color = const Color(0xff66bfe7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * 3.141592653589793 / 180);
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final dx = (column - (columns - 1) / 2) * step * scale;
        final dy = (row - (rows - 1) / 2) * step * scale;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(dx, dy),
            width: panelW * scale,
            height: panelH * scale,
          ),
          paint,
        );
        final text = TextPainter(
          text: TextSpan(
            text: 'R${row + 1}C${column + 1}',
            style: const TextStyle(color: Color(0xff66bfe7), fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(dx - text.width / 2, dy - text.height / 2));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MosaicPreviewPainter oldDelegate) =>
      rows != oldDelegate.rows ||
      columns != oldDelegate.columns ||
      overlap != oldDelegate.overlap ||
      rotation != oldDelegate.rotation;
}
