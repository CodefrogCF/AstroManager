import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../../core/astronomy/lunar_ephemeris.dart';

import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';

import '../domain/models/celestial_object.dart';

class TargetCoordinatesPanel extends ConsumerStatefulWidget {
  const TargetCoordinatesPanel({super.key, required this.object});

  final CelestialObject object;

  @override
  ConsumerState<TargetCoordinatesPanel> createState() =>
      _TargetCoordinatesPanelState();
}

class _TargetCoordinatesPanelState
    extends ConsumerState<TargetCoordinatesPanel> {
  late final Future<List<ObservingLocation>> _locations;

  DateTime _utc = DateTime.now().toUtc();
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();

    _locations = ref.read(observingLocationRepositoryProvider).getAll();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _utc,
      firstDate: DateTime.utc(1900),
      lastDate: DateTime.utc(2100),
      helpText: 'Select UTC date',
    );

    if (!mounted || selected == null) return;

    setState(() {
      _utc = DateTime.utc(
        selected.year,
        selected.month,
        selected.day,
        _utc.hour,
        _utc.minute,
      );
    });
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _utc.hour, minute: _utc.minute),
      helpText: 'Select UTC time',
    );

    if (!mounted || selected == null) return;

    setState(() {
      _utc = DateTime.utc(
        _utc.year,
        _utc.month,
        _utc.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  void _useCurrentTime() {
    setState(() {
      _utc = DateTime.now().toUtc();
    });
  }

  String _formattedUtc(DateTime date) {
    final iso = date.toUtc().toIso8601String();
    return '${iso.substring(0, 16).replaceFirst('T', ' ')} UTC';
  }

  String _angle(double value, {int digits = 2}) {
    return '${value.toStringAsFixed(digits)}°';
  }

  String _siderealTime(double degrees) {
    final totalHours = degrees / 15;
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).floor();

    return '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }

  Widget _valueTile(String title, String value, {String? subtitle}) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null)
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _calculatedValues(ObservingLocation location) {
    final object = widget.object;

    final result = AstronomicalCoordinates.calculateJ2000(
      j2000: EquatorialPosition(
        raDegrees: object.raDegrees,
        decDegrees: object.decDegrees,
      ),
      observer: ObserverPosition(
        latitudeDegrees: location.latitude,
        longitudeDegrees: location.longitude,
        elevationMeters: location.elevationMeters.toDouble(),
      ),
      time: _utc,
    );

    final altitude = result.horizontal.altitudeDegrees;
    final azimuth = result.horizontal.azimuthDegrees;
    final airmass = result.horizontal.relativeAirmass;
    final lunar = LunarEphemeris.conditionsForTarget(
      at: _utc,
      observer: ObserverPosition(
        latitudeDegrees: location.latitude,
        longitudeDegrees: location.longitude,
        elevationMeters: location.elevationMeters,
      ),
      targetJ2000: EquatorialPosition(
        raDegrees: object.raDegrees,
        decDegrees: object.decDegrees,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        Text(
          'Calculated position',
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 16,
          runSpacing: 20,
          children: [
            _valueTile(
              'Altitude',
              _angle(altitude),
              subtitle: altitude > 0 ? 'Above horizon' : 'At or below horizon',
            ),
            _valueTile(
              'Azimuth',
              azimuth == null ? 'Undefined' : _angle(azimuth),
              subtitle: '0° N · 90° E',
            ),
            _valueTile(
              'Airmass',
              airmass == null ? '—' : '${airmass.toStringAsFixed(2)}×',
            ),
            _valueTile(
              'Zenith distance',
              _angle(result.horizontal.zenithDistanceDegrees),
            ),
            _valueTile('Hour angle', _angle(result.hourAngleDegrees)),
            _valueTile(
              'Local sidereal time',
              _siderealTime(result.localSiderealDegrees),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        Text(
          'Mean equatorial coordinates of date',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _valueTile(
              'RA',
              _angle(result.meanEquatorialOfDate.raDegrees, digits: 4),
            ),
            _valueTile(
              'Dec',
              _angle(result.meanEquatorialOfDate.decDegrees, digits: 4),
            ),
            _valueTile('Julian Date', result.julianDate.toStringAsFixed(5)),
            _valueTile(
              'Greenwich sidereal',
              _siderealTime(result.greenwichSiderealDegrees),
            ),
          ],
        ),

        const SizedBox(height: 16),

        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Moonlight conditions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          key: const ValueKey('moon-target-separation'),
          spacing: 16,
          runSpacing: 16,
          children: [
            _valueTile(
              'Moon–target separation',
              _angle(lunar.targetSeparationDegrees),
            ),
            _valueTile(
              'Moon illumination',
              '${(lunar.moon.illuminationFraction * 100).toStringAsFixed(1)}%',
            ),
            _valueTile('Moon phase', lunar.moon.phase.label),
            _valueTile(
              'Moon altitude',
              _angle(lunar.moon.horizontal.altitudeDegrees),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Angular separation includes lunar topocentric parallax. '
          'Brightness and skyglow depend on atmospheric conditions; '
          'separation alone is not a suitability rating.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text(
          'Geometric position using mean sidereal time. '
          'Atmospheric refraction, local obstructions, '
          'nutation and proper motion are not included.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ObservingLocation>>(
      future: _locations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load observing locations: '
            '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }

        final locations = snapshot.data!;

        if (locations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Add an observing location in Settings '
              'to calculate altitude and azimuth.',
            ),
          );
        }

        var location = locations.firstWhere(
          (entry) => entry.isDefault,
          orElse: () => locations.first,
        );

        for (final entry in locations) {
          if (entry.id == _selectedLocationId) {
            location = entry;
            break;
          }
        }

        return Column(
          key: const ValueKey('target-coordinates-panel'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Observing coordinates',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey('coordinate-location-${location.id}'),
              initialValue: location.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Observing location',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: [
                for (final entry in locations)
                  DropdownMenuItem(value: entry.id, child: Text(entry.name)),
              ],
              onChanged: (id) {
                setState(() {
                  _selectedLocationId = id;
                });
              },
            ),

            const SizedBox(height: 8),

            Text(
              '${location.latitude.toStringAsFixed(4)}° '
              'latitude · '
              '${location.longitude.toStringAsFixed(4)}° '
              'longitude · ${location.timeZone}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 16),

            Text(
              _formattedUtc(_utc),
              style: Theme.of(context).textTheme.titleSmall,
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('UTC date'),
                ),
                OutlinedButton.icon(
                  onPressed: _chooseTime,
                  icon: const Icon(Icons.schedule),
                  label: const Text('UTC time'),
                ),
                TextButton.icon(
                  onPressed: _useCurrentTime,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Now'),
                ),
              ],
            ),

            _calculatedValues(location),
          ],
        );
      },
    );
  }
}
