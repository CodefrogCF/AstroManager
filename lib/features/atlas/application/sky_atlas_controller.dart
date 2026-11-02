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
  }) : _position = initialPosition,
       _fieldOfViewDegrees = initialFieldOfViewDegrees,
       _markers = List.unmodifiable(initialMarkers),
       _overlays = List.unmodifiable(initialOverlays) {
    _validate();
  }

  SkyAtlasPosition _position;
  double _fieldOfViewDegrees;
  List<SkyAtlasMarker> _markers;
  List<SkyAtlasCircleOverlay> _overlays;
  SkyAtlasStatus _status = SkyAtlasStatus.loading;
  String? _error;
  int _revision = 0;
  CameraFramingFootprint? _cameraFrame;
  MosaicFootprint? _mosaic;
  SkyAtlasProjectionMode _projectionMode = SkyAtlasProjectionMode.detail;
  SkyDomeOverlay? _dome;

  SkyAtlasPosition get position => _position;
  double get fieldOfViewDegrees => _fieldOfViewDegrees;
  List<SkyAtlasMarker> get markers => _markers;
  List<SkyAtlasCircleOverlay> get overlays => _overlays;
  SkyAtlasStatus get status => _status;
  String? get error => _error;
  int get revision => _revision;
  CameraFramingFootprint? get cameraFrame => _cameraFrame;
  MosaicFootprint? get mosaic => _mosaic;
  SkyAtlasProjectionMode get projectionMode => _projectionMode;
  SkyDomeOverlay? get dome => _dome;

  String get stateJson => SkyAtlasProtocol.state(
    position: _position,
    fieldOfViewDegrees: _fieldOfViewDegrees,
    markers: _markers,
    overlays: _overlays,
    cameraFrame: _cameraFrame,
    mosaic: _mosaic,
    projectionMode: _projectionMode,
    dome: _dome,
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
    );
  }

  void goto(SkyAtlasPosition position) {
    position.validate();
    _position = position;
    _revision++;
    notifyListeners();
  }

  void setFieldOfView(double degrees) {
    if (!degrees.isFinite || degrees < 0.01 || degrees > 180) {
      throw ArgumentError.value(degrees, 'degrees');
    }
    _fieldOfViewDegrees = degrees;
    _revision++;
    notifyListeners();
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

  void setProjectionMode(SkyAtlasProjectionMode mode) {
    if (mode == _projectionMode) return;
    _projectionMode = mode;
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
      case 'viewChanged':
        final ra = event['ra'];
        final dec = event['dec'];
        final fov = event['fov'];
        if (ra is! num || dec is! num || fov is! num) return;
        try {
          final next = SkyAtlasPosition(
            raDegrees: ra.toDouble(),
            decDegrees: dec.toDouble(),
          );
          next.validate();
          final zoom = fov.toDouble();
          if (!zoom.isFinite || zoom < 0.01 || zoom > 180) return;
          _position = next;
          _fieldOfViewDegrees = zoom;
          notifyListeners();
        } on ArgumentError {
          // Malformed messages from a third-party JS runtime are ignored.
        }
    }
  }
}
