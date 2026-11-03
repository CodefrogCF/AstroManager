import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_message.dart';
import '../application/observing_locations_controller.dart';
import '../domain/models/observing_location.dart';
import '../domain/models/iana_time_zones.dart';
import '../../light_pollution/presentation/light_pollution_location_panel.dart';
import '../../site_comparison/presentation/observing_site_comparison_panel.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    ObservingLocation? location,
  }) async {
    final input = await showDialog<ObservingLocationInput>(
      context: context,
      builder: (context) => LocationEditorDialog(location: location),
    );

    if (input == null || !context.mounted) return;

    await _execute(
      context,
      () => ref
          .read(observingLocationsProvider.notifier)
          .save(input, id: location?.id),
      successMessage: location == null
          ? 'Observing location created.'
          : 'Observing location updated.',
    );
  }

  Future<void> _execute(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();

      if (!context.mounted) return;

      if (successMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(successMessage)));
      }
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(appErrorMessage(error))));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ObservingLocation location,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete observing location?'),
        content: AppText(
          'Delete "${location.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _execute(
      context,
      () => ref.read(observingLocationsProvider.notifier).delete(location.id),
      successMessage: 'Observing location deleted.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(observingLocationsProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/settings');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const AppText('Back to Settings'),
                ),

                const SizedBox(height: 12),

                AppText(
                  'Observing Locations',
                  style: theme.textTheme.headlineMedium,
                ),

                const SizedBox(height: 8),

                AppText(
                  'Manage observing sites used for '
                  'astronomical calculations, weather '
                  'forecasts and imaging recommendations.',
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: () => _showEditor(context, ref),
                  icon: const Icon(Icons.add_location_alt),
                  label: const AppText('Add location'),
                ),

                const SizedBox(height: 24),

                locations.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),

                  error: (error, stackTrace) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        appErrorMessage(error),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.invalidate(observingLocationsProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const AppText('Retry'),
                      ),
                    ],
                  ),

                  data: (savedLocations) {
                    if (savedLocations.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 44,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              const AppText('No observing locations yet.'),
                              const SizedBox(height: 8),
                              const AppText(
                                'Add your first observing '
                                'location to get started.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (savedLocations.length >= 2) ...[
                          ObservingSiteComparisonPanel(sites: savedLocations),
                          const SizedBox(height: 14),
                        ],
                        for (final location in savedLocations)
                          Card(
                            key: ValueKey('location-${location.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      location.isDefault
                                          ? Icons.my_location
                                          : Icons.place_outlined,
                                      color: location.isDefault
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                    title: AppText(location.name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          '${location.latitude.toStringAsFixed(6)}°, '
                                          '${location.longitude.toStringAsFixed(6)}°',
                                        ),
                                        AppText(
                                          '${location.elevationMeters.toStringAsFixed(1)} m • '
                                          '${location.timeZone}',
                                        ),
                                        if (location.isDefault)
                                          AppText(
                                            'Default observing location',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Wrap(
                                      spacing: 0,
                                      children: [
                                        if (!location.isDefault)
                                          IconButton(
                                            tooltip: appTranslate(
                                              context,
                                              'Set as default',
                                            ),
                                            icon: const Icon(
                                              Icons.star_outline,
                                            ),
                                            onPressed: () => _execute(
                                              context,
                                              () => ref
                                                  .read(
                                                    observingLocationsProvider
                                                        .notifier,
                                                  )
                                                  .setDefault(location.id),
                                            ),
                                          ),
                                        IconButton(
                                          tooltip: appTranslate(
                                            context,
                                            'Edit location',
                                          ),
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _showEditor(
                                            context,
                                            ref,
                                            location: location,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: appTranslate(
                                            context,
                                            'Delete location',
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () => _confirmDelete(
                                            context,
                                            ref,
                                            location,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  LightPollutionLocationPanel(
                                    key: ValueKey(
                                      'light-pollution-${location.id}',
                                    ),
                                    site: location,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog used for both creating and editing observing locations.
class LocationEditorDialog extends ConsumerStatefulWidget {
  const LocationEditorDialog({this.location, super.key});

  final ObservingLocation? location;

  @override
  ConsumerState<LocationEditorDialog> createState() =>
      _LocationEditorDialogState();
}

class _LocationEditorDialogState extends ConsumerState<LocationEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _elevationController;
  late String _selectedTimeZone;
  late final TextEditingController _timeZoneSearchController;

  bool _locating = false;

  @override
  void initState() {
    super.initState();

    final location = widget.location;

    _nameController = TextEditingController(text: location?.name ?? '');

    _latitudeController = TextEditingController(
      text: location?.latitude.toString() ?? '',
    );

    _longitudeController = TextEditingController(
      text: location?.longitude.toString() ?? '',
    );

    _elevationController = TextEditingController(
      text: location?.elevationMeters.toString() ?? '0',
    );

    _selectedTimeZone = location?.timeZone ?? 'Etc/UTC';
    _timeZoneSearchController = TextEditingController(text: _selectedTimeZone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _elevationController.dispose();
    _timeZoneSearchController.dispose();
    super.dispose();
  }

  double? _parseNumber(String raw) {
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  String? _validateNumber(String? raw, double min, double max) {
    final value = _parseNumber(raw ?? '');

    if (value == null || !value.isFinite) {
      return 'Enter a valid number.';
    }

    if (value < min || value > max) {
      return 'Allowed range: $min to $max';
    }

    return null;
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
    });

    try {
      final coordinates = await ref
          .read(deviceLocationServiceProvider)
          .getCurrentCoordinates();

      if (!mounted) return;

      _latitudeController.text = coordinates.latitude.toStringAsFixed(6);

      _longitudeController.text = coordinates.longitude.toStringAsFixed(6);

      final elevation = coordinates.elevationMeters;

      if (elevation.isFinite && elevation >= -500 && elevation <= 10000) {
        _elevationController.text = elevation.toStringAsFixed(1);
      }

      // GPS does not reliably provide an IANA time zone.
      // The user must verify the time zone separately.
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(appErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  void _save() {
    // Filtering the menu is not a selection. Never persist a typed value or
    // silently use an old selection while different filter text is visible.
    if (_timeZoneSearchController.text.trim() != _selectedTimeZone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Select a time zone from the list.')),
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final input = ObservingLocationInput(
      name: _nameController.text,
      latitude: _parseNumber(_latitudeController.text)!,
      longitude: _parseNumber(_longitudeController.text)!,
      elevationMeters: _parseNumber(_elevationController.text)!,
      timeZone: _selectedTimeZone,
    );

    try {
      input.validate();

      Navigator.of(context).pop(input);
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(appErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    const numberKeyboard = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    return AlertDialog(
      title: AppText(
        widget.location == null
            ? 'Add observing location'
            : 'Edit observing location',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('location-name'),
                  controller: _nameController,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(
                      labelText: 'Location name',
                      hintText: 'e.g. Home Observatory',
                    ),
                  ),
                  maxLength: 100,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a location name.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  key: const ValueKey('location-latitude'),
                  controller: _latitudeController,
                  keyboardType: numberKeyboard,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(
                      labelText: 'Latitude (degrees)',
                      hintText: 'e.g. 47.480000',
                    ),
                  ),
                  validator: (value) => _validateNumber(value, -90, 90),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  key: const ValueKey('location-longitude'),
                  controller: _longitudeController,
                  keyboardType: numberKeyboard,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(
                      labelText: 'Longitude (degrees)',
                      hintText: 'e.g. 8.210000',
                    ),
                  ),
                  validator: (value) => _validateNumber(value, -180, 180),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  key: const ValueKey('location-elevation'),
                  controller: _elevationController,
                  keyboardType: numberKeyboard,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(labelText: 'Elevation (meters)'),
                  ),
                  validator: (value) => _validateNumber(value, -500, 10000),
                ),

                const SizedBox(height: 12),

                // Filterable selection, not free text: a valid IANA identifier
                // must be picked from the same database used by validation.
                DropdownMenu<String>(
                  key: const ValueKey('location-timezone'),
                  initialSelection: _selectedTimeZone,
                  controller: _timeZoneSearchController,
                  label: AppText('IANA time zone'),
                  helperText: appTranslate(
                    context,
                    'Use the time zone of the observing site.',
                  ),
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  menuHeight: 300,
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    for (final identifier in IanaTimeZones.all)
                      DropdownMenuEntry<String>(
                        value: identifier,
                        label: identifier,
                      ),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      setState(() => _selectedTimeZone = value);
                    }
                  },
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const AppText('Use current location'),
                ),

                const SizedBox(height: 8),

                const AppText(
                  'GPS coordinates and elevation may be '
                  'approximate. Verify the time zone manually.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const AppText('Save')),
      ],
    );
  }
}
