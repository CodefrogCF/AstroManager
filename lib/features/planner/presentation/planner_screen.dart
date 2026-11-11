import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../../core/astronomy/lunar_ephemeris.dart';
import '../../../core/astronomy/solar_events.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import 'night_planning_section.dart';

/// Solar events and darkness for one observing site and local calendar date.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({
    super.key,
    this.initialLocationId,
    this.initialDate,
    this.initialProjectId,
    this.initialTargetId,
  });

  final String? initialLocationId;
  final DateTime? initialDate;
  final String? initialProjectId;
  final String? initialTargetId;

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime? _selectedDate;
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedLocationId = widget.initialLocationId;
  }

  @override
  void didUpdateWidget(covariant PlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLocationId != oldWidget.initialLocationId ||
        widget.initialDate != oldWidget.initialDate ||
        widget.initialProjectId != oldWidget.initialProjectId ||
        widget.initialTargetId != oldWidget.initialTargetId) {
      _selectedLocationId = widget.initialLocationId;
      _selectedDate = widget.initialDate;
    }
  }

  Future<void> _pickDate(DateTime date, DateTime today) async {
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100, 12, 31);
    final selected = await showDatePicker(
      context: context,
      initialDate: date.isBefore(firstDate) || date.isAfter(lastDate)
          ? today
          : date,
      currentDate: today,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedDate = selected);
  }

  Widget _eventRow(String label, SolarEvent? event, SolarCrossingState state) {
    final value = event == null
        ? switch (state) {
            SolarCrossingState.alwaysAbove => 'Sun stays above threshold',
            SolarCrossingState.alwaysBelow => 'Sun stays below threshold',
            SolarCrossingState.normal => 'No crossing on this date',
          }
        : SolarEvents.formatLocal(event.local);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 155, child: AppText(label)),
          Expanded(child: AppText(value)),
        ],
      ),
    );
  }

  Widget _thresholdCard(
    SolarDayEvents day,
    SolarThreshold threshold,
    String heading,
    String dawnLabel,
    String duskLabel,
  ) {
    final events = day.forThreshold(threshold);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(heading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _eventRow(dawnLabel, events.morning, events.state),
            _eventRow(duskLabel, events.evening, events.state),
          ],
        ),
      ),
    );
  }

  Widget _lunarEventRow(
    String label,
    LunarEvent? event,
    LunarCrossingState state,
  ) {
    final value = event == null
        ? switch (state) {
            LunarCrossingState.alwaysAbove => 'Moon stays above horizon',
            LunarCrossingState.alwaysBelow => 'Moon stays below horizon',
            LunarCrossingState.crossings => 'No crossing in this night',
          }
        : SolarEvents.formatLocal(event.local, includeDate: true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 135, child: AppText(label)),
          Expanded(child: AppText(value)),
        ],
      ),
    );
  }

  Widget _results(ObservingLocation location, DateTime date) {
    final day = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: date,
    );
    final moonEvents = LunarEphemeris.calculateForObservingNight(
      location: location,
      localDate: date,
    );
    final zone = SolarEvents.timeZone(location.timeZone);
    // Local midnight belonging to the observation night, never the device zone.
    final localMidnight = tz.TZDateTime(
      zone,
      date.year,
      date.month,
      date.day + 1,
    );
    final moon = LunarEphemeris.positionAt(
      at: localMidnight.toUtc(),
      observer: ObserverPosition(
        latitudeDegrees: location.latitude,
        longitudeDegrees: location.longitude,
        elevationMeters: location.elevationMeters,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        NightPlanningSection(
          location: location,
          day: day,
          initialProjectId: widget.initialProjectId,
          initialTargetId: widget.initialTargetId,
        ),
        const SizedBox(height: 16),
        AppText('Solar events', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        AppText(
          'Local time: ${location.timeZone} · '
          'Civil day: ${day.civilDayLength.inHours} h',
        ),
        const SizedBox(height: 12),
        _thresholdCard(
          day,
          SolarThreshold.horizon,
          'Sunrise / sunset (−0.8333°)',
          'Sunrise',
          'Sunset',
        ),
        _thresholdCard(
          day,
          SolarThreshold.civil,
          'Civil twilight (−6°)',
          'Civil dawn',
          'Civil dusk',
        ),
        _thresholdCard(
          day,
          SolarThreshold.nautical,
          'Nautical twilight (−12°)',
          'Nautical dawn',
          'Nautical dusk',
        ),
        _thresholdCard(
          day,
          SolarThreshold.astronomical,
          'Astronomical twilight (−18°)',
          'Astronomical dawn',
          'Astronomical dusk',
        ),
        const SizedBox(height: 20),
        AppText(
          'Lunar conditions · observing night',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        AppText(
          'Moon position at ${SolarEvents.formatLocal(localMidnight, includeDate: true)}',
        ),
        const SizedBox(height: 10),
        Card(
          key: const ValueKey('planner-lunar-conditions'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Moon phase: ${moon.phase.label}'),
                const SizedBox(height: 6),
                AppText(
                  'Illumination: ${(moon.illuminationFraction * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 6),
                AppText(
                  'Moon altitude: ${moon.horizontal.altitudeDegrees.toStringAsFixed(1)}°',
                ),
                const SizedBox(height: 6),
                AppText(
                  moon.horizontal.azimuthDegrees == null
                      ? 'Moon azimuth: undefined'
                      : 'Moon azimuth: ${moon.horizontal.azimuthDegrees!.toStringAsFixed(1)}°',
                ),
                const SizedBox(height: 6),
                AppText(
                  'Distance: ${moon.distanceKilometers.toStringAsFixed(0)} km',
                ),
                const Divider(height: 22),
                const AppText('Moonrise / moonset · noon-to-noon window'),
                const SizedBox(height: 8),
                _lunarEventRow(
                  'Moonrise',
                  moonEvents.moonrise,
                  moonEvents.state,
                ),
                _lunarEventRow('Moonset', moonEvents.moonset, moonEvents.state),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppText(
          'Solar positions are approximate. Sunrise/sunset assumes an '
          'unobstructed sea-level horizon and standard refraction. '
          'Mountain ridges, weather and artificial light are not included.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _locations(List<ObservingLocation> locations) {
    if (locations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: AppText(
            'Add an observing location in Settings to plan a night.',
          ),
        ),
      );
    }

    final selected = locations.where(
      (location) => location.id == _selectedLocationId,
    );
    final current = selected.isNotEmpty
        ? selected.first
        : locations.firstWhere(
            (location) => location.isDefault,
            orElse: () => locations.first,
          );

    final nowAtSite = tz.TZDateTime.now(SolarEvents.timeZone(current.timeZone));
    final today = DateTime(nowAtSite.year, nowAtSite.month, nowAtSite.day);
    final date = _selectedDate ?? today;
    final siteControl = DropdownButtonFormField<String>(
      key: ValueKey('planner-site-${current.id}'),
      initialValue: current.id,
      isExpanded: true,
      decoration: localizeDecoration(
        context,
        const InputDecoration(
          labelText: 'Observing location',
          prefixIcon: Icon(Icons.place_outlined),
        ),
      ),
      items: [
        for (final location in locations)
          DropdownMenuItem(value: location.id, child: AppText(location.name)),
      ],
      onChanged: (value) => setState(() => _selectedLocationId = value),
    );
    final dateControls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('planner-date'),
          onPressed: () => _pickDate(date, today),
          icon: const Icon(Icons.calendar_month),
          label: Text(MaterialLocalizations.of(context).formatFullDate(date)),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedDate = null),
          child: const AppText('Today'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 650
              ? Row(
                  children: [
                    Expanded(child: siteControl),
                    const SizedBox(width: 16),
                    Expanded(child: dateControls),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    siteControl,
                    const SizedBox(height: 8),
                    dateControls,
                  ],
                ),
        ),
        _results(current, date),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(observingLocationsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Night Planner',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                locations.when(
                  loading: () =>
                      const AppText('Loading observing locations...'),
                  error: (error, stackTrace) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('Unable to load observing locations: $error'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(observingLocationsProvider),
                        child: const AppText('Retry'),
                      ),
                    ],
                  ),
                  data: _locations,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
