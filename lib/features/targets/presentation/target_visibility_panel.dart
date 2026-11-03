import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../../core/astronomy/solar_events.dart';
import '../../../core/astronomy/target_visibility.dart';
import '../../locations/domain/models/observing_location.dart';
import '../domain/models/celestial_object.dart';

/// Local-noon-to-noon visibility of one OpenNGC target for a saved site.
/// Visibility is additionally restricted to astronomical darkness.
class TargetVisibilityPanel extends StatefulWidget {
  const TargetVisibilityPanel({
    super.key,
    required this.object,
    required this.location,
    required this.localDate,
  });

  final CelestialObject object;
  final ObservingLocation location;
  final DateTime localDate;

  @override
  State<TargetVisibilityPanel> createState() => _TargetVisibilityPanelState();
}

class _TargetVisibilityPanelState extends State<TargetVisibilityPanel> {
  double _minimumAltitude = 30;

  String _localTime(DateTime utc) {
    final zone = SolarEvents.timeZone(widget.location.timeZone);
    final local = tz.TZDateTime.from(utc, zone);
    return SolarEvents.formatLocal(local, includeDate: true);
  }

  @override
  Widget build(BuildContext context) {
    final result = TargetVisibility.forObservingNight(
      targetJ2000: EquatorialPosition(
        raDegrees: widget.object.raDegrees,
        decDegrees: widget.object.decDegrees,
      ),
      location: widget.location,
      localDate: widget.localDate,
      minimumAltitudeDegrees: _minimumAltitude,
    );

    final textTheme = Theme.of(context).textTheme;
    final label = switch (result.state) {
      TargetVisibilityState.continuouslyVisible =>
        'Visible throughout astronomical darkness',
      TargetVisibilityState.partiallyVisible =>
        'Visible during part of astronomical darkness',
      TargetVisibilityState.notVisible =>
        result.allowedIntervals.isEmpty
            ? 'No astronomical darkness during this observing night'
            : 'Target does not reach the minimum altitude in darkness',
    };

    return Column(
      key: const ValueKey('target-visibility-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Target visibility · observing night',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        AppText(
          'Local noon to next noon; Sun below −18°. '
          'Geometric altitude without terrain or atmospheric refraction.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        AppText('Minimum altitude: ${_minimumAltitude.toStringAsFixed(0)}°'),
        Slider(
          key: const ValueKey('target-min-altitude-slider'),
          value: _minimumAltitude,
          min: 0,
          max: 70,
          divisions: 14,
          label: '${_minimumAltitude.toStringAsFixed(0)}°',
          onChanged: (value) => setState(() => _minimumAltitude = value),
        ),
        AppText(label, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        AppText(
          'Available: ${result.totalVisibleDuration.inMinutes} min'
          ' / ${result.totalAllowedDuration.inMinutes} min darkness',
        ),
        if (result.bestTimeUtc != null) ...[
          const SizedBox(height: 8),
          AppText(
            'Best: ${result.bestAltitudeDegrees!.toStringAsFixed(1)}° '
            'at ${_localTime(result.bestTimeUtc!)}',
            key: const ValueKey('target-visibility-best'),
          ),
        ],
        if (result.culminations.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final culmination in result.culminations)
            AppText(
              'Upper culmination: '
              '${culmination.horizontal.altitudeDegrees.toStringAsFixed(1)}° '
              'at ${_localTime(culmination.utc)}',
            ),
        ],
        if (result.visibleIntervals.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppText('Visibility windows', style: textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final window in result.visibleIntervals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: AppText(
                '${_localTime(window.startUtc)} – '
                '${_localTime(window.endUtc)} '
                '(${window.duration.inMinutes} min)',
              ),
            ),
        ],
      ],
    );
  }
}
