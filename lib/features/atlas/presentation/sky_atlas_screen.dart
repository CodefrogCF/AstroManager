import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../equipment/application/equipment_controller.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../application/sky_atlas_controller.dart';
import '../data/framing_repository.dart';
import '../domain/camera_framing.dart';
import '../domain/sky_dome.dart';
import '../domain/sky_atlas_models.dart';
import 'sky_atlas_host.dart';

class SkyAtlasScreen extends StatefulWidget {
  const SkyAtlasScreen({
    super.key,
    this.target,
    this.hostBuilder,
    this.equipmentInventory,
    this.framingRepository,
    this.observingLocations,
    this.initialObservationUtc,
  });

  final CelestialObject? target;

  /// Inject an atlas transport and equipment set for offline widget tests.
  final Widget Function(SkyAtlasController controller)? hostBuilder;
  final EquipmentInventory? equipmentInventory;
  final CameraFramingRepository? framingRepository;

  /// Optional inputs make dome mode independently widget-testable.
  final List<ObservingLocation>? observingLocations;
  final DateTime? initialObservationUtc;

  @override
  State<SkyAtlasScreen> createState() => _SkyAtlasScreenState();
}

class _SkyAtlasScreenState extends State<SkyAtlasScreen> {
  late final SkyAtlasController _controller;
  late final CameraFramingRepository _repository;
  EquipmentInventory? _inventory;
  SkyAtlasPosition? _framingCenter;
  String? _profileId;
  double _rotation = 0;
  String? _feedback;
  int _hostGeneration = 0;
  int _restoreGeneration = 0;
  late DateTime _observationUtc;
  List<ObservingLocation> _locations = const [];
  List<ObservingLocation>? _lastProviderLocations;
  String? _locationId;
  double _minimumAltitude = 25;
  SkyAtlasPosition? _detailPosition;
  double _detailFov = 3;

  String get _targetKey => widget.target?.id ?? '__untargeted__';

  SkyAtlasPosition get _targetPosition {
    final target = widget.target;
    return target == null
        ? const SkyAtlasPosition(raDegrees: 10.6847, decDegrees: 41.2688)
        : SkyAtlasPosition(
            raDegrees: target.raDegrees,
            decDegrees: target.decDegrees,
          );
  }

  @override
  void initState() {
    super.initState();
    final position = _targetPosition;
    _framingCenter = position;
    _controller = SkyAtlasController(
      initialPosition: position,
      initialFieldOfViewDegrees: 3,
      initialMarkers: _markersFor(widget.target),
      initialOverlays: _overlaysFor(widget.target),
    )..addListener(_refresh);
    _repository =
        widget.framingRepository ??
        (widget.hostBuilder == null
            ? SharedPreferencesCameraFramingRepository()
            : MemoryCameraFramingRepository());
    // Injected inventory must be available before the asynchronous framing
    // restore chooses the initial optical profile. Previously this remained
    // null until an equipment-provider update, so test / embedded hosts never
    // received a camera footprint or its framing controls.
    _inventory = widget.equipmentInventory;
    _observationUtc = (widget.initialObservationUtc ?? DateTime.now()).toUtc();
    if (widget.observingLocations != null) {
      _updateLocations(widget.observingLocations!);
    }
    _readSaved();
  }

  List<SkyAtlasMarker> _markersFor(CelestialObject? target) {
    if (target == null) return [];
    return [
      SkyAtlasMarker(
        id: target.id,
        position: SkyAtlasPosition(
          raDegrees: target.raDegrees,
          decDegrees: target.decDegrees,
        ),
        label: target.displayTitle,
      ),
    ];
  }

  List<SkyAtlasCircleOverlay> _overlaysFor(CelestialObject? target) {
    final arcmin = target?.majorAxisArcmin;
    if (target == null || arcmin == null || arcmin <= 0 || arcmin > 10800) {
      return [];
    }
    return [
      SkyAtlasCircleOverlay(
        position: SkyAtlasPosition(
          raDegrees: target.raDegrees,
          decDegrees: target.decDegrees,
        ),
        radiusDegrees: arcmin / 120,
      ),
    ];
  }

  Future<void> _readSaved() async {
    final generation = ++_restoreGeneration;
    try {
      final stored = await _repository.load(_targetKey);
      if (!mounted || generation != _restoreGeneration) return;
      final inventory = _inventory;
      setState(() {
        _framingCenter = stored?.center ?? _targetPosition;
        _profileId =
            stored?.profileId ??
            (inventory != null && inventory.profiles.isNotEmpty
                ? inventory.profiles.first.id
                : null);
        _rotation = stored?.rotationDegrees ?? 0;
        _feedback = stored == null ? null : 'Saved framing restored';
      });
      _updateCameraFrame();
      if (stored != null) {
        _controller.goto(stored.center);
      }
    } catch (error) {
      if (!mounted || generation != _restoreGeneration) return;
      setState(() => _feedback = 'Unable to restore framing: $error');
    }
  }

  void _updateLocations(List<ObservingLocation> locations) {
    _locations = List.unmodifiable(locations);
    if (!_locations.any((location) => location.id == _locationId)) {
      final defaults = _locations.where((location) => location.isDefault);
      _locationId = defaults.isNotEmpty
          ? defaults.first.id
          : (_locations.isEmpty ? null : _locations.first.id);
    }
    if (_controller.projectionMode == SkyAtlasProjectionMode.skyDome) {
      _refreshDome();
    }
  }

  ObservingLocation? get _selectedLocation {
    for (final location in _locations) {
      if (location.id == _locationId) return location;
    }
    return null;
  }

  void _switchMode(SkyAtlasProjectionMode mode) {
    if (mode == _controller.projectionMode) return;
    if (mode == SkyAtlasProjectionMode.skyDome) {
      _detailPosition = _controller.position;
      _detailFov = _controller.fieldOfViewDegrees;
      _controller.setProjectionMode(mode);
      _refreshDome();
    } else {
      _controller.setProjectionMode(mode);
      _controller.setSkyDome(null);
      _controller.goto(_detailPosition ?? _targetPosition);
      _controller.setFieldOfView(_detailFov);
    }
  }

  void _refreshDome() {
    if (_controller.projectionMode != SkyAtlasProjectionMode.skyDome) return;
    final site = _selectedLocation;
    if (site == null) {
      _controller.setSkyDome(null);
      _controller.setFieldOfView(180);
      return;
    }
    try {
      final dome = SkyDomeGeometry.calculate(
        location: site,
        utc: _observationUtc,
        minimumAltitudeDegrees: _minimumAltitude,
      );
      _controller.setSkyDome(dome);
      _controller.goto(dome.zenith);
      _controller.setFieldOfView(180);
    } catch (error) {
      if (mounted) {
        setState(() => _feedback = 'Horizon calculation failed: $error');
      }
    }
  }

  Future<void> _pickDomeDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _observationUtc,
      firstDate: DateTime.utc(1900),
      lastDate: DateTime.utc(2100),
      helpText: 'Select UTC observation date',
    );
    if (!mounted || date == null) return;
    setState(() {
      _observationUtc = DateTime.utc(
        date.year,
        date.month,
        date.day,
        _observationUtc.hour,
        _observationUtc.minute,
      );
    });
    _refreshDome();
  }

  Future<void> _pickDomeTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observationUtc),
      helpText: 'Select UTC observation time',
    );
    if (!mounted || time == null) return;
    setState(() {
      _observationUtc = DateTime.utc(
        _observationUtc.year,
        _observationUtc.month,
        _observationUtc.day,
        time.hour,
        time.minute,
      );
    });
    _refreshDome();
  }

  Widget _domeControls() {
    if (widget.observingLocations == null && widget.hostBuilder == null) {
      return Consumer(
        builder: (context, ref, child) {
          final locations = ref.watch(observingLocationsProvider);
          return locations.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) =>
                Text('Observing sites unavailable: $error'),
            data: (items) {
              if (!identical(_lastProviderLocations, items)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _lastProviderLocations = items;
                    _updateLocations(items);
                  });
                });
              }
              return _domeControlContents();
            },
          );
        },
      );
    }
    return _domeControlContents();
  }

  Widget _domeControlContents() {
    final site = _selectedLocation;
    final utc = _observationUtc.toIso8601String().replaceFirst('T', ' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_locations.isEmpty)
          const Text('Add an observing location to display the local horizon.'),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            if (_locations.isNotEmpty)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('dome-site-${_locationId ?? 'none'}'),
                  initialValue: site?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Observing location',
                    isDense: true,
                  ),
                  items: [
                    for (final entry in _locations)
                      DropdownMenuItem(
                        value: entry.id,
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() => _locationId = id);
                    _refreshDome();
                  },
                ),
              ),
            Text(utc.length >= 16 ? '${utc.substring(0, 16)} UTC' : utc),
            OutlinedButton(
              key: const ValueKey('dome-date'),
              onPressed: _pickDomeDate,
              child: const Text('UTC date'),
            ),
            OutlinedButton(
              key: const ValueKey('dome-time'),
              onPressed: _pickDomeTime,
              child: const Text('UTC time'),
            ),
            OutlinedButton(
              key: const ValueKey('dome-now'),
              onPressed: () {
                setState(() => _observationUtc = DateTime.now().toUtc());
                _refreshDome();
              },
              child: const Text('Now'),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('Minimum altitude'),
            SizedBox(
              width: 140,
              child: Slider(
                key: const ValueKey('dome-min-altitude'),
                value: _minimumAltitude,
                min: 0,
                max: 60,
                divisions: 12,
                onChanged: (value) {
                  setState(() => _minimumAltitude = value);
                  _refreshDome();
                },
              ),
            ),
            Text('${_minimumAltitude.round()}°'),
            const Text('Green: horizon · Yellow: minimum altitude'),
          ],
        ),
      ],
    );
  }

  void _onInventory(EquipmentInventory inventory) {
    if (!mounted) return;
    if (identical(_inventory, inventory)) return;
    _inventory = inventory;
    final knownProfile = inventory.profiles.any((p) => p.id == _profileId);
    if (!knownProfile) {
      _profileId = inventory.profiles.isEmpty
          ? null
          : inventory.profiles.first.id;
    }
    _updateCameraFrame();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _updateCameraFrame() {
    final inventory = _inventory;
    final selected = _profileId;
    final center = _framingCenter;
    if (inventory == null || selected == null || center == null) {
      _controller.setCameraFrame(null);
      return;
    }
    try {
      final profile = inventory.profiles.firstWhere((p) => p.id == selected);
      final metrics = inventory.metricsFor(profile);
      final frame = CameraFramingGeometry.calculate(
        configuration: CameraFramingConfiguration(
          profileId: selected,
          center: center,
          rotationDegrees: _rotation,
        ),
        horizontalFovDegrees: metrics.horizontalFovDegrees,
        verticalFovDegrees: metrics.verticalFovDegrees,
      );
      _controller.setCameraFrame(frame);
    } catch (error) {
      _controller.setCameraFrame(null);
      if (mounted) setState(() => _feedback = 'Invalid optical setup: $error');
    }
  }

  void _changeProfile(String? id) {
    if (id == null) return;
    setState(() {
      _profileId = id;
      _feedback = null;
    });
    _updateCameraFrame();
  }

  void _changeRotation(double degrees) {
    setState(() => _rotation = degrees % 360);
    _updateCameraFrame();
  }

  void _setFrameCenter(SkyAtlasPosition center) {
    center.validate();
    setState(() {
      _framingCenter = center;
      _feedback = null;
    });
    _updateCameraFrame();
  }

  void _moveFrame({double east = 0, double north = 0}) {
    final center = _framingCenter;
    final frame = _controller.cameraFrame;
    if (center == null || frame == null) return;
    final distance =
        math.min(frame.horizontalFovDegrees, frame.verticalFovDegrees) * 0.15;
    final dec = (center.decDegrees + north * distance)
        .clamp(-89.999, 89.999)
        .toDouble();
    final cosDec = math.cos(center.decDegrees * math.pi / 180).abs();
    final deltaRa = east * distance / math.max(cosDec, 0.01);
    final ra = (center.raDegrees + deltaRa) % 360;
    _setFrameCenter(
      SkyAtlasPosition(raDegrees: ra < 0 ? ra + 360 : ra, decDegrees: dec),
    );
  }

  Future<void> _saveFrame() async {
    final frame = _controller.cameraFrame;
    if (frame == null) return;
    try {
      await _repository.save(_targetKey, frame.configuration);
      if (mounted) setState(() => _feedback = 'Camera framing saved');
    } catch (error) {
      if (mounted) setState(() => _feedback = 'Unable to save framing: $error');
    }
  }

  void _selectTarget(CelestialObject target) {
    final position = SkyAtlasPosition(
      raDegrees: target.raDegrees,
      decDegrees: target.decDegrees,
    );
    _controller.goto(position);
    _controller.setMarkers(_markersFor(target));
    _controller.setOverlays(_overlaysFor(target));
  }

  @override
  void didUpdateWidget(covariant SkyAtlasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target?.id != oldWidget.target?.id) {
      if (widget.target != null) _selectTarget(widget.target!);
      if (_controller.projectionMode == SkyAtlasProjectionMode.skyDome) {
        _switchMode(SkyAtlasProjectionMode.detail);
      }
      _framingCenter = _targetPosition;
      _profileId = null;
      _rotation = 0;
      _updateCameraFrame();
      _readSaved();
    }
    if (!identical(oldWidget.observingLocations, widget.observingLocations) &&
        widget.observingLocations != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _updateLocations(widget.observingLocations!));
        }
      });
    }
    if (!identical(oldWidget.equipmentInventory, widget.equipmentInventory) &&
        widget.equipmentInventory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onInventory(widget.equipmentInventory!);
      });
    }
  }

  void _retry() {
    setState(() {
      _hostGeneration++;
      _controller.resetLoading();
    });
  }

  @override
  void dispose() {
    _restoreGeneration++;
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Widget _framingControls(EquipmentInventory inventory) {
    if (inventory.profiles.isEmpty) {
      return const Text(
        'Create a camera + optic profile in Equipment to enable framing.',
      );
    }
    final frame = _controller.cameraFrame;
    final targetSize = widget.target?.majorAxisArcmin;
    final shortest = frame == null
        ? null
        : math.min(frame.horizontalFovDegrees, frame.verticalFovDegrees);
    final sizeDegrees = targetSize == null ? null : targetSize / 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            SizedBox(
              width: 245,
              child: DropdownButtonFormField<String>(
                key: ValueKey('frame-profile-${_profileId ?? "none"}'),
                initialValue: inventory.profiles.any((p) => p.id == _profileId)
                    ? _profileId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Imaging setup',
                  isDense: true,
                ),
                items: [
                  for (final profile in inventory.profiles)
                    DropdownMenuItem(
                      value: profile.id,
                      child: Text(profile.name),
                    ),
                ],
                onChanged: _changeProfile,
              ),
            ),
            if (frame != null) ...[
              Text(
                'Sensor ${frame.horizontalFovDegrees.toStringAsFixed(2)}° × '
                '${frame.verticalFovDegrees.toStringAsFixed(2)}°',
              ),
              OutlinedButton.icon(
                key: const ValueKey('frame-use-atlas-center'),
                onPressed: () => _setFrameCenter(_controller.position),
                icon: const Icon(Icons.center_focus_weak),
                label: const Text('Frame at atlas center'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('frame-save'),
                onPressed: _saveFrame,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save frame'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('frame-restore'),
                onPressed: _readSaved,
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
            ],
          ],
        ),
        if (frame != null) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('Rotation ${_rotation.round()}°'),
              SizedBox(
                width: 180,
                child: Slider(
                  key: const ValueKey('frame-rotation'),
                  value: _rotation,
                  min: 0,
                  max: 359,
                  divisions: 359,
                  onChanged: _changeRotation,
                ),
              ),
              IconButton(
                tooltip: 'Move framing west',
                onPressed: () => _moveFrame(east: -1),
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: 'Move framing east',
                onPressed: () => _moveFrame(east: 1),
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: 'Move framing north',
                onPressed: () => _moveFrame(north: 1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move framing south',
                onPressed: () => _moveFrame(north: -1),
                icon: const Icon(Icons.arrow_downward),
              ),
              Text(
                'Center ${_framingCenter!.raDegrees.toStringAsFixed(3)}° RA / '
                '${_framingCenter!.decDegrees.toStringAsFixed(3)}° Dec',
              ),
            ],
          ),
          if (sizeDegrees != null && sizeDegrees > frame.diagonalFovDegrees)
            const Text(
              'Target exceeds the camera field of view.',
              key: ValueKey('frame-too-small'),
              style: TextStyle(color: Colors.orange),
            )
          else if (sizeDegrees != null &&
              shortest != null &&
              sizeDegrees > shortest)
            const Text('Target may require rotation or a wider field of view.'),
        ],
        if (_feedback != null)
          Text(_feedback!, key: const ValueKey('frame-feedback')),
      ],
    );
  }

  Widget _equipmentArea() {
    final injected = widget.equipmentInventory;
    if (injected != null) return _framingControls(injected);
    if (widget.hostBuilder != null) return const SizedBox.shrink();
    return Consumer(
      builder: (context, ref, child) {
        final inventory = ref.watch(equipmentProvider);
        return inventory.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              Text('Unable to load imaging equipment: $error'),
          data: (value) {
            if (!identical(_inventory, value)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _onInventory(value);
              });
            }
            return _framingControls(value);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final target = widget.target;
    final theme = Theme.of(context);
    final isDome = controller.projectionMode == SkyAtlasProjectionMode.skyDome;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          target == null ? 'Sky Atlas' : 'Sky Atlas · ${target.displayTitle}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const ValueKey('atlas-mode-detail'),
                  label: const Text('Detail atlas'),
                  selected: !isDome,
                  onSelected: (_) => _switchMode(SkyAtlasProjectionMode.detail),
                ),
                ChoiceChip(
                  key: const ValueKey('atlas-mode-dome'),
                  label: const Text('Sky dome'),
                  selected: isDome,
                  onSelected: (_) =>
                      _switchMode(SkyAtlasProjectionMode.skyDome),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!isDome)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'RA ${controller.position.raDegrees.toStringAsFixed(4)}°',
                  ),
                  Text(
                    'Dec ${controller.position.decDegrees.toStringAsFixed(4)}°',
                  ),
                  Text(
                    'FOV ${controller.fieldOfViewDegrees.toStringAsFixed(2)}°',
                  ),
                  if (target != null)
                    OutlinedButton.icon(
                      key: const ValueKey('atlas-recenter'),
                      onPressed: () => _selectTarget(target),
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Center target'),
                    ),
                  for (final fov in [0.5, 1.0, 3.0, 10.0, 30.0])
                    ChoiceChip(
                      key: ValueKey('atlas-fov-$fov'),
                      label: Text('${fov.toStringAsFixed(fov < 1 ? 1 : 0)}°'),
                      selected: controller.fieldOfViewDegrees == fov,
                      onSelected: (_) => controller.setFieldOfView(fov),
                    ),
                ],
              ),
            const SizedBox(height: 6),
            if (isDome) _domeControls() else _equipmentArea(),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Center(
                    child: SizedBox(
                      width: isDome ? side : constraints.maxWidth,
                      height: isDome ? side : constraints.maxHeight,
                      child: _atlasViewport(controller, theme),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'DSS2 Color: Digitized Sky Survey (STScI/NASA), colour HiPS by CDS. '
              'HiPS mirror: ESA. Viewer: Aladin Lite (CDS). '
              'Object catalog: OpenNGC (CC BY-SA 4.0).',
              key: ValueKey('atlas-attribution'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _atlasViewport(SkyAtlasController controller, ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              widget.hostBuilder?.call(controller) ??
              SkyAtlasHost(
                key: ValueKey(_hostGeneration),
                controller: controller,
              ),
        ),
        if (controller.status == SkyAtlasStatus.loading ||
            controller.status == SkyAtlasStatus.imageryLoading)
          ColoredBox(
            color: const Color(0xBB111827),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    controller.status == SkyAtlasStatus.imageryLoading
                        ? 'Checking DSS2 Color survey imagery...'
                        : 'Loading Aladin Lite sky survey...',
                  ),
                ],
              ),
            ),
          ),
        if (controller.status == SkyAtlasStatus.error ||
            controller.status == SkyAtlasStatus.unsupported)
          ColoredBox(
            color: theme.colorScheme.surface,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    controller.status == SkyAtlasStatus.unsupported
                        ? 'Embedded sky atlas unsupported'
                        : 'Sky atlas unavailable',
                  ),
                  const SizedBox(height: 8),
                  Text(controller.error ?? 'Unknown atlas error'),
                  const SizedBox(height: 12),
                  if (controller.status == SkyAtlasStatus.error)
                    FilledButton.icon(
                      key: const ValueKey('atlas-retry'),
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
