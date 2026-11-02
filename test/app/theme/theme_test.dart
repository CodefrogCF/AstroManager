import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/app/app.dart';
import 'package:astromanager/app/theme/app_theme_choice.dart';
import 'package:astromanager/app/theme/app_themes.dart';
import 'package:astromanager/app/theme/theme_controller.dart';
import 'package:astromanager/app/theme/theme_repository.dart';
import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/features/alerts/data/observation_alert_store.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';

import '../../support/fake_app_preferences_repository.dart';

class FakeThemeRepository implements ThemeRepository {
  AppThemeChoice saved = AppThemeChoice.dark;

  @override
  Future<AppThemeChoice> load() async => saved;

  @override
  Future<void> save(AppThemeChoice choice) async {
    saved = choice;
  }
}

void main() {
  test('Default theme is Codefrog dark', () {
    final container = ProviderContainer.test();

    expect(container.read(appThemeProvider), AppThemeChoice.dark);
  });

  test('Theme selection is persisted', () async {
    final repository = FakeThemeRepository();

    final container = ProviderContainer.test(
      overrides: [themeRepositoryProvider.overrideWithValue(repository)],
    );

    await container
        .read(appThemeProvider.notifier)
        .select(AppThemeChoice.night);

    expect(container.read(appThemeProvider), AppThemeChoice.night);

    expect(repository.saved, AppThemeChoice.night);
  });

  testWidgets('Settings can switch to astronomy night mode', (tester) async {
    final repository = FakeThemeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeRepositoryProvider.overrideWithValue(repository),
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
          // Settings also builds the alert section. Avoid accessing the real
          // database during a theme-only widget test.
          observationAlertStoreProvider.overrideWithValue(
            MemoryObservationAlertStore(),
          ),
          observingLocationsProvider.overrideWithBuild((ref, notifier) => []),
        ],
        child: const AstroManagerApp(initialLocation: '/settings'),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Astronomy night'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Appearance'));

    final activeTheme = Theme.of(context);

    expect(activeTheme.brightness, Brightness.dark);

    expect(activeTheme.colorScheme.primary, AstroPalette.nightAccent);

    expect(repository.saved, AppThemeChoice.night);
  });

  testWidgets('Switching back restores Codefrog colors', (tester) async {
    final repository = FakeThemeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeRepositoryProvider.overrideWithValue(repository),
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
          // Settings also builds the alert section. Avoid accessing the real
          // database during a theme-only widget test.
          observationAlertStoreProvider.overrideWithValue(
            MemoryObservationAlertStore(),
          ),
          observingLocationsProvider.overrideWithBuild((ref, notifier) => []),
        ],
        child: const AstroManagerApp(initialLocation: '/settings'),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Astronomy night'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Codefrog dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Appearance'));

    expect(Theme.of(context).colorScheme.primary, AstroPalette.darkAccent);

    expect(repository.saved, AppThemeChoice.dark);
  });
}
