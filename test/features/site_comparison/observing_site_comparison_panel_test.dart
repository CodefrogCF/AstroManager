import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/site_comparison/presentation/observing_site_comparison_panel.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';

const sites = [
  ObservingLocation(
    id: 'a',
    name: 'Site A',
    latitude: 47,
    longitude: 8,
    elevationMeters: 500,
    timeZone: 'Europe/Zurich',
    isDefault: true,
  ),
  ObservingLocation(
    id: 'b',
    name: 'Site B',
    latitude: 48,
    longitude: 9,
    elevationMeters: 300,
    timeZone: 'Europe/Zurich',
    isDefault: false,
  ),
  ObservingLocation(
    id: 'c',
    name: 'Site C',
    latitude: 49,
    longitude: 10,
    elevationMeters: 100,
    timeZone: 'Europe/Zurich',
    isDefault: false,
  ),
];

const target = CelestialObject(
  id: 'm31',
  designation: 'M31',
  category: CelestialCategory.galaxy,
  sourceType: 'Test',
  raDegrees: 10,
  decDegrees: 41,
  constellation: 'And',
  commonNames: '',
  aliases: '',
);

void main() {
  testWidgets('comparison stays lazy until explicitly expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siteComparisonTargetsProvider.overrideWith((ref) async => [target]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObservingSiteComparisonPanel(sites: sites),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compare observing sites'), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-run')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('site-comparison-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compare-run')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-site-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-site-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-site-c')), findsOneWidget);
  });

  testWidgets('third site can be included, options can be changed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siteComparisonTargetsProvider.overrideWith((ref) async => [target]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObservingSiteComparisonPanel(sites: sites),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('site-comparison-expand')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('compare-site-c')));
    await tester.tap(find.byKey(const ValueKey('compare-site-c')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('compare-site-c')))
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('compare-terrain')));
    await tester.tap(find.byKey(const ValueKey('compare-terrain')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('compare-terrain')))
          .selected,
      isFalse,
    );
  });
}
