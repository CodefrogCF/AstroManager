import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/core/errors/app_failure.dart';

import 'package:astromanager/features/locations/application/observing_locations_controller.dart';
import 'package:astromanager/features/locations/data/repositories/drift_observing_location_repository.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/locations/domain/repositories/observing_location_repository.dart';
import 'package:astromanager/features/locations/presentation/locations_screen.dart';

ObservingLocation makeLocation({
  required String id,
  required String name,
  bool isDefault = false,
}) {
  return ObservingLocation(
    id: id,
    name: name,
    latitude: 47.48,
    longitude: 8.21,
    elevationMeters: 400,
    timeZone: 'Europe/Zurich',
    isDefault: isDefault,
  );
}

class FakeObservingLocationRepository implements ObservingLocationRepository {
  final List<ObservingLocation> locations = [];

  @override
  Future<List<ObservingLocation>> getAll() async {
    return List.unmodifiable(locations);
  }

  @override
  Future<void> save(ObservingLocation location) async {
    location.validate();

    final existingIndex = locations.indexWhere(
      (entry) => entry.id == location.id,
    );

    final shouldBeDefault =
        locations.isEmpty ||
        location.isDefault ||
        (existingIndex >= 0 && locations[existingIndex].isDefault);

    if (shouldBeDefault) {
      for (var i = 0; i < locations.length; i++) {
        final current = locations[i];

        locations[i] = ObservingLocation(
          id: current.id,
          name: current.name,
          latitude: current.latitude,
          longitude: current.longitude,
          elevationMeters: current.elevationMeters,
          timeZone: current.timeZone,
          isDefault: false,
        );
      }
    }

    final saved = ObservingLocation(
      id: location.id,
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
      elevationMeters: location.elevationMeters,
      timeZone: location.timeZone,
      isDefault: shouldBeDefault,
    );

    if (existingIndex >= 0) {
      locations[existingIndex] = saved;
    } else {
      locations.add(saved);
    }
  }

  @override
  Future<void> setDefault(String id) async {
    for (var i = 0; i < locations.length; i++) {
      final current = locations[i];

      locations[i] = ObservingLocation(
        id: current.id,
        name: current.name,
        latitude: current.latitude,
        longitude: current.longitude,
        elevationMeters: current.elevationMeters,
        timeZone: current.timeZone,
        isDefault: current.id == id,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    final wasDefault = locations.any(
      (entry) => entry.id == id && entry.isDefault,
    );

    locations.removeWhere((entry) => entry.id == id);

    if (wasDefault && locations.isNotEmpty) {
      await setDefault(locations.first.id);
    }
  }
}

void main() {
  group('Observing location validation', () {
    test('accepts valid Swiss coordinates', () {
      const input = ObservingLocationInput(
        name: 'Home Observatory',
        latitude: 47.48,
        longitude: 8.21,
        elevationMeters: 400,
        timeZone: 'Europe/Zurich',
      );

      expect(input.validate, returnsNormally);
    });

    test('rejects invalid latitude', () {
      const input = ObservingLocationInput(
        name: 'Invalid',
        latitude: 95,
        longitude: 8,
        elevationMeters: 400,
        timeZone: 'Europe/Zurich',
      );

      expect(input.validate, throwsA(isA<ValidationFailure>()));
    });

    test('rejects invalid longitude', () {
      const input = ObservingLocationInput(
        name: 'Invalid',
        latitude: 47,
        longitude: 200,
        elevationMeters: 400,
        timeZone: 'Europe/Zurich',
      );

      expect(input.validate, throwsA(isA<ValidationFailure>()));
    });

    test('rejects invalid time zone', () {
      const input = ObservingLocationInput(
        name: 'Invalid',
        latitude: 47,
        longitude: 8,
        elevationMeters: 400,
        timeZone: 'Invalid/TimeZone',
      );

      expect(input.validate, throwsA(isA<ValidationFailure>()));
    });

    test('rejects non-finite coordinates', () {
      const input = ObservingLocationInput(
        name: 'Invalid',
        latitude: double.nan,
        longitude: 8,
        elevationMeters: 400,
        timeZone: 'Europe/Zurich',
      );

      expect(input.validate, throwsA(isA<ValidationFailure>()));
    });
  });

  group('Drift observing location repository', () {
    late AppDatabase database;
    late DriftObservingLocationRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = DriftObservingLocationRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('first saved location becomes default', () async {
      await repository.save(makeLocation(id: '1', name: 'First'));

      final locations = await repository.getAll();

      expect(locations, hasLength(1));
      expect(locations.first.isDefault, isTrue);
    });

    test('saves and retrieves multiple locations', () async {
      await repository.save(makeLocation(id: '1', name: 'Home'));

      await repository.save(makeLocation(id: '2', name: 'Mountain'));

      final locations = await repository.getAll();

      expect(locations, hasLength(2));
      expect(locations.where((location) => location.isDefault), hasLength(1));
    });

    test('updates an existing location', () async {
      await repository.save(makeLocation(id: '1', name: 'Original'));

      await repository.save(makeLocation(id: '1', name: 'Renamed'));

      final locations = await repository.getAll();

      expect(locations, hasLength(1));
      expect(locations.first.name, 'Renamed');
      expect(locations.first.isDefault, isTrue);
    });

    test('changes the default location', () async {
      await repository.save(makeLocation(id: '1', name: 'First'));

      await repository.save(makeLocation(id: '2', name: 'Second'));

      await repository.setDefault('2');

      final locations = await repository.getAll();

      expect(locations.where((location) => location.isDefault), hasLength(1));

      expect(locations.first.id, '2');
    });

    test('deleting default selects another', () async {
      await repository.save(makeLocation(id: '1', name: 'First'));

      await repository.save(makeLocation(id: '2', name: 'Second'));

      await repository.delete('1');

      final locations = await repository.getAll();

      expect(locations, hasLength(1));
      expect(locations.first.id, '2');
      expect(locations.first.isDefault, isTrue);
    });

    test('deleting final location leaves empty list', () async {
      await repository.save(makeLocation(id: '1', name: 'Only'));

      await repository.delete('1');

      expect(await repository.getAll(), isEmpty);
    });

    test('invalid location cannot be persisted', () async {
      final invalid = ObservingLocation(
        id: 'invalid',
        name: '',
        latitude: 47,
        longitude: 8,
        elevationMeters: 400,
        timeZone: 'Europe/Zurich',
        isDefault: false,
      );

      await expectLater(
        repository.save(invalid),
        throwsA(isA<ValidationFailure>()),
      );

      expect(await repository.getAll(), isEmpty);
    });
  });

  test('migration v1 to v5 preserves settings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'astromanager_migration_',
    );

    final file = File(
      '${directory.path}${Platform.pathSeparator}migration.sqlite',
    );

    try {
      final oldDatabase = AppDatabase(NativeDatabase(file));

      try {
        final oldSettings = AppSettingsRepository(oldDatabase);

        await oldSettings.put('migration.test', 'preserved-value');

        // The simulated legacy schema must not contain v5 project tables.
        await oldDatabase.customStatement('DROP TABLE imaging_project_targets');
        await oldDatabase.customStatement('DROP TABLE imaging_projects');

        await oldDatabase.customStatement(
          'DROP TABLE celestial_catalog_entries',
        );

        await oldDatabase.customStatement('DROP TABLE optical_profiles');

        await oldDatabase.customStatement('DROP TABLE equipment_items');

        await oldDatabase.customStatement('DROP TABLE observing_locations');

        await oldDatabase.customStatement('PRAGMA user_version = 1');
      } finally {
        await oldDatabase.close();
      }

      final migratedDatabase = AppDatabase(NativeDatabase(file));

      try {
        final settings = AppSettingsRepository(migratedDatabase);

        expect(await settings.get('migration.test'), 'preserved-value');

        final locations = DriftObservingLocationRepository(migratedDatabase);

        await locations.save(makeLocation(id: 'new', name: 'After Migration'));

        expect(await locations.getAll(), hasLength(1));

        final version = await migratedDatabase
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(version.read<int>('user_version'), 6);

        final projectTables = await migratedDatabase
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('imaging_projects', 'imaging_project_targets')",
            )
            .get();
        expect(projectTables, hasLength(2));
      } finally {
        await migratedDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  testWidgets('location editor allows manual entry', (tester) async {
    final repository = FakeObservingLocationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observingLocationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: LocationsScreen())),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Add location'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('location-name')),
      'Test Observatory',
    );

    await tester.enterText(
      find.byKey(const ValueKey('location-latitude')),
      '47.48',
    );

    await tester.enterText(
      find.byKey(const ValueKey('location-longitude')),
      '8.21',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.locations, hasLength(1));

    expect(repository.locations.first.name, 'Test Observatory');

    expect(repository.locations.first.isDefault, isTrue);
  });
}
