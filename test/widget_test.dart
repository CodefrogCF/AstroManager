import 'dart:async';

import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:astromanager/app/app.dart';
import 'package:astromanager/app/router/app_router.dart';

import 'package:astromanager/features/settings/application/app_preferences_controller.dart';
import 'package:astromanager/features/alerts/data/observation_alert_store.dart';
import 'package:astromanager/features/equipment/application/equipment_controller.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/presentation/locations_screen.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';
import 'package:astromanager/features/settings/presentation/settings_screen.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/target_details_screen.dart';
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
          dashboardLayoutRepositoryProvider.overrideWithValue(
            MemoryDashboardLayoutRepository(),
          ),
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
          createCatalogNavigationTestOverride(),
          // The alert settings widget loads rules and locations on mount.
          // Keep navigation tests independent of the production database.
          observationAlertStoreProvider.overrideWithValue(
            MemoryObservationAlertStore(),
          ),
          observingLocationsProvider.overrideWithBuild((ref, notifier) => []),
          equipmentProvider.overrideWithBuild(
            (ref, notifier) => EquipmentInventory(items: [], profiles: []),
          ),
          plannedProjectsListProvider.overrideWith((ref) async => []),
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

  testWidgets(
    'System Back closes dialogs and pages before restoring the previous screen',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpTestApp(tester, initialLocation: AppRoutes.targets);

      final router = GoRouter.of(tester.element(find.byType(TargetsScreen)));
      const target = CelestialObject(
        id: 'M31',
        designation: 'Andromeda Galaxy',
        category: CelestialCategory.galaxy,
        sourceType: 'G',
        raDegrees: 10.68,
        decDegrees: 41.27,
        constellation: 'And',
        commonNames: '',
        aliases: '',
      );
      unawaited(
        router.push<void>(AppRoutes.targetDetails(target.id), extra: target),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TargetDetailsScreen), findsOneWidget);

      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      unawaited(router.push<void>(AppRoutes.locations));
      await tester.pumpAndSettle();

      final locationsContext = tester.element(find.byType(LocationsScreen));
      for (final useRootNavigator in [true, false]) {
        unawaited(
          showDialog<void>(
            context: locationsContext,
            useRootNavigator: useRootNavigator,
            builder: (context) => const AlertDialog(title: Text('Test dialog')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(LocationsScreen), findsOneWidget);
      }

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TargetDetailsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TargetsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'System Back from main sections reaches Dashboard before exiting',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final messenger = tester.binding.defaultBinaryMessenger;
      var exits = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pumpTestApp(tester);
      final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
      for (final route in [
        AppRoutes.targets,
        AppRoutes.planner,
        AppRoutes.equipment,
        AppRoutes.projects,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, route);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.dashboard,
        );
        expect(exits, 0);
      }

      await tester.binding.handlePopRoute();
      expect(exits, 1);
    },
  );

  testWidgets('iOS edge swipe goes back from Settings and a section root', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTestApp(tester, initialLocation: AppRoutes.projects);
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.settings);

    const drag = Offset(140, 0);
    await tester.dragFrom(const Offset(80, 400), drag);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.settings);

    await tester.dragFrom(const Offset(5, 400), drag);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.projects);
    await tester.dragFrom(const Offset(5, 400), drag);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.dashboard);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

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
