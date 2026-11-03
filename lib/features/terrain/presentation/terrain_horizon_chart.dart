import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:astromanager/l10n/app_text.dart';

import '../domain/terrain_horizon.dart';

/// Compass bearings are laid out horizontally (N–E–S–W–N).
/// Gaps deliberately remain blank when the DEM has no coverage.
class TerrainHorizonChart extends StatelessWidget {
  const TerrainHorizonChart({super.key, required this.profile});
  final TerrainHorizonProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // When used in a bounded standalone panel, large text can make the
    // heading and compass labels taller than the available height. Keep the
    // text at the requested scale and scroll the chart instead of overflowing.
    // Inside the dashboard's outer scroll view height is unbounded, so avoid
    // creating a second vertical scrollable there.
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText('Terrain horizon (degrees above horizontal)'),
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
            Row(
              children: [
                for (final bearing in const [
                  'N · 0°',
                  'E · 90°',
                  'S · 180°',
                  'W · 270°',
                  'N · 360°',
                ])
                  Expanded(
                    child: AppText(
                      bearing,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        );
        if (!constraints.hasBoundedHeight) {
          return content;
        }
        return SingleChildScrollView(
          key: const ValueKey('terrain-horizon-scroll'),
          primary: false,
          child: content,
        );
      },
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
