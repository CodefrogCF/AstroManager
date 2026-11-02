import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/terrain_horizon.dart';

/// Compass bearings are laid out horizontally (N–E–S–W–N).
/// Gaps deliberately remain blank when the DEM has no coverage.
class TerrainHorizonChart extends StatelessWidget {
  const TerrainHorizonChart({super.key, required this.profile});
  final TerrainHorizonProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Terrain horizon (degrees above horizontal)'),
        const SizedBox(height: 4),
        SizedBox(
          height: 156,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey('terrain-horizon-plot'),
            painter: _TerrainHorizonPainter(
              profile,
              theme.colorScheme.primary,
              theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('N · 0°'),
            Text('E · 90°'),
            Text('S · 180°'),
            Text('W · 270°'),
            Text('N · 360°'),
          ],
        ),
      ],
    );
  }
}

class _TerrainHorizonPainter extends CustomPainter {
  const _TerrainHorizonPainter(this.profile, this.color, this.gridColor);
  final TerrainHorizonProfile profile;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 12.0;
    const bottom = 20.0;
    const minimum = -10.0;
    const maximum = 50.0;
    double x(double az) => size.width * az / 360;
    double y(double altitude) =>
        top +
        (maximum - altitude.clamp(minimum, maximum)) /
            (maximum - minimum) *
            (size.height - top - bottom);
    final guide = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final angle in [-10.0, 0.0, 10.0, 30.0, 50.0]) {
      canvas.drawLine(Offset(0, y(angle)), Offset(size.width, y(angle)), guide);
    }
    for (final bearing in [0.0, 90.0, 180.0, 270.0, 360.0]) {
      canvas.drawLine(
        Offset(x(bearing), top),
        Offset(x(bearing), size.height - bottom),
        guide,
      );
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final step = profile.options.azimuthStepDegrees.toDouble();
    for (var i = 0; i < profile.bearings.length; i++) {
      final angle = profile.bearings[i].altitudeDegrees;
      if (angle == null) {
        continue;
      }
      // No line is drawn across unknown neighboring bearings.
      final next =
          profile.bearings[(i + 1) % profile.bearings.length].altitudeDegrees;
      if (next == null) {
        continue;
      }
      final path = Path()
        ..moveTo(x(i * step), y(angle))
        ..lineTo(x(math.min(360.0, (i + 1) * step)), y(next));
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_TerrainHorizonPainter oldDelegate) =>
      oldDelegate.profile != profile ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
