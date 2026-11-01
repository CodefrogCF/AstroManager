import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_message.dart';
import '../../application/app_preferences_controller.dart';
import '../../domain/models/app_preferences.dart';

class AppPreferencesSection extends ConsumerWidget {
  const AppPreferencesSection({super.key});

  Future<void> _execute(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Application preferences', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Configure measurement units and time display.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),

        preferences.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appErrorMessage(error),
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ref.invalidate(appPreferencesProvider);
                    },
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => _execute(
                      context,
                      () => ref
                          .read(appPreferencesProvider.notifier)
                          .restoreDefaults(),
                    ),
                    child: const Text('Restore defaults'),
                  ),
                ],
              ),
            ],
          ),
          data: (values) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<MeasurementUnits>(
                key: ValueKey('units-${values.units.name}'),
                initialValue: values.units,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Measurement units',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MeasurementUnits.metric,
                    child: Text('Metric (km, m, °C)'),
                  ),
                  DropdownMenuItem(
                    value: MeasurementUnits.imperial,
                    child: Text('Imperial (mi, ft, °F)'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;

                  await _execute(
                    context,
                    () => ref
                        .read(appPreferencesProvider.notifier)
                        .setUnits(value),
                  );
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<ClockFormat>(
                key: ValueKey('clock-${values.clockFormat.name}'),
                initialValue: values.clockFormat,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Time format',
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ClockFormat.system,
                    child: Text('Follow system'),
                  ),
                  DropdownMenuItem(
                    value: ClockFormat.hour24,
                    child: Text('24-hour clock'),
                  ),
                  DropdownMenuItem(
                    value: ClockFormat.hour12,
                    child: Text('12-hour clock (AM/PM)'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;

                  await _execute(
                    context,
                    () => ref
                        .read(appPreferencesProvider.notifier)
                        .setClockFormat(value),
                  );
                },
              ),

              const SizedBox(height: 20),

              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.language),
                title: Text('Language'),
                subtitle: Text(
                  'System default - full localization '
                  'planned for v1.0.0.',
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () => _execute(
                  context,
                  () => ref
                      .read(appPreferencesProvider.notifier)
                      .restoreDefaults(),
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restore defaults'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
