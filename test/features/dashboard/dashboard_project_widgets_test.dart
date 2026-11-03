import 'package:astromanager/features/dashboard/application/dashboard_project_activity_provider.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_project_activity.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/presentation/dashboard_widget_registry.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/dashboard_project_widgets.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/dashboard_quick_actions_widget.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/features/projects/data/planned_projects_repository.dart';

final _project = PlannedImagingProject(
  id: 'p1',
  title: 'Orion Imaging',
  targetIds: const [],
  createdAtUtc: DateTime.utc(2026, 10, 1),
  plannedIntegrationSeconds: 3600,
  status: ImagingProjectStatus.inProgress,
);
final _session = ObservationSession(
  id: 's1',
  projectId: 'p1',
  startedAtUtc: DateTime.utc(2026, 11, 2, 20),
  timeZoneId: 'Etc/UTC',
  utcOffsetMinutes: 0,
  exposureSeconds: 60,
  frameCount: 20,
  acceptedFrames: 15,
  rejectedFrames: 5,
);

void main() {
  testWidgets(
    'active projects show true integration progress and recent activity',
    (tester) async {
      final snapshot = DashboardProjectActivity.aggregate(
        projects: [_project],
        sessionsByProject: {
          'p1': [_session],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProjectActivityProvider.overrideWith(
              (ref) async => snapshot,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                height: 700,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DashboardActiveProjectsWidget(),
                      DashboardRecentSessionsWidget(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dashboard-active-projects')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-recent-sessions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-project-progress-p1')),
        findsOneWidget,
      );
      expect(find.textContaining('Orion Imaging'), findsWidgets);
      expect(find.textContaining('15'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'projects with no goal remain readable with 200 percent scaling',
    (tester) async {
      final project = _project.copyWith(plannedIntegrationSeconds: 0);
      final snapshot = DashboardProjectActivity.aggregate(
        projects: [project],
        sessionsByProject: {
          'p1': [_session],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProjectActivityProvider.overrideWith(
              (ref) async => snapshot,
            ),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SizedBox(
                  width: 230,
                  height: 240,
                  child: SingleChildScrollView(
                    child: DashboardActiveProjectsWidget(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No integration goal set'),
        findsNothing,
      ); // compact mode
      expect(
        find.byKey(const ValueKey('dashboard-project-progress-p1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('configurable quick actions support compact and hidden buttons', (
    tester,
  ) async {
    const instance = DashboardWidgetInstance(
      id: 'quick',
      typeId: 'quick-actions',
      settings: {
        'compact': true,
        'showAtlas': true,
        'showPlanner': false,
        'showProjects': true,
        'showSessions': true,
      },
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: DashboardQuickActionsWidget(instance: instance)),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('dashboard-quick-atlas')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-quick-planner')), findsNothing);
    expect(
      find.byKey(const ValueKey('dashboard-quick-projects')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-quick-sessions')),
      findsOneWidget,
    );
    expect(find.byType(IconButton), findsNWidgets(3));
  });

  testWidgets('session logging action opens project picker on demand', (
    tester,
  ) async {
    var projectLoads = 0;
    const instance = DashboardWidgetInstance(
      id: 'quick',
      typeId: 'quick-actions',
      settings: {
        'showAtlas': false,
        'showPlanner': false,
        'showProjects': false,
        'showSessions': true,
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannedProjectsListProvider.overrideWith((ref) async {
            projectLoads++;
            return [_project];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardQuickActionsWidget(instance: instance)),
        ),
      ),
    );
    expect(projectLoads, 0);
    await tester.tap(find.byKey(const ValueKey('dashboard-quick-sessions')));
    await tester.pumpAndSettle();
    expect(projectLoads, 1);
    expect(find.text('Orion Imaging'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'new project widgets register independent configurable sizes and limits',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(dashboardWidgetRegistryProvider);
      for (final type in ['active-projects', 'recent-sessions']) {
        final definition = registry.byType(type);
        expect(definition, isNotNull);
        expect(
          definition!.supportedSizes,
          contains(const DashboardWidgetSize(1, 1)),
        );
        expect(definition.settings.single.key, 'limit');
        expect(definition.settings.single.choices, contains('5'));
      }
      expect(registry.byType('quick-actions')!.settings.length, 7);
    },
  );
}
