import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/errors/app_failure.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/equipment/domain/services/optical_field_of_view.dart';

const camera = EquipmentItem(
  id: 'camera',
  name: '36 x 24 mm camera',
  kind: EquipmentKind.camera,
  sensorWidthMm: 36,
  sensorHeightMm: 24,
  resolutionX: 6000,
  resolutionY: 4000,
);

const telescope = EquipmentItem(
  id: 'scope',
  name: '600 mm f/6 scope',
  kind: EquipmentKind.telescope,
  focalLengthMm: 600,
  apertureMm: 100,
);

OpticalFieldOfViewResult measure({
  double focalLengthMm = 600,
  double apertureMm = 100,
  double sensorWidthMm = 36,
  double sensorHeightMm = 24,
  int resolutionX = 6000,
  int resolutionY = 4000,
  double focalMultiplier = 1,
  double reducerFactor = 1,
  double barlowFactor = 1,
  double cropFactor = 1,
  SensorRegionOfInterest? regionOfInterest,
}) {
  return OpticalFieldOfViewService.calculate(
    focalLengthMm: focalLengthMm,
    apertureMm: apertureMm,
    sensorWidthMm: sensorWidthMm,
    sensorHeightMm: sensorHeightMm,
    resolutionX: resolutionX,
    resolutionY: resolutionY,
    focalMultiplier: focalMultiplier,
    reducerFactor: reducerFactor,
    barlowFactor: barlowFactor,
    cropFactor: cropFactor,
    regionOfInterest: regionOfInterest,
  );
}

void main() {
  group('Reference image geometry', () {
    test('36 x 24 mm sensor at 600 mm matches independent trig values', () {
      final result = measure();

      expect(result.effectiveFocalLengthMm, 600);
      expect(result.effectiveFocalRatio, 6);
      expect(result.activeSensorWidthMm, 36);
      expect(result.activeSensorHeightMm, 24);
      expect(result.activeResolutionX, 6000);
      expect(result.activeResolutionY, 4000);
      expect(result.horizontalFovDegrees, closeTo(3.4367160033, 1e-8));
      expect(result.verticalFovDegrees, closeTo(2.2915256764, 1e-8));
      expect(result.diagonalFovDegrees, closeTo(4.1298684284, 1e-8));
      expect(result.pixelScaleXArcsecPerPixel, closeTo(2.06265, 1e-8));
      expect(result.pixelScaleYArcsecPerPixel, closeTo(2.06265, 1e-8));
    });

    test('reducer shortens focal length, enlarges FoV and image scale', () {
      final native = measure();
      final reduced = measure(reducerFactor: 0.8);

      expect(reduced.effectiveFocalLengthMm, closeTo(480, 1e-9));
      expect(reduced.effectiveFocalRatio, closeTo(4.8, 1e-9));
      expect(
        reduced.horizontalFovDegrees,
        greaterThan(native.horizontalFovDegrees),
      );
      expect(reduced.pixelScaleXArcsecPerPixel, closeTo(2.5783125, 1e-8));
    });

    test('Barlow doubles focal length and halves image scale', () {
      final native = measure();
      final doubled = measure(barlowFactor: 2);

      expect(doubled.effectiveFocalLengthMm, 1200);
      expect(doubled.effectiveFocalRatio, 12);
      expect(
        doubled.horizontalFovDegrees,
        lessThan(native.horizontalFovDegrees),
      );
      expect(
        doubled.pixelScaleXArcsecPerPixel,
        closeTo(native.pixelScaleXArcsecPerPixel / 2, 1e-9),
      );
    });

    test('combined modifiers are applied once and in any order', () {
      final combined = measure(reducerFactor: 0.5, barlowFactor: 2);
      final native = measure();

      expect(combined.effectiveFocalLengthMm, native.effectiveFocalLengthMm);
      expect(combined.horizontalFovDegrees, native.horizontalFovDegrees);
      expect(
        combined.pixelScaleXArcsecPerPixel,
        native.pixelScaleXArcsecPerPixel,
      );
    });

    test('legacy focal multiplier remains supported', () {
      final viaLegacy = OpticalMetrics.calculate(
        camera: camera,
        optic: telescope,
        focalMultiplier: 0.8,
      );
      final viaExplicit = measure(reducerFactor: 0.8);

      expect(
        viaLegacy.effectiveFocalLengthMm,
        viaExplicit.effectiveFocalLengthMm,
      );
      expect(viaLegacy.horizontalFovDegrees, viaExplicit.horizontalFovDegrees);
      expect(viaLegacy.verticalFovDegrees, viaExplicit.verticalFovDegrees);
      expect(
        viaLegacy.diagonalFovDegrees,
        closeTo(viaExplicit.diagonalFovDegrees, 1e-10),
      );
    });

    test('non-square pixels use independent physical pixel pitches', () {
      final result = measure(
        sensorWidthMm: 24,
        sensorHeightMm: 16,
        resolutionX: 6000,
        resolutionY: 2000,
      );

      expect(result.pixelScaleXArcsecPerPixel, closeTo(1.3751, 1e-8));
      expect(result.pixelScaleYArcsecPerPixel, closeTo(2.7502, 1e-8));
    });
  });

  group('Digital cropping and sensor ROI', () {
    test('1.5x digital crop reduces both axes but preserves pixel scale', () {
      final full = measure();
      final cropped = measure(cropFactor: 1.5);

      expect(cropped.activeResolutionX, 4000);
      expect(cropped.activeResolutionY, 2667);
      expect(cropped.activeSensorWidthMm, closeTo(24, 1e-10));
      expect(cropped.activeSensorHeightMm, closeTo(16.002, 1e-10));
      expect(cropped.horizontalFovDegrees, lessThan(full.horizontalFovDegrees));
      expect(cropped.verticalFovDegrees, lessThan(full.verticalFovDegrees));
      expect(cropped.pixelScaleXArcsecPerPixel, full.pixelScaleXArcsecPerPixel);
      expect(cropped.pixelScaleYArcsecPerPixel, full.pixelScaleYArcsecPerPixel);
      expect(cropped.effectiveFocalLengthMm, full.effectiveFocalLengthMm);
    });

    test('3000 x 2000 pixel ROI halves both sensor dimensions', () {
      final roi = measure(
        regionOfInterest: const SensorRegionOfInterest(
          xPixels: 1000,
          yPixels: 500,
          widthPixels: 3000,
          heightPixels: 2000,
        ),
      );

      expect(roi.activeResolutionX, 3000);
      expect(roi.activeResolutionY, 2000);
      expect(roi.activeSensorWidthMm, 18);
      expect(roi.activeSensorHeightMm, 12);
      expect(roi.horizontalFovDegrees, closeTo(1.7187444873, 1e-8));
      expect(roi.verticalFovDegrees, closeTo(1.1458773954, 1e-8));
      expect(roi.diagonalFovDegrees, closeTo(2.0656049545, 1e-8));
      expect(roi.pixelScaleXArcsecPerPixel, closeTo(2.06265, 1e-8));
    });

    test('ROI offset does not alter angular size', () {
      final first = measure(
        regionOfInterest: const SensorRegionOfInterest(
          xPixels: 0,
          yPixels: 0,
          widthPixels: 1000,
          heightPixels: 1000,
        ),
      );
      final second = measure(
        regionOfInterest: const SensorRegionOfInterest(
          xPixels: 5000,
          yPixels: 3000,
          widthPixels: 1000,
          heightPixels: 1000,
        ),
      );

      expect(first.horizontalFovDegrees, second.horizontalFovDegrees);
      expect(first.verticalFovDegrees, second.verticalFovDegrees);
    });

    test('single pixel ROI is valid', () {
      final result = measure(
        regionOfInterest: const SensorRegionOfInterest(
          xPixels: 5999,
          yPixels: 3999,
          widthPixels: 1,
          heightPixels: 1,
        ),
      );

      expect(result.activeResolutionX, 1);
      expect(result.activeResolutionY, 1);
      expect(result.horizontalFovDegrees, greaterThan(0));
    });

    test('incompatible crop factor and ROI are rejected', () {
      expect(
        () => measure(
          cropFactor: 1.5,
          regionOfInterest: const SensorRegionOfInterest(
            xPixels: 0,
            yPixels: 0,
            widthPixels: 100,
            heightPixels: 100,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('ROI outside full resolution is rejected', () {
      for (final roi in <SensorRegionOfInterest>[
        const SensorRegionOfInterest(
          xPixels: -1,
          yPixels: 0,
          widthPixels: 100,
          heightPixels: 100,
        ),
        const SensorRegionOfInterest(
          xPixels: 5500,
          yPixels: 0,
          widthPixels: 600,
          heightPixels: 100,
        ),
        const SensorRegionOfInterest(
          xPixels: 0,
          yPixels: 0,
          widthPixels: 0,
          heightPixels: 100,
        ),
        const SensorRegionOfInterest(
          xPixels: 0,
          yPixels: 4000,
          widthPixels: 100,
          heightPixels: 1,
        ),
      ]) {
        expect(
          () => measure(regionOfInterest: roi),
          throwsA(isA<ValidationFailure>()),
        );
      }
    });
  });

  group('Validation and downstream compatibility', () {
    test('invalid focal length and sensor specifications are rejected', () {
      expect(
        () => measure(focalLengthMm: 0),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(focalLengthMm: double.nan),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(focalLengthMm: double.infinity),
        throwsA(isA<ValidationFailure>()),
      );
      expect(() => measure(apertureMm: 0), throwsA(isA<ValidationFailure>()));
      expect(
        () => measure(sensorWidthMm: -1),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(sensorHeightMm: double.nan),
        throwsA(isA<ValidationFailure>()),
      );
      expect(() => measure(resolutionX: 0), throwsA(isA<ValidationFailure>()));
      expect(() => measure(resolutionY: -1), throwsA(isA<ValidationFailure>()));
    });

    test('invalid modifiers and crop factors are rejected', () {
      expect(
        () => measure(focalMultiplier: 0),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(reducerFactor: 1.2),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(reducerFactor: 0),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(barlowFactor: 0.8),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(barlowFactor: double.infinity),
        throwsA(isA<ValidationFailure>()),
      );
      expect(() => measure(cropFactor: 0.8), throwsA(isA<ValidationFailure>()));
      expect(
        () => measure(cropFactor: double.nan),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => measure(cropFactor: 4001),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('equipment inventory can apply temporary ROI without persistence', () {
      final inventory = EquipmentInventory(
        items: [camera, telescope],
        profiles: [
          const OpticalProfile(
            id: 'profile',
            name: 'Default',
            cameraId: 'camera',
            opticId: 'scope',
            focalMultiplier: 1,
          ),
        ],
      );
      final profile = inventory.profiles.single;
      final full = inventory.metricsFor(profile);
      final cropped = inventory.metricsFor(
        profile,
        regionOfInterest: const SensorRegionOfInterest(
          xPixels: 1000,
          yPixels: 1000,
          widthPixels: 3000,
          heightPixels: 2000,
        ),
      );

      expect(cropped.horizontalFovDegrees, lessThan(full.horizontalFovDegrees));
      expect(cropped.pixelScaleXArcsec, full.pixelScaleXArcsec);
      expect(profile.focalMultiplier, 1);
    });

    test('invalid equipment kind is rejected by legacy wrapper', () {
      const mount = EquipmentItem(
        id: 'mount',
        name: 'Mount',
        kind: EquipmentKind.mount,
        payloadCapacityKg: 12,
      );

      expect(
        () => OpticalMetrics.calculate(
          camera: camera,
          optic: mount,
          focalMultiplier: 1,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('existing const optical fixtures retain derived diagonal', () {
      const metrics = OpticalMetrics(
        effectiveFocalLengthMm: 600,
        effectiveFocalRatio: 6,
        horizontalFovDegrees: 3.4367160033109143,
        verticalFovDegrees: 2.291525676350207,
        pixelScaleXArcsec: 2.06265,
        pixelScaleYArcsec: 2.06265,
      );

      expect(metrics.diagonalFovDegrees, closeTo(4.1298684284, 1e-8));
    });
  });
}
