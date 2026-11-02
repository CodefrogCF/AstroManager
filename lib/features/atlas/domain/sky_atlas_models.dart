import 'dart:convert';

import 'camera_framing.dart';

/// An ICRS/J2000 sky position in decimal degrees.
final class SkyAtlasPosition {
  const SkyAtlasPosition({required this.raDegrees, required this.decDegrees});

  final double raDegrees;
  final double decDegrees;

  void validate() {
    if (!raDegrees.isFinite || raDegrees < 0 || raDegrees >= 360) {
      throw ArgumentError.value(raDegrees, 'raDegrees', 'Expected [0, 360).');
    }
    if (!decDegrees.isFinite || decDegrees < -90 || decDegrees > 90) {
      throw ArgumentError.value(
        decDegrees,
        'decDegrees',
        'Expected [-90, 90].',
      );
    }
  }

  Map<String, Object> toJson() => {'ra': raDegrees, 'dec': decDegrees};
}

final class SkyAtlasMarker {
  const SkyAtlasMarker({
    required this.id,
    required this.position,
    required this.label,
  });

  final String id;
  final SkyAtlasPosition position;
  final String label;

  Map<String, Object> toJson() {
    position.validate();
    if (id.trim().isEmpty ||
        label.trim().isEmpty ||
        id.length > 128 ||
        label.length > 180) {
      throw ArgumentError('Invalid atlas marker identifier or label.');
    }
    return {'id': id, 'label': label, ...position.toJson()};
  }
}

/// Circular annotations in sky coordinates. Camera framing is a later issue.
final class SkyAtlasCircleOverlay {
  const SkyAtlasCircleOverlay({
    required this.position,
    required this.radiusDegrees,
    this.color = '#3dd5f3',
  });

  final SkyAtlasPosition position;
  final double radiusDegrees;
  final String color;

  Map<String, Object> toJson() {
    position.validate();
    if (!radiusDegrees.isFinite || radiusDegrees <= 0 || radiusDegrees > 90) {
      throw ArgumentError.value(radiusDegrees, 'radiusDegrees');
    }
    if (!RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(color)) {
      throw ArgumentError.value(color, 'color');
    }
    return {...position.toJson(), 'radius': radiusDegrees, 'color': color};
  }
}

/// A geometric (unrefracted) local horizon, expressed in J2000/ICRS-like
/// equatorial coordinates for the Aladin image-survey frame.
///
/// This is a planning aid, not a terrain profile or an astrometric pointing
/// solution. Mean sidereal time approximates UT1 with UTC; nutation and
/// refraction are deliberately omitted, consistently with Issue #11.
final class SkyDomeOverlay {
  const SkyDomeOverlay({
    required this.zenith,
    required this.horizon,
    required this.altitude30,
    required this.altitude60,
    required this.minimumAltitude,
    required this.minimumAltitudeDegrees,
    required this.cardinals,
  });

  final SkyAtlasPosition zenith;
  final List<SkyAtlasPosition> horizon;
  final List<SkyAtlasPosition> altitude30;
  final List<SkyAtlasPosition> altitude60;
  final List<SkyAtlasPosition> minimumAltitude;
  final double minimumAltitudeDegrees;
  final List<SkyAtlasMarker> cardinals;

  Map<String, Object> toJson() => {
    'zenith': zenith.toJson(),
    'horizon': _points(horizon),
    'altitude30': _points(altitude30),
    'altitude60': _points(altitude60),
    'minimumAltitude': _points(minimumAltitude),
    'minimumAltitudeDegrees': minimumAltitudeDegrees,
    'cardinals': cardinals.map((item) => item.toJson()).toList(),
  };

  static List<List<double>> _points(List<SkyAtlasPosition> positions) => [
    for (final position in positions) [position.raDegrees, position.decDegrees],
  ];
}

enum SkyAtlasProjectionMode { detail, skyDome }

/// Versioned JSON envelope shared by browser and native WebView bridges.
abstract final class SkyAtlasProtocol {
  static const identifier = 'astromanager.aladin';
  static const version = 1;

  static String state({
    CameraFramingFootprint? cameraFrame,
    SkyAtlasProjectionMode projectionMode = SkyAtlasProjectionMode.detail,
    SkyDomeOverlay? dome,
    required SkyAtlasPosition position,
    required double fieldOfViewDegrees,
    required List<SkyAtlasMarker> markers,
    List<SkyAtlasCircleOverlay> overlays = const [],
  }) {
    position.validate();
    if (!fieldOfViewDegrees.isFinite ||
        fieldOfViewDegrees < 0.01 ||
        fieldOfViewDegrees > 180) {
      throw ArgumentError.value(fieldOfViewDegrees, 'fieldOfViewDegrees');
    }
    return jsonEncode({
      'protocol': identifier,
      'version': version,
      'type': 'state',
      ...position.toJson(),
      'fov': fieldOfViewDegrees,
      'markers': markers.map((m) => m.toJson()).toList(),
      'overlays': overlays.map((o) => o.toJson()).toList(),
      'cameraFrame': cameraFrame?.toJson(),
      'projection': projectionMode == SkyAtlasProjectionMode.skyDome
          ? 'dome'
          : 'detail',
      'dome': dome?.toJson(),
    });
  }

  static Map<String, dynamic>? parseEvent(String jsonText) {
    try {
      final result = jsonDecode(jsonText);
      if (result is! Map<String, dynamic> ||
          result['protocol'] != identifier ||
          result['version'] != version ||
          result['type'] is! String) {
        return null;
      }
      return result;
    } on FormatException {
      return null;
    }
  }
}
