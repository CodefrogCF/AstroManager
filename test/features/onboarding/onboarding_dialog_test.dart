import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:astromanager/features/dashboard/presentation/dashboard_screen.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/features/settings/domain/models/app_preferences.dart';
import 'package:astromanager/l10n/app_text.dart';
import 'package:astromanager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_preferences_repository.dart';

void main() {
  testWidgets('German UI labels follow the requested locale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: AppText('Observing Locations')),
      ),
    );
    expect(find.text('Beobachtungsorte'), findsOneWidget);
    expect(find.text('Observing Locations'), findsNothing);
  });

  testWidgets('labels remain readable with enlarged system text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AppText('Observing Locations'),
          ),
        ),
      ),
    );
    expect(find.text('Beobachtungsorte'), findsOneWidget);
    expect(
      tester.getSize(find.text('Beobachtungsorte')).height,
      greaterThan(25),
    );
  });

  testWidgets('first run can be completed without account or permission', (
    tester,
  ) async {
    final repository = FakeAppPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardLayoutRepositoryProvider.overrideWithValue(
            MemoryDashboardLayoutRepository(),
          ),
          appPreferencesRepositoryProvider.overrideWithValue(repository),
          observingLocationsProvider.overrideWithBuild((ref, notifier) => []),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-onboarding')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-onboarding')));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Location permission is optional'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(repository.preferences.onboardingCompleted, isTrue);
    expect(find.byKey(const ValueKey('start-onboarding')), findsNothing);
  });

  testWidgets('choosing German persists to existing preferences', (
    tester,
  ) async {
    final repository = FakeAppPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardLayoutRepositoryProvider.overrideWithValue(
            MemoryDashboardLayoutRepository(),
          ),
          appPreferencesRepositoryProvider.overrideWithValue(repository),
          observingLocationsProvider.overrideWithBuild((ref, notifier) => []),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-onboarding')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('German').last);
    await tester.pumpAndSettle();
    expect(repository.preferences.language, LanguagePreference.german);
  });
}
