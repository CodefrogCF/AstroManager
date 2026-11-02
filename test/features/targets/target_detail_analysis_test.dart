import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/domain/services/target_detail_analysis.dart';

const site = ObservingLocation(
  id: 'test-site',
  name: 'Observatory',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
const object = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6848,
  decDegrees: 41.2691,
  constellation: 'And',
  commonNames: 'Andromeda Galaxy',
  aliases: 'M31',
  majorAxisArcmin: 177.83,
  minorAxisArcmin: 69.66,
  visualMagnitude: 3.44,
  messierNumber: 31,
);

void main() {
  test(
    'analysis is deterministic with no weather and real local night boundaries',
    () {
      TargetDetailAnalysisResult build() => TargetDetailAnalysis.calculate(
        object: object,
        location: site,
        localDate: DateTime(2026, 11, 2),
        evaluatedAtUtc: DateTime.utc(2026, 11, 1),
      );
      final a = build();
      final b = build();
      expect(a.visibility.samples.length, b.visibility.samples.length);
      expect(a.visibility.periodStartUtc, b.visibility.periodStartUtc);
      expect(a.visibility.periodEndUtc, b.visibility.periodEndUtc);
      expect(
        a.recommendations.rankedWindows.map((w) => w.score.score).toList(),
        b.recommendations.rankedWindows.map((w) => w.score.score).toList(),
      );
      expect(a.moon.moon.illuminationFraction, inInclusiveRange(0, 1));
      for (final window in a.recommendations.rankedWindows) {
        expect(window.score.score, inInclusiveRange(0, 100));
        expect(window.isProvisional, isTrue);
      }
    },
  );

  test(
    'optical setup fit and unknown angular dimensions are explicitly labeled',
    () {
      final inventory = EquipmentInventory(
        items: const [
          EquipmentItem(
            id: 'c',
            name: 'Full frame',
            kind: EquipmentKind.camera,
            sensorWidthMm: 36,
            sensorHeightMm: 24,
            resolutionX: 6000,
            resolutionY: 4000,
          ),
          EquipmentItem(
            id: 'o',
            name: 'Wide lens',
            kind: EquipmentKind.lens,
            focalLengthMm: 50,
            apertureMm: 2.8,
          ),
          EquipmentItem(
            id: 't',
            name: 'Long scope',
            kind: EquipmentKind.telescope,
            focalLengthMm: 2000,
            apertureMm: 200,
          ),
        ],
        profiles: const [
          OpticalProfile(
            id: 'wide',
            name: 'Wide',
            cameraId: 'c',
            opticId: 'o',
            focalMultiplier: 1,
          ),
          OpticalProfile(
            id: 'long',
            name: 'Long',
            cameraId: 'c',
            opticId: 't',
            focalMultiplier: 1,
          ),
        ],
      );
      final result = TargetDetailAnalysis.calculate(
        object: object,
        location: site,
        localDate: DateTime(2026, 11, 2),
        evaluatedAtUtc: DateTime.utc(2026, 11, 1),
        inventory: inventory,
        selectedProfileId: 'wide',
      );
      expect(result.equipment.first.profile.id, 'wide');
      expect(result.equipment.first.fitsTarget, isTrue);
      expect(result.equipment.last.fitsTarget, isFalse);
      final unknown = TargetDetailAnalysis.calculate(
        object: const CelestialObject(
          id: 'x',
          designation: 'Unknown size',
          category: CelestialCategory.other,
          sourceType: 'Other',
          raDegrees: 10,
          decDegrees: 40,
          constellation: '',
          commonNames: '',
          aliases: '',
        ),
        location: site,
        localDate: DateTime(2026, 11, 2),
        evaluatedAtUtc: DateTime.utc(2026, 11, 1),
        inventory: inventory,
      );
      expect(
        unknown.equipment.every((setup) => setup.fitsTarget == null),
        isTrue,
      );
    },
  );

  test('missing weather never invents a nearby forecast hour', () {
    expect(
      TargetDetailAnalysis.nearestWeatherHour(null, DateTime.utc(2026)),
      isNull,
    );
  });
}
