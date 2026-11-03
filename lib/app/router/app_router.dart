import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_shell.dart';
import '../../features/atlas/presentation/sky_atlas_screen.dart';
import '../../features/targets/domain/models/celestial_object.dart';
import '../../features/targets/presentation/target_details_screen.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/targets/presentation/targets_screen.dart';
import '../../features/planner/presentation/planner_screen.dart';
import '../../features/equipment/presentation/equipment_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/locations/presentation/locations_screen.dart';

abstract final class AppRoutes {
  static const dashboard = '/dashboard';
  static const targets = '/targets';
  static const atlas = '/targets/atlas';
  static String targetDetails(String id) =>
      '/targets/details/${Uri.encodeComponent(id)}';
  static const planner = '/planner';

  /// Opens the Night Planner for an exact site and local observing date.
  static String plannerForNight(String locationId, String nightDate) => Uri(
    path: planner,
    queryParameters: {'location': locationId, 'night': nightDate},
  ).toString();
  static const equipment = '/equipment';
  static const projects = '/projects';
  static const settings = '/settings';
  static const locations = '/settings/locations';
}

GoRouter createAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: initialLocation != null,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AstroManagerShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.targets,
                builder: (context, state) => const TargetsScreen(),
                routes: [
                  GoRoute(
                    path: 'details/:id',
                    builder: (context, state) => TargetDetailsScreen(
                      targetId: state.pathParameters['id']!,
                      initialObject: state.extra is CelestialObject
                          ? state.extra! as CelestialObject
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'atlas',
                    builder: (context, state) => SkyAtlasScreen(
                      target: state.extra is CelestialObject
                          ? state.extra! as CelestialObject
                          : state.extra is SkyAtlasMosaicRequest
                          ? (state.extra! as SkyAtlasMosaicRequest).target
                          : null,
                      initialMosaic: state.extra is SkyAtlasMosaicRequest
                          ? (state.extra! as SkyAtlasMosaicRequest).plan
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.planner,
                builder: (context, state) {
                  final night = state.uri.queryParameters['night'];
                  final validNight =
                      night != null &&
                      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(night);
                  return PlannerScreen(
                    initialLocationId: state.uri.queryParameters['location'],
                    initialDate: validNight ? DateTime.tryParse(night) : null,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.equipment,
                builder: (context, state) => const EquipmentScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.projects,
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'locations',
                    builder: (context, state) => const LocationsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Page not found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText('The requested page does not exist.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const AppText('Go to Dashboard'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
