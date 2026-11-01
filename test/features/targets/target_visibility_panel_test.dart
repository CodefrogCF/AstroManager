import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/target_visibility_panel.dart';

const _m31 = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6848,
  decDegrees: 41.2691,
  constellation: 'And',
  commonNames: 'Andromeda Galaxy',
  aliases: 'M31',
);

const _site = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

void main() {
  testWidgets('displays dark visibility and configurable minimum altitude', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TargetVisibilityPanel(
              object: _m31,
              location: _site,
              localDate: _fixedDate,
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('target-visibility-panel')),
      findsOneWidget,
    );
    expect(find.text('Minimum altitude: 30°'), findsOneWidget);
    expect(find.textContaining('Visibility windows'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('target-visibility-best')),
      findsOneWidget,
    );
    final slider = find.byKey(const ValueKey('target-min-altitude-slider'));
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();
    expect(find.text('Minimum altitude: 30°'), findsNothing);
  });
}

final DateTime _fixedDate = DateTime.utc(2026, 11, 1);
