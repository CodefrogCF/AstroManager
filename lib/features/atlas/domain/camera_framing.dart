import 'dart:math' as math;

import 'sky_atlas_models.dart';

/// Saved pointing and imaging setup. A configuration is stored per catalog
/// target (or under a dedicated key for the untargeted atlas).
final class CameraFramingConfiguration {
  const CameraFramingConfiguration({
    required this.profileId,
    required this.center,
    this.rotationDegrees = 0,
  });

  final String profileId;
  final SkyAtlasPosition center;

  /// Clockwise angle in sky coordinates: positive rotations move the upper
  /// edge toward increasing RA (east), with north toward the top of the frame.
  final double rotationDegrees;

  void validate() {
    center.validate();
    if (profileId.trim().isEmpty ||
        profileId.length > 128 ||
        !rotationDegrees.isFinite ||
        rotationDegrees < 0 ||
        rotationDegrees >= 360) {
      throw ArgumentError('Invalid saved camera framing configuration.');
    }
  }

  Map<String, Object> toJson() {
    validate();
    return {
      'version': 1,
      'profileId': profileId,
      'ra': center.raDegrees,
      'dec': center.decDegrees,
      'rotation': rotationDegrees,
    };
  }

  static CameraFramingConfiguration fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['profileId'] is! String ||
        json['ra'] is! num ||
        json['dec'] is! num ||
        json['rotation'] is! num) {
      throw const FormatException('Invalid camera framing record.');
    }
    final frame = CameraFramingConfiguration(
      profileId: json['profileId'] as String,
      center: SkyAtlasPosition(
        raDegrees: (json['ra'] as num).toDouble(),
        decDegrees: (json['dec'] as num).toDouble(),
      ),
      rotationDegrees: (json['rotation'] as num).toDouble(),
    );
    frame.validate();
    return frame;
  }
}

/// Geometry to be rendered by the Aladin sky-coordinate overlay.
final class CameraFramingFootprint {
  const CameraFramingFootprint({
    required this.configuration,
    required this.horizontalFovDegrees,
    required this.verticalFovDegrees,
    required this.outline,
  });

  final CameraFramingConfiguration configuration;
  final double horizontalFovDegrees;
  final double verticalFovDegrees;
  final List<SkyAtlasPosition> outline;

  double get diagonalFovDegrees =>
      2 *
      math.atan(
        math.sqrt(
          math.pow(math.tan(horizontalFovDegrees * math.pi / 360), 2) +
              math.pow(math.tan(verticalFovDegrees * math.pi / 360), 2),
        ),
      ) *
      180 /
      math.pi;

  Map<String, Object> toJson() => {
    'width': horizontalFovDegrees,
    'height': verticalFovDegrees,
    'rotation': configuration.rotationDegrees,
    'points': [
      for (final p in outline) [p.raDegrees, p.decDegrees],
    ],
  };
}

/// Inverse gnomonic projection from physical angular field-of-view to ICRS.
/// All outlines are fixed on the celestial sphere, independent of atlas zoom.
abstract final class CameraFramingGeometry {
  static CameraFramingFootprint calculate({
    required CameraFramingConfiguration configuration,
    required double horizontalFovDegrees,
    required double verticalFovDegrees,
    int subdivisionsPerEdge = 8,
  }) {
    configuration.validate();
    if (!horizontalFovDegrees.isFinite ||
        !verticalFovDegrees.isFinite ||
        horizontalFovDegrees <= 0 ||
        verticalFovDegrees <= 0 ||
        horizontalFovDegrees >= 170 ||
        verticalFovDegrees >= 170 ||
        subdivisionsPerEdge < 1 ||
        subdivisionsPerEdge > 64) {
      throw ArgumentError('Field of view or outline resolution is invalid.');
    }

    final hx = math.tan(horizontalFovDegrees * math.pi / 360);
    final hy = math.tan(verticalFovDegrees * math.pi / 360);
    final theta = configuration.rotationDegrees * math.pi / 180;
    final cs = math.cos(theta);
    final sn = math.sin(theta);
    final dec0 = configuration.center.decDegrees * math.pi / 180;
    final ra0 = configuration.center.raDegrees * math.pi / 180;

    SkyAtlasPosition project(double u, double v) {
      // Frame axes are east (u), north (v). Positive rotation is clockwise
      // when north is at the top and east to the right.
      final x = u * cs + v * sn;
      final y = -u * sn + v * cs;
      final denominator = math.cos(dec0) - y * math.sin(dec0);
      final ra = ra0 + math.atan2(x, denominator);
      final dec = math.atan2(
        math.sin(dec0) + y * math.cos(dec0),
        math.sqrt(x * x + denominator * denominator),
      );
      final raDeg = (ra * 180 / math.pi) % 360;
      return SkyAtlasPosition(
        raDegrees: raDeg < 0 ? raDeg + 360 : raDeg,
        decDegrees: dec * 180 / math.pi,
      );
    }

    final points = <SkyAtlasPosition>[];
    for (var i = 0; i < subdivisionsPerEdge; i++) {
      final t = i / subdivisionsPerEdge;
      points.add(project(-hx + 2 * hx * t, -hy));
    }
    for (var i = 0; i < subdivisionsPerEdge; i++) {
      final t = i / subdivisionsPerEdge;
      points.add(project(hx, -hy + 2 * hy * t));
    }
    for (var i = 0; i < subdivisionsPerEdge; i++) {
      final t = i / subdivisionsPerEdge;
      points.add(project(hx - 2 * hx * t, hy));
    }
    for (var i = 0; i < subdivisionsPerEdge; i++) {
      final t = i / subdivisionsPerEdge;
      points.add(project(-hx, hy - 2 * hy * t));
    }
    points.add(points.first); // A.polyline is not implicitly closed.

    return CameraFramingFootprint(
      configuration: configuration,
      horizontalFovDegrees: horizontalFovDegrees,
      verticalFovDegrees: verticalFovDegrees,
      outline: List.unmodifiable(points),
    );
  }
}
