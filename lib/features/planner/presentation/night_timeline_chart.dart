import 'dart:math' as math;

import 'package:astromanager/l10n/app_text.dart';

import 'package:flutter/material.dart';

import '../../../core/astronomy/solar_events.dart';
import '../../../core/astronomy/target_visibility.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../domain/night_observation_block.dart';
import '../domain/night_timeline.dart';

/// Horizontally scrollable, UTC-proportional lanes. Device timezone is never
/// used for labels, segment geometry or durations.
class NightTimelineChart extends StatelessWidget {
  const NightTimelineChart({
    super.key,
    required this.timeline,
    required this.location,
    required this.visibility,
    required this.blocks,
    required this.onEdit,
    required this.onCreateAt,
    this.weather,
    this.pixelsPerHour = 70,
  });

  final NightTimeline timeline;
  final ObservingLocation location;
  final Map<String, TargetVisibilityResult> visibility;
  final List<NightObservationBlock> blocks;
  final WeatherForecastSnapshot? weather;
  final double pixelsPerHour;
  final ValueChanged<NightObservationBlock> onEdit;
  final ValueChanged<DateTime> onCreateAt;

  double get _width =>
      math.max(900.0, timeline.duration.inMinutes / 60 * pixelsPerHour);

  Widget _bar(
    DateTime start,
    DateTime end,
    Color color,
    String description, {
    double top = 6,
    double height = 24,
    VoidCallback? onTap,
    String? keyName,
  }) {
    final left = timeline.fraction(start) * _width;
    final width = math.max(1.5, timeline.widthFraction(start, end) * _width);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Tooltip(
        message: description,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            key: keyName == null ? null : ValueKey(keyName),
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _lane(
    String label,
    List<Widget> segments, {
    double height = 40,
    Widget? background,
  }) => SizedBox(
    height: height,
    child: Row(
      children: [
        SizedBox(
          width: 175,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            child: AppText(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        SizedBox(
          width: _width,
          height: height,
          child: Stack(
            children: [
              if (background != null) Positioned.fill(child: background),
              ...segments,
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _grid(Color color, double height) => [
    for (final tick in timeline.ticks())
      Positioned(
        left: timeline.fraction(tick) * _width,
        top: 0,
        bottom: 0,
        child: Container(width: 1, color: color),
      ),
  ];

  String _local(DateTime utc) => timeline.clockLabel(utc);

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final muted = palette.outlineVariant;
    final overlap = NightPlanConflicts.detect(blocks);
    final day = timeline.day;
    final followingDay = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: DateTime.utc(
        day.localDate.year,
        day.localDate.month,
        day.localDate.day + 1,
      ),
    );
    final solarMarks = <(String, SolarEvent?, Color)>[
      ('Sunset', day.sunset, palette.tertiary),
      ('Civil dusk', day.civilDusk, palette.tertiary),
      ('Nautical dusk', day.nauticalDusk, palette.secondary),
      ('Astronomical dusk', day.astronomicalDusk, palette.primary),
      ('Astronomical dawn', followingDay.astronomicalDawn, palette.primary),
      ('Nautical dawn', followingDay.nauticalDawn, palette.secondary),
      ('Civil dawn', followingDay.civilDawn, palette.tertiary),
      ('Sunrise', followingDay.sunrise, palette.tertiary),
    ];
    final weatherHours =
        weather?.forecast.hours
            .where(
              (hour) =>
                  !hour.timeUtc.isBefore(timeline.startUtc) &&
                  hour.timeUtc.isBefore(timeline.endUtc),
            )
            .toList() ??
        const [];
    return SingleChildScrollView(
      key: const ValueKey('night-timeline-scroll'),
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lane('Site time (UTC offset)', [
            ..._grid(muted, 42),
            for (final tick in timeline.ticks())
              Positioned(
                left: math.min(timeline.fraction(tick) * _width, _width - 110),
                top: 4,
                width: 110,
                child: AppText(
                  _local(tick),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ], height: 42),
          const Divider(height: 5),
          _lane('Sun / twilight', [
            ..._grid(muted, 44),
            for (final (label, event, color) in solarMarks)
              if (event != null &&
                  !event.utc.isBefore(timeline.startUtc) &&
                  !event.utc.isAfter(timeline.endUtc))
                Positioned(
                  left: timeline.fraction(event.utc) * _width,
                  top: 1,
                  height: 38,
                  child: Tooltip(
                    message: '$label · ${_local(event.utc)}',
                    child: Container(width: 3, color: color),
                  ),
                ),
          ], height: 44),
          _lane('Astronomical dark', [
            ..._grid(muted, 38),
            for (final segment in day.astronomicalDarkness)
              _bar(
                segment.startUtc,
                segment.endUtc,
                palette.primary.withValues(alpha: 0.74),
                'Sun below −18° · ${_local(segment.startUtc)} – ${_local(segment.endUtc)}',
              ),
          ], height: 38),
          _lane('Cloud forecast', [
            ..._grid(muted, 40),
            for (final hour in weatherHours)
              _bar(
                hour.timeUtc,
                hour.timeUtc
                        .add(const Duration(hours: 1))
                        .isAfter(timeline.endUtc)
                    ? timeline.endUtc
                    : hour.timeUtc.add(const Duration(hours: 1)),
                hour.totalCloudCoverPercent.value == null
                    ? palette.outlineVariant
                    : palette.secondary.withValues(
                        alpha:
                            0.2 +
                            hour.totalCloudCoverPercent.value! / 100 * 0.6,
                      ),
                'Cloud cover: ${hour.totalCloudCoverPercent.value?.toStringAsFixed(0) ?? 'unknown'}%'
                '\nPrecipitation: ${hour.precipitationMillimeters.value?.toStringAsFixed(1) ?? 'unknown'} mm/h'
                '\nWind: ${hour.windSpeedMetersPerSecond.value?.toStringAsFixed(1) ?? 'unknown'} m/s'
                '\n${_local(hour.timeUtc)}',
              ),
          ], height: 40),
          for (final entry in visibility.entries)
            _lane('Target: ${entry.key}', [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AltitudePainter(
                    timeline: timeline,
                    result: entry.value,
                    lineColor: palette.tertiary,
                    guideColor: muted,
                    width: _width,
                  ),
                ),
              ),
              for (final interval in entry.value.visibleIntervals)
                _bar(
                  interval.startUtc,
                  interval.endUtc,
                  palette.primary.withValues(alpha: 0.38),
                  'Visible ≥ ${entry.value.minimumAltitudeDegrees.toStringAsFixed(0)}° during astronomical darkness',
                  top: 28,
                  height: 7,
                ),
            ], height: 44),
          const Divider(height: 6),
          if (blocks.isEmpty)
            _lane('Planned observations', [
              Positioned.fill(
                child: InkWell(
                  key: const ValueKey('night-timeline-add-track'),
                  onTapUp: (details) {
                    final fraction = (details.localPosition.dx / _width).clamp(
                      0.0,
                      1.0,
                    );
                    final minutes =
                        ((timeline.duration.inMinutes * fraction) / 15)
                            .round() *
                        15;
                    onCreateAt(
                      timeline.startUtc.add(Duration(minutes: minutes)),
                    );
                  },
                  child: Center(
                    child: AppText(
                      'Tap to schedule a target',
                      style: TextStyle(color: palette.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ], height: 44),
          for (final block in blocks)
            _lane('${block.targetName} · ${block.projectName}', [
              ..._grid(muted, 42),
              _bar(
                block.startUtc,
                block.endUtc,
                overlap.containsKey(block.id) ? palette.error : palette.primary,
                '${block.projectName} · ${block.targetName}\n'
                '${_local(block.startUtc)} – ${_local(block.endUtc)}'
                '${overlap.containsKey(block.id) ? '\nOverlaps another observation!' : ''}\nTap to edit',
                top: 5,
                height: 30,
                keyName: 'night-plan-block-${block.id}',
                onTap: () => onEdit(block),
              ),
            ], height: 42),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AltitudePainter extends CustomPainter {
  const _AltitudePainter({
    required this.timeline,
    required this.result,
    required this.lineColor,
    required this.guideColor,
    required this.width,
  });
  final NightTimeline timeline;
  final TargetVisibilityResult result;
  final Color lineColor;
  final Color guideColor;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    // 0° horizon at 2/3 height, +90° at the top, -45° at bottom.
    double y(double altitude) => (90 - altitude) / 135 * size.height;
    canvas.drawLine(Offset(0, y(30)), Offset(width, y(30)), guide);
    if (result.samples.isEmpty) {
      return;
    }
    final path = Path();
    for (var i = 0; i < result.samples.length; i++) {
      final sample = result.samples[i];
      final x = timeline.fraction(sample.utc) * width;
      final pos = y(sample.horizontal.altitudeDegrees)
          .clamp(0.0, size.height)
          .toDouble();
      if (i == 0) {
        path.moveTo(x, pos);
      } else {
        path.lineTo(x, pos);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _AltitudePainter old) =>
      old.result != result || old.width != width || old.lineColor != lineColor;
}
