import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:astromanager/app/app.dart';
import 'package:astromanager/app/router/app_router.dart';

import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/features/settings/presentation/settings_screen.dart';
import 'package:astromanager/features/targets/presentation/targets_screen.dart';

import 'support/catalog_navigation_test_override.dart';
import 'support/fake_app_preferences_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpTestApp(
    WidgetTester tester, {
    String initialLocation = AppRoutes.dashboard,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
          createCatalogNavigationTestOverride(),
        ],
        child: AstroManagerApp(initialLocation: initialLocation),
      ),
    );

    await tester.pumpAndSettle();
  }

  // NavigationBar labels can be hidden depending on
  // the Material configuration or selected destination.
  //
  // Select the actual destination widget instead.
  Finder mobileDestination(int index) {
    return find
        .descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(NavigationDestination),
        )
        .at(index);
  }

  testWidgets('Mobile navigation switches sections', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTestApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Destination 1: Targets
    await tester.tap(mobileDestination(1));
    await tester.pumpAndSettle();

    expect(find.text('Celestial Object Catalog'), findsOneWidget);

    expect(find.text('Find suitable celestial targets.'), findsOneWidget);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    // Destination 2: Planner
    await tester.tap(mobileDestination(2));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    // Return to Targets.
    await tester.tap(mobileDestination(1));
    await tester.pumpAndSettle();

    expect(find.text('Celestial Object Catalog'), findsOneWidget);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('Settings opens and returns to previous section', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTestApp(tester, initialLocation: AppRoutes.targets);

    expect(find.byType(TargetsScreen), findsOneWidget);

    final targetsContext = tester.element(find.byType(TargetsScreen));

    targetsContext.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    expect(find.text('Observing Locations'), findsOneWidget);

    final settingsContext = tester.element(find.byType(SettingsScreen));

    settingsContext.go(AppRoutes.targets);
    await tester.pumpAndSettle();

    expect(find.text('Celestial Object Catalog'), findsOneWidget);
  });

  testWidgets('Desktop navigation uses NavigationRail', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTestApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final targetsDestination = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Targets'),
    );

    expect(targetsDestination, findsOneWidget);

    await tester.tap(targetsDestination);
    await tester.pumpAndSettle();

    expect(find.text('Celestial Object Catalog'), findsOneWidget);
  });
}
