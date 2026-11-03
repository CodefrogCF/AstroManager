import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_text.dart';
import '../../../shared/widgets/feature_placeholder.dart';
import '../../onboarding/presentation/onboarding_dialog.dart';
import '../../settings/application/app_preferences_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final needsSetup = prefs.value != null && !prefs.value!.onboardingCompleted;
    return ListView(
      children: [
        const SizedBox(height: 28),
        const FeaturePlaceholder(
          title: 'Welcome to AstroManager',
          description: 'Your astrophotography planning dashboard.',
        ),
        if (needsSetup)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppText('No account required'),
                        const SizedBox(height: 8),
                        const AppText(
                          'Your data stays on this device. No account or registration is required.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton(
                              key: const ValueKey('start-onboarding'),
                              onPressed: () => showAstroOnboarding(context),
                              child: const AppText('Get started'),
                            ),
                            TextButton(
                              key: const ValueKey('skip-onboarding'),
                              onPressed: () => ref
                                  .read(appPreferencesProvider.notifier)
                                  .completeOnboarding(),
                              child: const AppText('Set up later'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
