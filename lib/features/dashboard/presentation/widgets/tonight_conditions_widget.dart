import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/astronomy/lunar_ephemeris.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../l10n/app_text.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../application/tonight_conditions_provider.dart';
import '../../domain/tonight_conditions.dart';
import 'dashboard_widget_state.dart';

/// Offline astronomical conditions. The ephemeris provider is only watched
/// while this dashboard widget is mounted; a minute ticker refreshes the
/// remaining-darkness display without recalculating the full ephemeris.
class TonightConditionsWidget extends ConsumerStatefulWidget {
  const TonightConditionsWidget({
    super.key,
    required this.location,
    this.referenceUtc,
  });

  final ObservingLocation? location;

  /// Allows deterministic clock and night-boundary widget tests.
  final DateTime? referenceUtc;

  @override
  ConsumerState<TonightConditionsWidget> createState() =>
      _TonightConditionsWidgetState();
}

class _TonightConditionsWidgetState
    extends ConsumerState<TonightConditionsWidget> {
  Timer? _minuteTimer;
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.referenceUtc == null) {
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty('No observing location selected.'),
        dataBuilder: _unused,
      );
    }
    final nowUtc = (widget.referenceUtc ?? DateTime.now()).toUtc();
    final date = TonightConditionsCalculator.currentNight(site, nowUtc);
    final conditions = ref.watch(
      tonightConditionsProvider((location: site, localDate: date)),
    );
    return conditions.when(
      loading: () => const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.loading(),
        dataBuilder: _unused,
      ),
      error: (error, _) => const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.error(
          'Unable to calculate astronomical conditions.',
        ),
        dataBuilder: _unused,
      ),
      data: (result) => _TonightSummary(
        conditions: result,
        nowUtc: nowUtc,
        detailsExpanded: _detailsExpanded,
        onToggleDetails: () =>
            setState(() => _detailsExpanded = !_detailsExpanded),
      ),
    );
  }

  static Widget _unused(BuildContext context, Object value) =>
      const SizedBox.shrink();
}

class _TonightSummary extends StatelessWidget {
  const _TonightSummary({
    required this.conditions,
    required this.nowUtc,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  final TonightConditions conditions;
  final DateTime nowUtc;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  String _duration(Duration value) {
    final minutes = value.inMinutes;
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  String _clock(SolarEvent? event) =>
      event == null ? '—' : SolarEvents.formatLocal(event.local);

  String _moonClock(LunarEvent? event) =>
      event == null ? '—' : SolarEvents.formatLocal(event.local);

  @override
  Widget build(BuildContext context) {
    final night = conditions;
    final remaining = night.remainingDarknessAt(nowUtc);
    final moonPhase = appTranslate(context, night.moon.phase.label);
    final localDate = night.localDate;
    final dateText =
        '${localDate.day.toString().padLeft(2, '0')}.'
        '${localDate.month.toString().padLeft(2, '0')}.'
        '${localDate.year}';
    final textStyle = Theme.of(context).textTheme.labelSmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 310;
        final compact = narrow && !detailsExpanded;
        final content = Column(
          key: const ValueKey('dashboard-tonight'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(dateText, style: Theme.of(context).textTheme.labelMedium),
                Text(night.night.timeZone, style: textStyle),
              ],
            ),
            const SizedBox(height: 7),
            if (night.darknessState == TonightDarknessState.none)
              const AppText('No astronomical darkness during this night.')
            else if (night.darknessState == TonightDarknessState.continuous)
              const AppText(
                'Continuous astronomical darkness throughout this observing night.',
              )
            else
              const AppText(
                'Astronomical darkness',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 5),
            _Stat(
              key: const ValueKey('dashboard-tonight-darkness'),
              label: 'Darkness duration',
              value: _duration(night.darknessDuration),
              prominent: true,
            ),
            _Stat(
              key: const ValueKey('dashboard-tonight-remaining'),
              label: 'Remaining darkness',
              value: _duration(remaining),
            ),
            const Divider(height: 15),
            _Stat(
              key: const ValueKey('dashboard-tonight-moon'),
              label: 'Moon phase and illumination',
              value:
                  '$moonPhase · '
                  '${(night.moon.illuminationFraction * 100).toStringAsFixed(1)}%',
            ),
            _Stat(
              key: const ValueKey('dashboard-tonight-sunset'),
              label: 'Sunset / sunrise',
              value: '${_clock(night.sunset)}  /  ${_clock(night.sunrise)}',
            ),
            if (!compact) ...[
              _Stat(
                key: const ValueKey('dashboard-tonight-dusk'),
                label: 'Astronomical dusk / dawn',
                value:
                    '${_clock(night.astronomicalDusk)}  /  '
                    '${_clock(night.astronomicalDawn)}',
              ),
              const Divider(height: 15),
              _Stat(
                key: const ValueKey('dashboard-tonight-moonrise'),
                label: 'Moonrise / moonset',
                value:
                    '${_moonClock(night.moonEvents.moonrise)}  /  '
                    '${_moonClock(night.moonEvents.moonset)}',
              ),
              if (night.moonEvents.events.isEmpty)
                AppText(switch (night.moonEvents.state) {
                  LunarCrossingState.alwaysAbove => 'Moon stays above horizon',
                  LunarCrossingState.alwaysBelow => 'Moon stays below horizon',
                  LunarCrossingState.crossings =>
                    'No lunar crossing this night',
                }, style: textStyle),
              if (night.sunset == null ||
                  night.sunrise == null ||
                  night.astronomicalDusk == null ||
                  night.astronomicalDawn == null) ...[
                const SizedBox(height: 5),
                const AppText(
                  'Some solar events do not occur during this observing night.',
                ),
              ],
            ],
            if (narrow)
              TextButton.icon(
                key: const ValueKey('dashboard-tonight-details'),
                onPressed: onToggleDetails,
                icon: Icon(compact ? Icons.expand_more : Icons.expand_less),
                label: AppText(compact ? 'Show details' : 'Hide details'),
              ),
            const SizedBox(height: 6),
            TextButton.icon(
              key: const ValueKey('dashboard-tonight-planner'),
              onPressed: () => context.go(AppRoutes.planner),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const AppText('Open Night Planner'),
            ),
          ],
        );
        if (!constraints.hasBoundedHeight) {
          return content;
        }
        return SingleChildScrollView(primary: false, child: content);
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          softWrap: true,
          style: prominent
              ? Theme.of(context).textTheme.titleSmall
              : Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
