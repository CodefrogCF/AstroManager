import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../atlas/presentation/sky_atlas_screen.dart';
import '../../equipment/application/equipment_controller.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../projects/domain/planned_imaging_project.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../data/mosaic_repository.dart';
import '../domain/mosaic_plan.dart';
import 'mosaic_planner_dialog.dart';

class ProjectMosaicSection extends ConsumerStatefulWidget {
  const ProjectMosaicSection({super.key, required this.project});
  final PlannedImagingProject project;

  @override
  ConsumerState<ProjectMosaicSection> createState() =>
      _ProjectMosaicSectionState();
}

class _ProjectMosaicSectionState extends ConsumerState<ProjectMosaicSection> {
  MosaicPlan? _plan;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectMosaicSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.project.id != oldWidget.project.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.project.id;
    try {
      final loaded = await ref.read(mosaicPlansRepositoryProvider).load(id);
      if (mounted && widget.project.id == id) {
        setState(() {
          _plan = loaded;
          _busy = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && widget.project.id == id) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<CelestialObject?> _target(String id) async {
    await ref.read(celestialCatalogProvider.future);
    return ref.read(celestialCatalogRepositoryProvider).findById(id);
  }

  Future<List<CelestialObject>> _availableTargets() async {
    final targets = <CelestialObject>[];
    for (final id in widget.project.targetIds) {
      final found = await _target(id);
      if (found != null) {
        targets.add(found);
      }
    }
    return targets;
  }

  Future<void> _edit(EquipmentInventory inventory) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final targets = await _availableTargets();
      if (!mounted) {
        return;
      }
      if (targets.isEmpty || inventory.profiles.isEmpty) {
        _message('Assign a catalog target and an imaging setup first.');
        return;
      }
      final compatiblePlan =
          _plan != null &&
              targets.any((t) => t.id == _plan!.targetId) &&
              inventory.profiles.any((p) => p.id == _plan!.profileId)
          ? _plan
          : null;
      final changed = await showDialog<MosaicPlan>(
        context: context,
        builder: (_) => MosaicPlannerDialog(
          project: widget.project,
          targets: targets,
          equipment: inventory,
          existing: compatiblePlan,
        ),
      );
      if (changed == null) {
        return;
      }
      await ref.read(mosaicPlansRepositoryProvider).save(changed);
      if (mounted) {
        setState(() {
          _plan = changed;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        _message('Mosaic operation failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete mosaic plan?'),
        content: const Text(
          'This removes only the mosaic composition, not the project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('mosaic-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(mosaicPlansRepositoryProvider).delete(widget.project.id);
      if (mounted) {
        setState(() {
          _plan = null;
          _error = null;
        });
      }
    } catch (e) {
      _message('Mosaic deletion failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  MosaicFootprint _geometry(EquipmentInventory inventory) {
    final plan = _plan!;
    final profile = inventory.profiles.firstWhere(
      (p) => p.id == plan.profileId,
    );
    return MosaicGeometry.calculate(
      plan: plan,
      optics: inventory.metricsFor(profile),
    );
  }

  Future<void> _export(EquipmentInventory inventory) async {
    try {
      final footprint = _geometry(inventory);
      final bytes = Uint8List.fromList(utf8.encode(footprint.exportJson()));
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Export mosaic panel coordinates',
        fileName: 'AstroManager-mosaic-${widget.project.id}.json',
        mimeType: 'application/json',
        bytes: bytes,
      );
      if (destination != null) {
        _message('Mosaic coordinates exported.');
      }
    } catch (e) {
      _message('Mosaic export failed: $e');
    }
  }

  Future<void> _atlas(EquipmentInventory inventory) async {
    try {
      _geometry(
        inventory,
      ); // Block an unrenderable plan instead of silently hiding it.
      final target = await _target(_plan!.targetId);
      if (!mounted) {
        return;
      }
      context.push(
        AppRoutes.atlas,
        extra: SkyAtlasMosaicRequest(target: target, plan: _plan!),
      );
    } catch (e) {
      _message('Unable to open mosaic atlas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipment = ref.watch(equipmentProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mosaic composition',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text('Mosaic data unavailable: $_error'),
        equipment.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text('Imaging setups unavailable: $error'),
          data: (inventory) {
            MosaicFootprint? footprint;
            String? geometryError;
            if (_plan != null) {
              try {
                footprint = _geometry(inventory);
              } catch (e) {
                geometryError = e.toString();
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (footprint != null)
                  Text(
                    '${_plan!.rows} × ${_plan!.columns} panels · '
                    '${_plan!.overlapPercent.toStringAsFixed(0)}% overlap · '
                    '${footprint.widthDegrees.toStringAsFixed(2)}° × '
                    '${footprint.heightDegrees.toStringAsFixed(2)}°',
                  ),
                if (_plan == null)
                  const Text('No mosaic planned for this project.'),
                if (geometryError != null)
                  Text(
                    'Mosaic requires an available, valid optical setup: $geometryError',
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('mosaic-edit'),
                      onPressed: _busy ? null : () => _edit(inventory),
                      icon: const Icon(Icons.grid_on),
                      label: Text(
                        _plan == null ? 'Create mosaic' : 'Edit mosaic',
                      ),
                    ),
                    if (footprint != null) ...[
                      OutlinedButton.icon(
                        key: const ValueKey('mosaic-atlas'),
                        onPressed: _busy ? null : () => _atlas(inventory),
                        icon: const Icon(Icons.public),
                        label: const Text('View in atlas'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('mosaic-export'),
                        onPressed: _busy ? null : () => _export(inventory),
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export coordinates'),
                      ),
                    ],
                    if (_plan != null)
                      OutlinedButton.icon(
                        key: const ValueKey('mosaic-delete'),
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove mosaic'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
