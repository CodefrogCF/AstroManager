import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/astronomy/solar_events.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';

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

  Widget _results(ObservingLocation location) {
    final day = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: _date,
    );
    final darkness = day.astronomicalDarkness;

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
