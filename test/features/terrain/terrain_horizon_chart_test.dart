import 'package:astromanager/features/terrain/domain/terrain_horizon.dart';
import 'package:astromanager/features/terrain/presentation/terrain_horizon_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders polar horizon with explicit compass labels', (
    tester,
  ) async {
    final profile = TerrainHorizonProfile(
      sourceId: 'test',
      createdAtUtc: DateTime.utc(2026),
      latitude: 47,
      longitude: 8,
      observerElevationMeters: 400,
      options: const TerrainHorizonOptions(
        azimuthStepDegrees: 30,
        maximumDistanceMeters: 1000,
        distanceStepMeters: 1000,
      ),
      bearings: const [
        TerrainBearing(azimuthDegrees: 0, altitudeDegrees: 0),
        TerrainBearing(azimuthDegrees: 30, altitudeDegrees: 10),
        TerrainBearing(azimuthDegrees: 60, altitudeDegrees: 20),
        TerrainBearing(azimuthDegrees: 90, altitudeDegrees: 30),
        TerrainBearing(azimuthDegrees: 120, altitudeDegrees: 20),
        TerrainBearing(azimuthDegrees: 150, altitudeDegrees: 10),
        TerrainBearing(azimuthDegrees: 180, altitudeDegrees: 0),
        TerrainBearing(azimuthDegrees: 210, altitudeDegrees: 0),
        TerrainBearing(azimuthDegrees: 240, altitudeDegrees: 0),
        TerrainBearing(azimuthDegrees: 270, altitudeDegrees: null),
        TerrainBearing(azimuthDegrees: 300, altitudeDegrees: 0),
        TerrainBearing(azimuthDegrees: 330, altitudeDegrees: 0),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerrainHorizonChart(profile: profile)),
      ),
    );
    expect(find.byKey(const ValueKey('terrain-horizon-plot')), findsOneWidget);
    expect(find.text('E · 90°'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
