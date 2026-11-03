import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_text.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../locations/presentation/locations_screen.dart';
import '../../settings/application/app_preferences_controller.dart';
import '../../settings/domain/models/app_preferences.dart';

/// First-run setup is optional and never requests a permission automatically.
/// A completed or skipped guide is stored in the existing offline preferences.
class OnboardingDialog extends ConsumerStatefulWidget {
  const OnboardingDialog({super.key});

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  int _step = 0;
  bool _saving = false;
  String? _error;

  Future<void> _complete({bool openEquipment = false}) async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(appPreferencesProvider.notifier).completeOnboarding();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      if (openEquipment) {
        context.go('/equipment');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the setup preference.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addLocation() async {
    final input = await showDialog<ObservingLocationInput>(
      context: context,
      builder: (_) => const LocationEditorDialog(),
    );
    if (input == null || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final locationsController = ref.read(observingLocationsProvider.notifier);
      await locationsController.save(input);
      // The existing default, if any, remains unchanged.
      final locations = ref.read(observingLocationsProvider).value ?? [];
      if (locations.length == 1) {
        await locationsController.setDefault(locations.first.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save observing location.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _stepBody(BuildContext context) {
    final theme = Theme.of(context);
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'Your data stays on this device. No account or registration is required.',
            ),
            const SizedBox(height: 16),
            const AppText('Choose your language'),
            const SizedBox(height: 8),
            DropdownButtonFormField<LanguagePreference>(
              key: const ValueKey('onboarding-language'),
              initialValue:
                  ref.watch(appPreferencesProvider).value?.language ??
                  LanguagePreference.system,
              decoration: InputDecoration(
                labelText: appTranslate(context, 'Language'),
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: LanguagePreference.system,
                  child: AppText('System default'),
                ),
                DropdownMenuItem(
                  value: LanguagePreference.english,
                  child: AppText('English'),
                ),
                DropdownMenuItem(
                  value: LanguagePreference.german,
                  child: AppText('German'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (language) async {
                      if (language == null) {
                        return;
                      }
                      try {
                        await ref
                            .read(appPreferencesProvider.notifier)
                            .setLanguage(language);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () =>
                                _error = 'Unable to save language preference.',
                          );
                        }
                      }
                    },
            ),
          ],
        );
      case 1:
        final locationCount =
            ref.watch(observingLocationsProvider).value?.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'Create an observing site so local sky calculations use accurate coordinates and time zones.',
            ),
            const SizedBox(height: 12),
            AppText(
              'Location permission is optional',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const AppText(
              'You can enter coordinates manually. Location permission is requested only if you choose to use device positioning.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('onboarding-add-location'),
              onPressed: _saving ? null : _addLocation,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const AppText('Add observing location'),
            ),
            if (locationCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppText('$locationCount observing location(s) saved'),
              ),
          ],
        );
      case 2:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'Add a camera, optics and mount later in Equipment to calculate accurate framing and mosaics.',
            ),
            SizedBox(height: 16),
            AppText('You can change all settings later.'),
          ],
        );
      default:
        return const AppText('You can change all settings later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Welcome to AstroManager',
      1 => 'Observing location',
      _ => 'Optional equipment',
    };
    return AlertDialog(
      title: AppText(title),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: Localizations.localeOf(context).languageCode == 'de'
                    ? 'Einrichtung Schritt ${_step + 1} von 3'
                    : 'Setup step ${_step + 1} of 3',
                child: LinearProgressIndicator(value: (_step + 1) / 3),
              ),
              const SizedBox(height: 16),
              _stepBody(context),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('onboarding-skip'),
          onPressed: _saving ? null : () => _complete(),
          child: const AppText('Skip'),
        ),
        if (_step > 0)
          TextButton(
            onPressed: _saving ? null : () => setState(() => _step--),
            child: const AppText('Previous'),
          ),
        if (_step < 2)
          FilledButton(
            key: const ValueKey('onboarding-next'),
            onPressed: _saving ? null : () => setState(() => _step++),
            child: const AppText('Next'),
          )
        else ...[
          OutlinedButton(
            onPressed: _saving ? null : () => _complete(openEquipment: true),
            child: const AppText('Set up equipment'),
          ),
          FilledButton(
            key: const ValueKey('onboarding-finish'),
            onPressed: _saving ? null : () => _complete(),
            child: const AppText('Finish'),
          ),
        ],
      ],
    );
  }
}

Future<void> showAstroOnboarding(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const OnboardingDialog(),
);
