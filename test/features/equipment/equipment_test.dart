import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/errors/app_failure.dart';
import 'package:astromanager/features/equipment/application/equipment_controller.dart';
import 'package:astromanager/features/equipment/data/repositories/drift_equipment_repository.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/equipment/presentation/equipment_screen.dart';

const testCamera = EquipmentItem(
  id: 'camera-1',
  name: 'Test Full Frame Camera',
  kind: EquipmentKind.camera,
  sensorWidthMm: 36,
  sensorHeightMm: 24,
  resolutionX: 6000,
  resolutionY: 4000,
);

const testOptic = EquipmentItem(
  id: 'optic-1',
  name: '600 mm Telescope',
  kind: EquipmentKind.telescope,
  focalLengthMm: 600,
  apertureMm: 100,
);

const testMount = EquipmentItem(
  id: 'mount-1',
  name: 'Test Tracking Mount',
  kind: EquipmentKind.mount,
  payloadCapacityKg: 5,
);

const testProfile = OpticalProfile(
  id: 'profile-1',
  name: 'Deep Sky Setup',
  cameraId: 'camera-1',
  opticId: 'optic-1',
  mountId: 'mount-1',
  focalMultiplier: 1,
);

void main() {
  group('Equipment domain validation', () {
    test('accepts valid camera specifications', () {
      expect(testCamera.validate, returnsNormally);
    });

    test('rejects invalid camera sensor dimensions', () {
      const invalid = EquipmentItem(
        id: 'bad-camera',
        name: 'Invalid Camera',
        kind: EquipmentKind.camera,
        sensorWidthMm: -10,
        sensorHeightMm: 24,
        resolutionX: 6000,
        resolutionY: 4000,
      );

      expect(invalid.validate, throwsA(isA<ValidationFailure>()));
    });

    test('rejects invalid focal length', () {
      const invalid = EquipmentItem(
        id: 'bad-optic',
        name: 'Invalid Telescope',
        kind: EquipmentKind.telescope,
        focalLengthMm: 0,
        apertureMm: 100,
      );

      expect(invalid.validate, throwsA(isA<ValidationFailure>()));
    });

    test('rejects invalid optical multiplier', () {
      const invalid = OpticalProfile(
        id: 'bad-profile',
        name: 'Invalid Setup',
        cameraId: 'camera-1',
        opticId: 'optic-1',
        focalMultiplier: 0,
      );

      expect(invalid.validate, throwsA(isA<ValidationFailure>()));
    });
  });

  group('Optical calculations', () {
    test('calculates pixel size', () {
      expect(testCamera.pixelSizeXMicrons, closeTo(6, 0.0001));

      expect(testCamera.pixelSizeYMicrons, closeTo(6, 0.0001));
    });

    test('calculates field of view and pixel scale', () {
      final metrics = OpticalMetrics.calculate(
        camera: testCamera,
        optic: testOptic,
        focalMultiplier: 1,
      );

      expect(metrics.effectiveFocalLengthMm, 600);

      expect(metrics.effectiveFocalRatio, closeTo(6, 0.0001));

      expect(metrics.horizontalFovDegrees, closeTo(3.4377, 0.001));

      expect(metrics.verticalFovDegrees, closeTo(2.2915, 0.001));

      expect(metrics.pixelScaleXArcsec, closeTo(2.06265, 0.001));
    });

    test('reducer changes effective focal length', () {
      final metrics = OpticalMetrics.calculate(
        camera: testCamera,
        optic: testOptic,
        focalMultiplier: 0.5,
      );

      expect(metrics.effectiveFocalLengthMm, 300);
      expect(metrics.effectiveFocalRatio, closeTo(3, 0.001));

      expect(metrics.horizontalFovDegrees, greaterThan(6.8));

      expect(metrics.pixelScaleXArcsec, closeTo(4.1253, 0.001));
    });

    test('Barlow decreases field of view', () {
      final normal = OpticalMetrics.calculate(
        camera: testCamera,
        optic: testOptic,
        focalMultiplier: 1,
      );

      final barlow = OpticalMetrics.calculate(
        camera: testCamera,
        optic: testOptic,
        focalMultiplier: 2,
      );

      expect(barlow.effectiveFocalLengthMm, 1200);

      expect(
        barlow.horizontalFovDegrees,
        lessThan(normal.horizontalFovDegrees),
      );
    });
  });

  group('Drift equipment repository', () {
    late AppDatabase database;
    late DriftEquipmentRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = DriftEquipmentRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('starts with empty inventory', () async {
      final inventory = await repository.load();

      expect(inventory.items, isEmpty);
      expect(inventory.profiles, isEmpty);
    });

    test('saves cameras, optics and mounts', () async {
      await repository.saveItem(testCamera);
      await repository.saveItem(testOptic);
      await repository.saveItem(testMount);

      final inventory = await repository.load();

      expect(inventory.items, hasLength(3));
      expect(inventory.cameras, hasLength(1));
      expect(inventory.optics, hasLength(1));
      expect(inventory.mounts, hasLength(1));
    });

    test('updates existing equipment', () async {
      await repository.saveItem(testCamera);

      await repository.saveItem(
        const EquipmentItem(
          id: 'camera-1',
          name: 'Renamed Camera',
          kind: EquipmentKind.camera,
          sensorWidthMm: 36,
          sensorHeightMm: 24,
          resolutionX: 6000,
          resolutionY: 4000,
        ),
      );

      final inventory = await repository.load();

      expect(inventory.items, hasLength(1));
      expect(inventory.cameras.first.name, 'Renamed Camera');
    });

    test('creates a profile with valid references', () async {
      await repository.saveItem(testCamera);
      await repository.saveItem(testOptic);
      await repository.saveItem(testMount);
      await repository.saveProfile(testProfile);

      final inventory = await repository.load();

      expect(inventory.profiles, hasLength(1));

      final metrics = inventory.metricsFor(inventory.profiles.first);

      expect(metrics.effectiveFocalLengthMm, 600);
    });

    test('rejects a profile with missing camera', () async {
      await repository.saveItem(testOptic);

      await expectLater(
        repository.saveProfile(testProfile),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects camera used in the optic field', () async {
      await repository.saveItem(testCamera);

      const invalid = OpticalProfile(
        id: 'invalid',
        name: 'Invalid Profile',
        cameraId: 'camera-1',
        opticId: 'camera-1',
        focalMultiplier: 1,
      );

      await expectLater(
        repository.saveProfile(invalid),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('prevents deletion of referenced equipment', () async {
      await repository.saveItem(testCamera);
      await repository.saveItem(testOptic);
      await repository.saveItem(testMount);
      await repository.saveProfile(testProfile);

      await expectLater(
        repository.deleteItem(testCamera.id),
        throwsA(isA<ValidationFailure>()),
      );

      expect((await repository.load()).cameras, hasLength(1));
    });

    test('allows deletion after removing profile', () async {
      await repository.saveItem(testCamera);
      await repository.saveItem(testOptic);
      await repository.saveItem(testMount);
      await repository.saveProfile(testProfile);

      await repository.deleteProfile(testProfile.id);
      await repository.deleteItem(testCamera.id);

      final inventory = await repository.load();

      expect(inventory.cameras, isEmpty);
      expect(inventory.profiles, isEmpty);
    });

    test('foreign key integrity remains valid', () async {
      await repository.saveItem(testCamera);
      await repository.saveItem(testOptic);
      await repository.saveProfile(
        const OpticalProfile(
          id: 'fk-test',
          name: 'Foreign Key Test',
          cameraId: 'camera-1',
          opticId: 'optic-1',
          focalMultiplier: 1,
        ),
      );

      final violations = await database
          .customSelect('PRAGMA foreign_key_check')
          .get();

      expect(violations, isEmpty);
    });
  });

  testWidgets('equipment can be added through the UI', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    final repository = DriftEquipmentRepository(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [equipmentRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: EquipmentScreen())),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Camera'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('equipment-name')),
      'Test Camera',
    );

    await tester.enterText(find.byKey(const ValueKey('sensor-width')), '36');

    await tester.enterText(find.byKey(const ValueKey('sensor-height')), '24');

    await tester.enterText(find.byKey(const ValueKey('resolution-x')), '6000');

    await tester.enterText(find.byKey(const ValueKey('resolution-y')), '4000');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final inventory = await repository.load();

    expect(inventory.cameras, hasLength(1));
    expect(inventory.cameras.first.name, 'Test Camera');
  });
}
