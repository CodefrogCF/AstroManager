import 'dart:convert';

import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/data/framing_repository.dart';
import 'package:astromanager/features/atlas/domain/camera_framing.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:flutter_test/flutter_test.dart';

const skyCenter = SkyAtlasPosition(raDegrees: 120, decDegrees: 0);

class FakeFrameStore implements CameraFramingStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  CameraFramingFootprint frame({
    double ra = 120,
    double dec = 0,
    double rotation = 0,
    double width = 4,
    double height = 2,
  }) => CameraFramingGeometry.calculate(
    configuration: CameraFramingConfiguration(
      profileId: 'sony-a7-600mm',
      center: SkyAtlasPosition(raDegrees: ra, decDegrees: dec),
      rotationDegrees: rotation,
    ),
    horizontalFovDegrees: width,
    verticalFovDegrees: height,
  );

  group('Camera field footprint', () {
    test('horizontal/vertical angular sizes agree with input at equator', () {
      final calculated = frame();
      final eastMid = calculated.outline[12];
      final northMid = calculated.outline[20];
      expect(eastMid.raDegrees, closeTo(122, 1e-9));
      expect(eastMid.decDegrees, closeTo(0, 1e-9));
      expect(northMid.raDegrees, closeTo(120, 1e-9));
      expect(northMid.decDegrees, closeTo(1, 1e-9));
      expect(calculated.horizontalFovDegrees, 4);
      expect(calculated.verticalFovDegrees, 2);
      expect(calculated.outline.length, 33);
      expect(
        calculated.outline.first.raDegrees,
        calculated.outline.last.raDegrees,
      );
    });

    test('90-degree rotation rotates east edge toward south', () {
      final calculated = frame(rotation: 90);
      expect(calculated.outline[12].raDegrees, closeTo(120, 1e-9));
      expect(calculated.outline[12].decDegrees, closeTo(-2, 1e-9));
      expect(calculated.outline[20].raDegrees, closeTo(121, 1e-9));
      expect(calculated.outline[20].decDegrees, closeTo(0, 1e-9));
    });

    test('RA wraparound and polar locations remain valid', () {
      for (final position in [
        frame(ra: 359.8),
        frame(ra: 0.2),
        frame(ra: 24, dec: 89.5, width: 2, height: 1),
      ]) {
        for (final point in position.outline) {
          expect(point.raDegrees, inInclusiveRange(0, 360));
          expect(point.decDegrees, inInclusiveRange(-90, 90));
        }
      }
      expect(frame(ra: 359.8).outline.any((p) => p.raDegrees < 3), isTrue);
    });

    test('telescope zoom does not affect sky footprint coordinates', () {
      final computed = frame();
      final controller = SkyAtlasController(initialPosition: skyCenter);
      addTearDown(controller.dispose);
      controller.setCameraFrame(computed);
      final firstJson =
          jsonDecode(controller.stateJson) as Map<String, dynamic>;
      controller.setFieldOfView(12);
      controller.goto(const SkyAtlasPosition(raDegrees: 15, decDegrees: -30));
      final secondJson =
          jsonDecode(controller.stateJson) as Map<String, dynamic>;
      expect(secondJson['cameraFrame'], firstJson['cameraFrame']);
      expect(controller.cameraFrame!.configuration.center.raDegrees, 120);
    });

    test('increasing field of view doubles footprint angular extent', () {
      final small = frame(width: 2, height: 1);
      final large = frame(width: 4, height: 2);
      expect(large.outline[12].raDegrees - 120, closeTo(2, 1e-9));
      expect(small.outline[12].raDegrees - 120, closeTo(1, 1e-9));
      expect(large.diagonalFovDegrees, greaterThan(small.diagonalFovDegrees));
    });

    test('invalid angles and sensor fields are rejected', () {
      expect(() => frame(width: 0), throwsArgumentError);
      expect(() => frame(width: double.nan), throwsArgumentError);
      expect(() => frame(rotation: 360), throwsArgumentError);
      expect(() => frame(dec: 92), throwsArgumentError);
      expect(() => frame(width: 170), throwsArgumentError);
    });
  });

  group('Framing persistence', () {
    test(
      'persists center, rotation and exact equipment profile per target',
      () async {
        final store = FakeFrameStore();
        const config = CameraFramingConfiguration(
          profileId: 'telescope-profile-2',
          center: SkyAtlasPosition(raDegrees: 359.95, decDegrees: 45),
          rotationDegrees: 172.5,
        );
        final first = SharedPreferencesCameraFramingRepository(store: store);
        await first.save('NGC224', config);
        final second = SharedPreferencesCameraFramingRepository(store: store);
        final restored = await second.load('NGC224');
        expect(restored!.profileId, 'telescope-profile-2');
        expect(restored.center.raDegrees, 359.95);
        expect(restored.center.decDegrees, 45);
        expect(restored.rotationDegrees, 172.5);
        expect(await second.load('M42'), isNull);
      },
    );

    test(
      'invalid records are ignored and do not crash atlas startup',
      () async {
        final store = FakeFrameStore();
        final repository = SharedPreferencesCameraFramingRepository(
          store: store,
        );
        await repository.save(
          'NGC224',
          const CameraFramingConfiguration(
            profileId: 'test',
            center: skyCenter,
          ),
        );
        final key = store.values.keys.single;
        store.values[key] = '{not-json';
        expect(await repository.load('NGC224'), isNull);
        store.values[key] = jsonEncode({
          'version': 1,
          'profileId': 'test',
          'ra': 120,
          'dec': 95,
          'rotation': 0,
        });
        expect(await repository.load('NGC224'), isNull);
      },
    );

    test('deleting a saved frame leaves other targets unaffected', () async {
      final store = FakeFrameStore();
      final repo = SharedPreferencesCameraFramingRepository(store: store);
      const config = CameraFramingConfiguration(
        profileId: 'test',
        center: skyCenter,
      );
      await repo.save('M31', config);
      await repo.save('M42', config);
      await repo.delete('M31');
      expect(await repo.load('M31'), isNull);
      expect(await repo.load('M42'), isNotNull);
    });
  });
}
