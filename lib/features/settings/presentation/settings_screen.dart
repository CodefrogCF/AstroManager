import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'widgets/app_preferences_section.dart';

import '../../../core/database/database_diagnostics_tile.dart';
import '../../../app/theme/app_theme_choice.dart';
import '../../../app/theme/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  IconData _iconFor(AppThemeChoice choice) {
    return switch (choice) {
      AppThemeChoice.system => Icons.brightness_auto,
      AppThemeChoice.light => Icons.light_mode_outlined,
      AppThemeChoice.dark => Icons.dark_mode_outlined,
      AppThemeChoice.night => Icons.nights_stay_outlined,
    };
  }

  Future<void> _selectTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemeChoice choice,
  ) async {
    try {
      await ref.read(appThemeProvider.notifier).select(choice);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save theme preference.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(appThemeProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Choose how AstroManager looks. '
                  'Astronomy night mode is designed for '
                  'use during observing sessions.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                for (final choice in AppThemeChoice.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        key: ValueKey('theme-${choice.name}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Icon(_iconFor(choice)),
                        title: Text(choice.label),
                        subtitle: Text(choice.description),
                        selected: selectedTheme == choice,
                        trailing: selectedTheme == choice
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.circle_outlined),
                        onTap: () => _selectTheme(context, ref, choice),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                Text(
                  'The selected appearance is saved '
                  'automatically and restored at startup.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                const AppPreferencesSection(),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  const DatabaseDiagnosticsTile(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
