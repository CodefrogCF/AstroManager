import 'package:flutter/foundation.dart';

import '../domain/sky_atlas_models.dart';
import '../domain/camera_framing.dart';
import '../../mosaic/domain/mosaic_plan.dart';

enum SkyAtlasStatus { loading, imageryLoading, ready, error, unsupported }

/// Single source of truth; platform adapters only transport JSON packets.
class SkyAtlasController extends ChangeNotifier {
  SkyAtlasController({
    required SkyAtlasPosition initialPosition,
    double initialFieldOfViewDegrees = 3,
    List<SkyAtlasMarker> initialMarkers = const [],
    List<SkyAtlasCircleOverlay> initialOverlays = const [],
    this.onSkyTap,
  }) : _position = initialPosition,
       _fieldOfViewDegrees = initialFieldOfViewDegrees,
       _markers = List.unmodifiable(initialMarkers),
       _overlays = List.unmodifiable(initialOverlays) {
    _validate();
  }

  SkyAtlasPosition _position;
  final void Function(SkyAtlasPosition position, double toleranceDegrees)?
  onSkyTap;
  double _fieldOfViewDegrees;
  List<SkyAtlasMarker> _markers;
  List<SkyAtlasCircleOverlay> _overlays;
  SkyAtlasStatus _status = SkyAtlasStatus.loading;
  String? _error;
  int _revision = 0;
  int _viewRevision = 0;
  bool _pointerInputEnabled = true;
  CameraFramingFootprint? _cameraFrame;
  MosaicFootprint? _mosaic;
  SkyAtlasProjectionMode _projectionMode = SkyAtlasProjectionMode.detail;
  SkyDomeOverlay? _dome;
  // null: Aladin native controls follow responsive default (hidden on phones).
  bool? _showAladinControls;

  SkyAtlasPosition get position => _position;
  double get fieldOfViewDegrees => _fieldOfViewDegrees;
  List<SkyAtlasMarker> get markers => _markers;
  List<SkyAtlasCircleOverlay> get overlays => _overlays;
  SkyAtlasStatus get status => _status;
  String? get error => _error;
  int get revision => _revision;
  bool get pointerInputEnabled => _pointerInputEnabled;
  CameraFramingFootprint? get cameraFrame => _cameraFrame;
  MosaicFootprint? get mosaic => _mosaic;
  SkyAtlasProjectionMode get projectionMode => _projectionMode;
  SkyDomeOverlay? get dome => _dome;
  bool? get showAladinControls => _showAladinControls;

  String get stateJson => SkyAtlasProtocol.state(
    position: _position,
    fieldOfViewDegrees: _fieldOfViewDegrees,
    markers: _markers,
    overlays: _overlays,
    cameraFrame: _cameraFrame,
    mosaic: _mosaic,
    projectionMode: _projectionMode,
    dome: _dome,
    showAladinControls: _showAladinControls,
    viewRevision: _viewRevision,
  );

  void _validate() {
    SkyAtlasProtocol.state(
      position: _position,
      fieldOfViewDegrees: _fieldOfViewDegrees,
      markers: _markers,
      overlays: _overlays,
      cameraFrame: _cameraFrame,
      mosaic: _mosaic,
      projectionMode: _projectionMode,
      dome: _dome,
      showAladinControls: _showAladinControls,
    );
  }

  void goto(SkyAtlasPosition position) {
    position.validate();
    _position = position;
    _viewChanged();
  }

  void setFieldOfView(double degrees) {
    if (!degrees.isFinite || degrees < 0.01 || degrees > 180) {
      throw ArgumentError.value(degrees, 'degrees');
    }
    _fieldOfViewDegrees = degrees;
    _viewChanged();
  }

  void setMarkers(List<SkyAtlasMarker> markers) {
    final copied = List<SkyAtlasMarker>.unmodifiable(markers);
    for (final marker in copied) {
      marker.toJson();
    }
    _markers = copied;
    _revision++;
    notifyListeners();
  }

  void setOverlays(List<SkyAtlasCircleOverlay> overlays) {
    final copied = List<SkyAtlasCircleOverlay>.unmodifiable(overlays);
    for (final overlay in copied) {
      overlay.toJson();
    }
    _overlays = copied;
    _revision++;
    notifyListeners();
  }

  void setSelection({SkyAtlasMarker? marker, SkyAtlasCircleOverlay? outline}) {
    marker?.toJson();
    outline?.toJson();
    _markers = marker == null ? const [] : List.unmodifiable([marker]);
    _overlays = outline == null ? const [] : List.unmodifiable([outline]);
    _revision++;
    notifyListeners();
  }

  void setPointerInputEnabled(bool value) {
    if (value == _pointerInputEnabled) return;
    _pointerInputEnabled = value;
    notifyListeners();
  }

  void setProjectionMode(SkyAtlasProjectionMode mode) {
    if (mode == _projectionMode) return;
    _projectionMode = mode;
    _viewChanged();
  }

  void _viewChanged() {
    _viewRevision++;
    _revision++;
    notifyListeners();
  }

  void setSkyDome(SkyDomeOverlay? dome) {
    _dome = dome;
    _revision++;
    notifyListeners();
  }

  void setCameraFrame(CameraFramingFootprint? frame) {
    _cameraFrame = frame;
    _revision++;
    notifyListeners();
  }

  void setShowAladinControls(bool? value) {
    if (_showAladinControls == value) return;
    _showAladinControls = value;
    _revision++;
    notifyListeners();
  }

  void setMosaic(MosaicFootprint? mosaic) {
    _mosaic = mosaic;
    _revision++;
    notifyListeners();
  }

  /// The transport and geometry are deliberately retained across retries.
  void reportUnsupported(String message) {
    _status = SkyAtlasStatus.unsupported;
    _error = message;
    notifyListeners();
  }

  void resetLoading() {
    _status = SkyAtlasStatus.loading;
    _error = null;
    notifyListeners();
  }

  void reportError(String message) {
    _status = SkyAtlasStatus.error;
    _error = message;
    notifyListeners();
  }

  /// Called by either iframe postMessage or the native JavaScript channel.
  /// View-change events do not bump the outbound command revision (no echo).
  void receive(String packet) {
    final event = SkyAtlasProtocol.parseEvent(packet);
    if (event == null) return;
    switch (event['type']) {
      case 'ready':
        _status = SkyAtlasStatus.ready;
        _error = null;
        notifyListeners();
      case 'imageryLoading':
        _status = SkyAtlasStatus.imageryLoading;
        _error = null;
        notifyListeners();
      case 'imageryReady':
        _status = SkyAtlasStatus.ready;
        _error = null;
        notifyListeners();
      case 'imageryError':
        reportError(
          (event['message'] as String?) ?? 'Survey imagery unavailable.',
        );
      case 'error':
        reportError((event['message'] as String?) ?? 'Atlas unavailable.');
      case 'skyTap':
        if (!_pointerInputEnabled) return;
        final position = _eventPosition(event);
        final tolerance = event['tolerance'];
        if (position == null ||
            tolerance is! num ||
            !tolerance.isFinite ||
            tolerance <= 0 ||
            tolerance > 180) {
          return;
        }
        onSkyTap?.call(position, tolerance.toDouble());
      case 'viewChanged':
        final position = _eventPosition(event);
        final fov = event['fov'];
        if (position == null ||
            fov is! num ||
            !fov.isFinite ||
            fov < 0.01 ||
            fov > 180) {
          return;
        }
        _position = position;
        _fieldOfViewDegrees = fov.toDouble();
        notifyListeners();
    }
  }

  SkyAtlasPosition? _eventPosition(Map<String, dynamic> event) {
    final ra = event['ra'];
    final dec = event['dec'];
    if (ra is! num || dec is! num) return null;
    final position = SkyAtlasPosition(
      raDegrees: ra.toDouble(),
      decDegrees: dec.toDouble(),
    );
    try {
      position.validate();
      return position;
    } on ArgumentError {
      return null;
    }
  }
}
