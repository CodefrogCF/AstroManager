import 'package:astromanager/features/dashboard/application/top_targets_provider.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/domain/top_targets.dart';
import 'package:astromanager/features/discovery/domain/discovery_results.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/dashboard/presentation/widgets/top_targets_widget.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = ObservingLocation(
  id: 'test',
  name: 'Test',
  latitude: 47.4,
  longitude: 8.3,
  elevationMeters: 450,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
const _instance = DashboardWidgetInstance(
  id: 'targets',
  typeId: 'top-targets',
  settings: {'candidateSource': 'projects', 'minimumDurationMinutes': '90'},
);

void main() {
  testWidgets('without a site no ranking provider is activated', (
    tester,
  ) async {
    var evaluations = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topTargetsProvider.overrideWith((ref, query) async {
            evaluations++;
            throw StateError('Should not be loaded');
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TopTargetsWidget(location: null, instance: _instance),
          ),
        ),
      ),
    );
    expect(find.text('No observing location selected.'), findsOneWidget);
    expect(evaluations, 0);
  });

  testWidgets('query uses site, tonight, candidate scope and duration', (
    tester,
  ) async {
    final queries = <TopTargetsQuery>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topTargetsProvider.overrideWith((ref, query) async {
            queries.add(query);
            return TopTargetsResult(
              nightDate: DateTime.parse(query.nightDate),
              considered: 2,
              candidates: const [],
              ranked: const [],
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 420,
              child: TopTargetsWidget(location: _site, instance: _instance),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(queries, hasLength(1));
    expect(queries.single.locationId, 'test');
    expect(queries.single.source, DashboardTargetSource.projects);
    expect(queries.single.minimumDurationMinutes, 90);
    expect(find.textContaining('No qualifying targets'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-target-refresh')));
    await tester.pumpAndSettle();
    expect(queries.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'top target shows score, window, moon distance and detail actions',
    (tester) async {
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 2));
      const target = CelestialObject(
        id: 'm31',
        designation: 'M31',
        category: CelestialCategory.galaxy,
        sourceType: 'test',
        raDegrees: 10.6,
        decDegrees: 41.3,
        constellation: 'And',
        commonNames: 'Andromeda',
        aliases: '',
      );
      final record = RankedDiscoveryTarget(
        object: target,
        window: ObservationWindow(
          targetId: 'm31',
          targetDesignation: 'M31',
          startUtc: start,
          endUtc: end,
          bestAltitudeDegrees: 61,
          bestAltitudeAtUtc: start,
          weatherStatus: WindowWeatherStatus.missing,
          weatherTimeCoverage: 0,
          weatherParameterCoverage: 0,
          explanation: 'Scored for astronomical darkness.',
          score: TargetSuitabilityScore(
            targetId: 'm31',
            startUtc: start,
            endUtc: end,
            score: 48,
            dataCoverage: 0.6,
            isProvisional: true,
            visibleDuration: const Duration(hours: 2),
            astronomicalDarkDuration: const Duration(hours: 2),
            usableDuration: const Duration(hours: 2),
            bestUsableAltitudeDegrees: 61,
            factors: const {
              SuitabilityFactor.altitude: SuitabilityFactorResult(
                factor: SuitabilityFactor.altitude,
                status: SuitabilityDataStatus.complete,
                rawScore: 90,
                weight: 0.18,
                contribution: 16.2,
                dataCoverage: 1,
                explanation: 'High above the horizon.',
              ),
            },
            constraints: const [],
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topTargetsProvider.overrideWith(
              (ref, query) async => TopTargetsResult(
                nightDate: DateTime.utc(2030, 1, 1),
                considered: 4,
                candidates: const [target],
                ranked: [record],
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 390,
                  child: TopTargetsWidget(location: _site, instance: _instance),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('top-target-score-m31')),
        findsOneWidget,
      );
      expect(find.textContaining('Moon separation'), findsOneWidget);
      expect(
        find.textContaining('Terrain horizon not available'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('top-target-atlas-m31')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('top-target-plan-m31')), findsOneWidget);
      final details = find.byKey(const ValueKey('top-target-explanation-m31'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('High above the horizon.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
