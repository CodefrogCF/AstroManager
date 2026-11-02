import 'dart:convert';
import 'dart:math' as math;

import '../../atlas/domain/sky_atlas_models.dart';
import '../../equipment/domain/models/equipment_models.dart';

/// Project-owned imaging mosaic. Coordinates are ICRS/J2000 decimal degrees.
/// Panel order is row-major, from top-left (north-west) to bottom-right.
final class MosaicPlan {
  const MosaicPlan({
    required this.projectId,
    required this.targetId,
    required this.profileId,
    required this.center,
    this.rows = 2,
    this.columns = 2,
    this.overlapPercent = 15,
    this.rotationDegrees = 0,
  });

  final String projectId;
  final String targetId;
  final String profileId;
  final SkyAtlasPosition center;
  final int rows;
  final int columns;
  final double overlapPercent;
  final double rotationDegrees;

  void validate() {
    center.validate();
    if (projectId.trim().isEmpty ||
        targetId.trim().isEmpty ||
        profileId.trim().isEmpty ||
        rows < 1 ||
        columns < 1 ||
        rows > 10 ||
        columns > 10 ||
        rows * columns > 64 ||
        !overlapPercent.isFinite ||
        overlapPercent < 0 ||
        overlapPercent >= 90 ||
        !rotationDegrees.isFinite ||
        rotationDegrees < 0 ||
        rotationDegrees >= 360) {
      throw const FormatException('Invalid mosaic configuration.');
    }
  }

  MosaicPlan copyWith({
    String? profileId,
    SkyAtlasPosition? center,
    int? rows,
    int? columns,
    double? overlapPercent,
    double? rotationDegrees,
  }) => MosaicPlan(
    projectId: projectId,
    targetId: targetId,
    profileId: profileId ?? this.profileId,
    center: center ?? this.center,
    rows: rows ?? this.rows,
    columns: columns ?? this.columns,
    overlapPercent: overlapPercent ?? this.overlapPercent,
    rotationDegrees: rotationDegrees ?? this.rotationDegrees,
  );

  Map<String, Object> toJson() {
    validate();
    return {
      'version': 1,
      'projectId': projectId,
      'targetId': targetId,
      'profileId': profileId,
      'centerRaDeg': center.raDegrees,
      'centerDecDeg': center.decDegrees,
      'rows': rows,
      'columns': columns,
      'overlapPercent': overlapPercent,
      'rotationDegrees': rotationDegrees,
    };
  }

  factory MosaicPlan.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['projectId'] is! String ||
        json['targetId'] is! String ||
        json['profileId'] is! String ||
        json['centerRaDeg'] is! num ||
        json['centerDecDeg'] is! num ||
        json['rows'] is! int ||
        json['columns'] is! int ||
        json['overlapPercent'] is! num ||
        json['rotationDegrees'] is! num) {
      throw const FormatException('Unsupported mosaic plan format.');
    }
    final result = MosaicPlan(
      projectId: json['projectId'] as String,
      targetId: json['targetId'] as String,
      profileId: json['profileId'] as String,
      center: SkyAtlasPosition(
        raDegrees: (json['centerRaDeg'] as num).toDouble(),
        decDegrees: (json['centerDecDeg'] as num).toDouble(),
      ),
      rows: json['rows'] as int,
      columns: json['columns'] as int,
      overlapPercent: (json['overlapPercent'] as num).toDouble(),
      rotationDegrees: (json['rotationDegrees'] as num).toDouble(),
    );
    result.validate();
    return result;
  }
}

final class MosaicPanel {
  const MosaicPanel({
    required this.row,
    required this.column,
    required this.center,
    required this.outline,
  });
  final int row;
  final int column;
  final SkyAtlasPosition center;
  final List<SkyAtlasPosition> outline;
  String get label => 'R${row + 1}C${column + 1}';
  Map<String, Object> toJson() => {
    'label': label,
    'row': row + 1,
    'column': column + 1,
    'ra': center.raDegrees,
    'dec': center.decDegrees,
    'points': [
      for (final p in outline) [p.raDegrees, p.decDegrees],
    ],
  };
}

final class MosaicFootprint {
  const MosaicFootprint({
    required this.plan,
    required this.panels,
    required this.outline,
    required this.widthDegrees,
    required this.heightDegrees,
    required this.panelWidthDegrees,
    required this.panelHeightDegrees,
  });
  final MosaicPlan plan;
  final List<MosaicPanel> panels;
  final List<SkyAtlasPosition> outline;

  /// Angular width/height along the mosaic's own rotated axes.
  final double widthDegrees;
  final double heightDegrees;
  final double panelWidthDegrees;
  final double panelHeightDegrees;

  Map<String, Object> toJson() => {
    'panels': [for (final panel in panels) panel.toJson()],
    'outline': [
      for (final p in outline) [p.raDegrees, p.decDegrees],
    ],
  };

  /// Standalone portable pointing list, independent of the atlas bridge.
  /// Numeric RA/Dec are decimal ICRS degrees, not hours or apparent coordinates.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'format': 'astromanager-mosaic-panels',
    'version': 1,
    'referenceFrame': 'ICRS/J2000',
    'coordinateUnit': 'degrees',
    'order': 'row-major, north-west to south-east',
    'plan': plan.toJson(),
    'panelFovDegrees': {
      'width': panelWidthDegrees,
      'height': panelHeightDegrees,
    },
    'mosaicFovDegrees': {'width': widthDegrees, 'height': heightDegrees},
    'panels': [for (final panel in panels) panel.toJson()],
  });
}

/// Common tangent-plane layout with a true inverse gnomonic projection.
/// This avoids linear RA offsets, RA wraparound and near-pole errors.
abstract final class MosaicGeometry {
  static MosaicFootprint calculate({
    required MosaicPlan plan,
    required OpticalMetrics optics,
  }) {
    plan.validate();
    final w = optics.horizontalFovDegrees;
    final h = optics.verticalFovDegrees;
    if (!w.isFinite ||
        !h.isFinite ||
        w <= 0 ||
        h <= 0 ||
        w >= 120 ||
        h >= 120) {
      throw const FormatException('Invalid optical field of view for mosaic.');
    }
    final halfX = math.tan(w * math.pi / 360);
    final halfY = math.tan(h * math.pi / 360);
    final stepX = 2 * halfX * (1 - plan.overlapPercent / 100);
    final stepY = 2 * halfY * (1 - plan.overlapPercent / 100);
    final totalHalfX = halfX + (plan.columns - 1) * stepX / 2;
    final totalHalfY = halfY + (plan.rows - 1) * stepY / 2;
    // The tangent plane must remain within the forward hemisphere.
    if (2 * math.atan(totalHalfX) * 180 / math.pi >= 170 ||
        2 * math.atan(totalHalfY) * 180 / math.pi >= 170 ||
        math.sqrt(totalHalfX * totalHalfX + totalHalfY * totalHalfY) > 10) {
      throw const FormatException(
        'Mosaic is too wide for a single tangent-plane chart.',
      );
    }
    final ra0 = plan.center.raDegrees * math.pi / 180;
    final dec0 = plan.center.decDegrees * math.pi / 180;
    final rotation = plan.rotationDegrees * math.pi / 180;
    final cs = math.cos(rotation);
    final sn = math.sin(rotation);
    SkyAtlasPosition project(double east, double north) {
      final x = east * cs + north * sn;
      final y = -east * sn + north * cs;
      final denominator = math.cos(dec0) - y * math.sin(dec0);
      final ra = (ra0 + math.atan2(x, denominator)) * 180 / math.pi;
      final dec =
          math.atan2(
            math.sin(dec0) + y * math.cos(dec0),
            math.sqrt(x * x + denominator * denominator),
          ) *
          180 /
          math.pi;
      return SkyAtlasPosition(
        raDegrees: (ra % 360 + 360) % 360,
        decDegrees: dec.clamp(-90.0, 90.0).toDouble(),
      );
    }

    List<SkyAtlasPosition> rectangle(
      double left,
      double right,
      double bottom,
      double top,
    ) => List.unmodifiable([
      project(left, bottom),
      project(right, bottom),
      project(right, top),
      project(left, top),
      project(left, bottom),
    ]);
    final panels = <MosaicPanel>[];
    for (var row = 0; row < plan.rows; row++) {
      final cy = (plan.rows - 1 - 2 * row) * stepY / 2;
      for (var column = 0; column < plan.columns; column++) {
        final cx = (2 * column - plan.columns + 1) * stepX / 2;
        panels.add(
          MosaicPanel(
            row: row,
            column: column,
            center: project(cx, cy),
            outline: rectangle(cx - halfX, cx + halfX, cy - halfY, cy + halfY),
          ),
        );
      }
    }
    return MosaicFootprint(
      plan: plan,
      panels: List.unmodifiable(panels),
      outline: rectangle(-totalHalfX, totalHalfX, -totalHalfY, totalHalfY),
      widthDegrees: 2 * math.atan(totalHalfX) * 180 / math.pi,
      heightDegrees: 2 * math.atan(totalHalfY) * 180 / math.pi,
      panelWidthDegrees: w,
      panelHeightDegrees: h,
    );
  }
}
