import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';

import 'package:astromanager/features/targets/application/celestial_catalog_controller.dart';
import 'package:astromanager/features/targets/data/catalog_asset_source.dart';
import 'package:astromanager/features/targets/data/drift_celestial_catalog_repository.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/presentation/targets_screen.dart';

const andromeda = CelestialObject(
  id: 'NGC0224',
  designation: 'NGC 224',
  category: CelestialCategory.galaxy,
  sourceType: 'G',
  raDegrees: 10.6848,
  decDegrees: 41.2691,
  constellation: 'And',
  visualMagnitude: 3.44,
  majorAxisArcmin: 177.83,
  minorAxisArcmin: 69.66,
  messierNumber: 31,
  commonNames: 'Andromeda Galaxy',
  aliases: 'NGC0224, NGC 224, M31, M 31',
);

const orion = CelestialObject(
  id: 'NGC1976',
  designation: 'NGC 1976',
  category: CelestialCategory.nebula,
  sourceType: 'HII',
  raDegrees: 83.82,
  decDegrees: -5.39,
  constellation: 'Ori',
  visualMagnitude: 4.0,
  majorAxisArcmin: 65,
  minorAxisArcmin: 60,
  messierNumber: 42,
  commonNames: 'Orion Nebula',
  aliases: 'NGC1976, NGC 1976, M42, M 42',
);

CelestialCatalogBundle sampleBundle({String version = 'test-v1'}) {
  return CelestialCatalogBundle(
    version: version,
    objects: const [andromeda, orion],
  );
}

class FakeCatalogAssetSource implements CatalogAssetSource {
  FakeCatalogAssetSource(this.bundle);

  final CelestialCatalogBundle bundle;

  @override
  Future<CelestialCatalogBundle> load() async => bundle;
}

void main() {
  group('Celestial object domain', () {
    test('accepts valid J2000 coordinates', () {
      expect(andromeda.validate, returnsNormally);
      expect(orion.validate, returnsNormally);
    });

    test('rejects right ascension outside 0-360', () {
      const invalid = CelestialObject(
        id: 'invalid',
        designation: 'Invalid object',
        category: CelestialCategory.other,
        sourceType: 'Other',
        raDegrees: 400,
        decDegrees: 10,
        constellation: '',
        commonNames: '',
        aliases: '',
      );

      expect(invalid.validate, throwsException);
    });

    test('rejects invalid declination', () {
      const invalid = CelestialObject(
        id: 'invalid',
        designation: 'Invalid object',
        category: CelestialCategory.other,
        sourceType: 'Other',
        raDegrees: 100,
        decDegrees: -100,
        constellation: '',
        commonNames: '',
        aliases: '',
      );

      expect(invalid.validate, throwsException);
    });

    test('parses versioned catalog JSON', () {
      final bundle = CelestialCatalogBundle.fromJson({
        'version': 'test-v1',
        'source': 'OpenNGC',
        'license': 'CC-BY-SA-4.0',
        'objects': [
          {
            'id': 'NGC0224',
            'designation': 'NGC 224',
            'category': 'galaxy',
            'sourceType': 'G',
            'raDegrees': 10.6848,
            'decDegrees': 41.2691,
            'constellation': 'And',
            'visualMagnitude': 3.44,
            'majorAxisArcmin': 177.83,
            'minorAxisArcmin': 69.66,
            'messierNumber': 31,
            'commonNames': 'Andromeda Galaxy',
            'aliases': 'NGC0224, M31',
          },
        ],
      });

      expect(bundle.version, 'test-v1');
      expect(bundle.objects, hasLength(1));
      expect(bundle.objects.first.messierNumber, 31);
    });
  });

  group('Drift catalog repository', () {
    late AppDatabase database;
    late DriftCelestialCatalogRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = DriftCelestialCatalogRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('initial database has no catalog objects', () async {
      expect(await repository.count(), 0);
    });

    test('imports bundled objects', () async {
      await repository.seedIfNeeded(sampleBundle());

      expect(await repository.count(), 2);

      final saved = await repository.findById('NGC0224');

      expect(saved, isNotNull);
      expect(saved!.messierNumber, 31);
      expect(saved.commonNames, 'Andromeda Galaxy');
    });

    test('repeated import is idempotent', () async {
      final bundle = sampleBundle();

      await repository.seedIfNeeded(bundle);
      await repository.seedIfNeeded(bundle);

      expect(await repository.count(), 2);
    });

    test('searches Messier aliases', () async {
      await repository.seedIfNeeded(sampleBundle());

      final results = await repository.search(query: 'M31');

      expect(results, hasLength(1));
      expect(results.single.id, 'NGC0224');
    });

    test('searches common names', () async {
      await repository.seedIfNeeded(sampleBundle());

      final results = await repository.search(query: 'orion nebula');

      expect(results, hasLength(1));
      expect(results.single.id, 'NGC1976');
    });

    test('searches catalog identifiers', () async {
      await repository.seedIfNeeded(sampleBundle());

      final results = await repository.search(query: 'NGC 224');

      expect(results, hasLength(1));
      expect(results.single.id, 'NGC0224');
    });

    test('filters by object category', () async {
      await repository.seedIfNeeded(sampleBundle());

      final galaxies = await repository.search(
        category: CelestialCategory.galaxy,
      );

      expect(galaxies, hasLength(1));
      expect(galaxies.single.id, 'NGC0224');
    });

    test('limits results', () async {
      await repository.seedIfNeeded(sampleBundle());

      final results = await repository.search(limit: 1);

      expect(results, hasLength(1));
    });

    test('updates catalog data when version changes', () async {
      await repository.seedIfNeeded(sampleBundle(version: 'test-v1'));

      await repository.seedIfNeeded(
        CelestialCatalogBundle(
          version: 'test-v2',
          objects: const [
            CelestialObject(
              id: 'NGC0224',
              designation: 'NGC 224',
              category: CelestialCategory.galaxy,
              sourceType: 'G',
              raDegrees: 10.6848,
              decDegrees: 41.2691,
              constellation: 'And',
              visualMagnitude: 3.44,
              messierNumber: 31,
              commonNames: 'Updated Andromeda Galaxy',
              aliases: 'M31',
            ),
            orion,
          ],
        ),
      );

      final updated = await repository.findById('NGC0224');

      expect(updated!.commonNames, 'Updated Andromeda Galaxy');
      expect(await repository.count(), 2);
    });
  });

  test('migration v3 to v5 preserves existing settings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'astromanager_catalog_migration_',
    );

    final file = File(
      '${directory.path}${Platform.pathSeparator}migration.sqlite',
    );

    try {
      final oldDatabase = AppDatabase(NativeDatabase(file));

      try {
        final settings = AppSettingsRepository(oldDatabase);

        await settings.put('existing.setting', 'preserved-value');

        // Simulate schema v3 before the catalog table existed.
        // The simulated legacy schema must not contain v5 project tables.
        await oldDatabase.customStatement('DROP TABLE imaging_project_targets');
        await oldDatabase.customStatement('DROP TABLE imaging_projects');

        await oldDatabase.customStatement(
          'DROP TABLE celestial_catalog_entries',
        );

        await oldDatabase.customStatement('PRAGMA user_version = 3');
      } finally {
        await oldDatabase.close();
      }

      final migrated = AppDatabase(NativeDatabase(file));

      try {
        final settings = AppSettingsRepository(migrated);

        expect(await settings.get('existing.setting'), 'preserved-value');

        final repository = DriftCelestialCatalogRepository(migrated);

        await repository.seedIfNeeded(sampleBundle());

        expect(await repository.count(), 2);

        final result = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(result.read<int>('user_version'), 6);

        final projectTables = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('imaging_projects', 'imaging_project_targets')",
            )
            .get();
        expect(projectTables, hasLength(2));
      } finally {
        await migrated.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  testWidgets('catalog search works in Targets UI', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          celestialCatalogRepositoryProvider.overrideWithValue(
            DriftCelestialCatalogRepository(database),
          ),
          catalogAssetSourceProvider.overrideWithValue(
            FakeCatalogAssetSource(sampleBundle()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TargetsScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2 catalog objects available offline'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('catalog-search')), 'M31');

    await tester.pumpAndSettle();

    expect(find.text('M 31 · NGC 224'), findsOneWidget);
    expect(find.text('M 42 · NGC 1976'), findsNothing);
  });
}
