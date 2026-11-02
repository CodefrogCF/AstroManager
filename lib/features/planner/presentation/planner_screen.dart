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
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _date = DateTime.now();
  String? _selectedLocationId;

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (!mounted || selected == null) return;
    setState(() => _date = selected);
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

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
          SizedBox(width: 155, child: Text(label)),
          Expanded(child: Text(value)),
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
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
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
          SizedBox(width: 135, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _results(ObservingLocation location) {
    final day = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: _date,
    );
    final darkness = day.astronomicalDarkness;
    final moonEvents = LunarEphemeris.calculateForObservingNight(
      location: location,
      localDate: _date,
    );
    final zone = SolarEvents.timeZone(location.timeZone);
    // Local midnight belonging to the observation night, never the device zone.
    final localMidnight = tz.TZDateTime(
      zone,
      _date.year,
      _date.month,
      _date.day + 1,
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
        Text(
          'Solar events · ${_dateText(day.localDate)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Local time: ${location.timeZone} · '
          'Civil day: ${day.civilDayLength.inHours} h',
        ),
        const SizedBox(height: 12),
        NightPlanningSection(location: location, date: _date),
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
        const SizedBox(height: 16),
        Text(
          'Astronomical darkness · observing night',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Sun below −18°; evaluated from local noon through the following '
          'local noon. Intervals can span midnight.',
        ),
        const SizedBox(height: 10),
        if (darkness.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No astronomical darkness during this night.'),
            ),
          ),
        for (final interval in darkness)
          Card(
            key: ValueKey('darkness-${interval.startUtc.toIso8601String()}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${SolarEvents.formatLocal(interval.startLocal, includeDate: true)} '
                    '– ${SolarEvents.formatLocal(interval.endLocal, includeDate: true)}',
                  ),
                  const SizedBox(height: 4),
                  Text('Duration: ${interval.duration.inMinutes} minutes'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Lunar conditions · observing night',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
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
                Text('Moon phase: ${moon.phase.label}'),
                const SizedBox(height: 6),
                Text(
                  'Illumination: ${(moon.illuminationFraction * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 6),
                Text(
                  'Moon altitude: ${moon.horizontal.altitudeDegrees.toStringAsFixed(1)}°',
                ),
                const SizedBox(height: 6),
                Text(
                  moon.horizontal.azimuthDegrees == null
                      ? 'Moon azimuth: undefined'
                      : 'Moon azimuth: ${moon.horizontal.azimuthDegrees!.toStringAsFixed(1)}°',
                ),
                const SizedBox(height: 6),
                Text(
                  'Distance: ${moon.distanceKilometers.toStringAsFixed(0)} km',
                ),
                const Divider(height: 22),
                const Text('Moonrise / moonset · noon-to-noon window'),
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
        Text(
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
          child: Text('Add an observing location in Settings to plan a night.'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('planner-site-${current.id}'),
          initialValue: current.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Observing location',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          items: [
            for (final location in locations)
              DropdownMenuItem(value: location.id, child: Text(location.name)),
          ],
          onChanged: (value) => setState(() => _selectedLocationId = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('planner-date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(_dateText(_date)),
            ),
            TextButton(
              onPressed: () => setState(() => _date = DateTime.now()),
              child: const Text('Today'),
            ),
          ],
        ),
        _results(current),
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
                Text(
                  'Night Planner',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Plan your upcoming astrophotography sessions.'),
                const SizedBox(height: 20),
                locations.when(
                  loading: () => const Text('Loading observing locations...'),
                  error: (error, stackTrace) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unable to load observing locations: $error'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(observingLocationsProvider),
                        child: const Text('Retry'),
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
