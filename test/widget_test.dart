import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/app/app.dart';

import 'support/fake_app_preferences_repository.dart';

void setTestSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Application starts on Dashboard', (tester) async {
    setTestSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
        ],
        child: const AstroManagerApp(initialLocation: '/dashboard'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to AstroManager'), findsOneWidget);

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Mobile navigation switches sections', (tester) async {
    setTestSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
        ],
        child: const AstroManagerApp(initialLocation: '/dashboard'),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.travel_explore_outlined));

    await tester.pumpAndSettle();

    expect(find.text('Find suitable celestial targets.'), findsOneWidget);
  });

  testWidgets('Settings opens and returns to previous section', (tester) async {
    setTestSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
        ],
        child: const AstroManagerApp(initialLocation: '/dashboard'),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Targets.
    await tester.tap(find.byIcon(Icons.travel_explore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Find suitable celestial targets.'), findsOneWidget);

    // Open Settings.
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();

    // Verify the new settings interface.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Astronomy night'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Return to the previous navigation section.
    await tester.tap(find.byTooltip('Back to previous section'));
    await tester.pumpAndSettle();

    expect(find.text('Find suitable celestial targets.'), findsOneWidget);
  });

  testWidgets('Desktop uses NavigationRail', (tester) async {
    setTestSize(tester, const Size(1300, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
        ],
        child: const AstroManagerApp(initialLocation: '/dashboard'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));

    await tester.pumpAndSettle();

    expect(
      find.text('Plan your upcoming astrophotography sessions.'),
      findsOneWidget,
    );
  });

  testWidgets('Direct route opens Projects', (tester) async {
    setTestSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
        ],
        child: const AstroManagerApp(initialLocation: '/projects'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Astrophotography Projects'), findsOneWidget);
  });
}
