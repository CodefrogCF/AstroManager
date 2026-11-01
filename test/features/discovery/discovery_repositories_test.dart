import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/discovery/data/discovery_repositories.dart';
import 'package:astromanager/features/targets/data/drift_celestial_catalog_repository.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';

const faint = CelestialObject(
  id: 'faint',
  designation: 'Dim Galaxy',
  category: CelestialCategory.galaxy,
  sourceType: 'Test',
  raDegrees: 30,
  decDegrees: 12,
  constellation: 'And',
  commonNames: '',
  aliases: '',
  visualMagnitude: 13,
);
const bright = CelestialObject(
  id: 'bright',
  designation: 'Bright Nebula',
  category: CelestialCategory.nebula,
  sourceType: 'Test',
  raDegrees: 70,
  decDegrees: 25,
  constellation: 'Ori',
  commonNames: 'Famous bright cloud',
  aliases: 'M999',
  visualMagnitude: 4,
);
const unknown = CelestialObject(
  id: 'unknown',
  designation: 'Unmeasured',
  category: CelestialCategory.other,
  sourceType: 'Test',
  raDegrees: 60,
  decDegrees: 30,
  constellation: '',
  commonNames: '',
  aliases: '',
);

void main() {
  late AppDatabase database;
  late DriftCelestialCatalogRepository catalog;
  late LocalDiscoveryCandidateSource source;
  late SettingsTargetFavoritesStore favorites;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catalog = DriftCelestialCatalogRepository(database);
    source = LocalDiscoveryCandidateSource(catalog, database);
    favorites = SettingsTargetFavoritesStore(AppSettingsRepository(database));
    await catalog.seedIfNeeded(
      CelestialCatalogBundle(
        version: 'discovery-test',
        objects: [faint, unknown, bright],
      ),
    );
  });
  tearDown(() async => database.close());

  test('catalog shortlist sorts by known magnitude, unknown is last', () async {
    final results = await source.load(
      query: '',
      category: null,
      favoriteIds: {},
      favoritesOnly: false,
      limit: 3,
    );
    expect(results.map((row) => row.id).toList(), [
      'bright',
      'faint',
      'unknown',
    ]);
  });

  test('favorites are saved in existing settings and prioritized', () async {
    await favorites.save({'faint', 'unknown'});
    final newInstance = SettingsTargetFavoritesStore(
      AppSettingsRepository(database),
    );
    expect(await newInstance.load(), {'faint', 'unknown'});
    final results = await source.load(
      query: '',
      category: null,
      favoriteIds: await favorites.load(),
      favoritesOnly: true,
    );
    expect(results.map((row) => row.id).toSet(), {'faint', 'unknown'});
  });

  test('filtering and alias search use local catalog', () async {
    final results = await source.load(
      query: 'M999',
      category: CelestialCategory.nebula,
      favoriteIds: {},
      favoritesOnly: false,
    );
    expect(results.single.id, 'bright');
    final empty = await source.load(
      query: '',
      category: CelestialCategory.star,
      favoriteIds: {},
      favoritesOnly: false,
    );
    expect(empty, isEmpty);
  });

  test('invalid shortlist limit throws', () async {
    await expectLater(
      source.load(
        query: '',
        category: null,
        favoriteIds: {},
        favoritesOnly: false,
        limit: 0,
      ),
      throwsArgumentError,
    );
  });
}
