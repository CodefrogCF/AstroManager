import 'dart:convert';

import 'package:astromanager/features/dashboard/domain/observing_site_conditions.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/terrain/data/terrain_profile_repository.dart';
import 'package:astromanager/features/terrain/domain/terrain_horizon.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = ObservingLocation(
  id: 'site-a',
  name: 'Mountain',
  latitude: 47.4,
  longitude: 8.5,
  elevationMeters: 720,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
const _other = ObservingLocation(
  id: 'site-b',
  name: 'Other',
  latitude: 46.5,
  longitude: 9.1,
  elevationMeters: 500,
  timeZone: 'Europe/Zurich',
  isDefault: false,
);

class _TerrainSource implements TerrainElevationProvider {
  int calls = 0;
  @override
  String get id => 'opentopodata:fixture:eudem25m';
  @override
  Future<List<double?>> elevations(List<TerrainPoint> points) async {
    calls++;
    throw StateError('Dashboard must not request elevation data');
  }
}

class _TerrainStore implements TerrainProfileStore {
  final data = <String, String>{};
  @override
  Future<String?> getString(String key) async => data[key];
  @override
  Future<void> setString(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }

  @override
  Future<Set<String>> getKeys() async => data.keys.toSet();
}

TerrainHorizonProfile _profile(DateTime created) => TerrainHorizonProfile(
  sourceId: 'opentopodata:fixture:eudem25m',
  createdAtUtc: created,
  latitude: _site.latitude,
  longitude: _site.longitude,
  observerElevationMeters: _site.elevationMeters,
  options: const TerrainHorizonOptions(),
  bearings: [
    for (var i = 0; i < 36; i++)
      TerrainBearing(
        azimuthDegrees: i * 10.0,
        altitudeDegrees: i.isEven ? 3.0 : null,
      ),
  ],
);

void main() {
  test('dashboard reads saved terrain without network calls', () async {
    final now = DateTime.now().toUtc();
    final terrainSource = _TerrainSource();
    final terrainStore = _TerrainStore();
    final terrainRepo = TerrainProfileRepository(
      provider: terrainSource,
      store: terrainStore,
    );
    await terrainStore.setString(
      terrainRepo.cacheKey(_site, const TerrainHorizonOptions()),
      jsonEncode(_profile(now).toJson()),
    );
    final reader = ObservingSiteConditionsReader(
      terrainRepository: terrainRepo,
    );
    final result = await reader.read(_site);
    expect(result.site.id, 'site-a');
    expect(result.knownTerrainBearings, 18);
    expect(result.terrainCoverage, 0.5);
    expect(result.terrainStale, isFalse);
    expect(terrainSource.calls, 0);
    final missing = await reader.read(_other);
    expect(missing.terrain, isNull);
    expect(terrainSource.calls, 0);
  });

  test(
    'an existing non-default terrain resolution is visible without fetch',
    () async {
      final provider = _TerrainSource();
      final store = _TerrainStore();
      final terrainRepo = TerrainProfileRepository(
        provider: provider,
        store: store,
      );
      const alternate = TerrainHorizonOptions(azimuthStepDegrees: 20);
      final profile = TerrainHorizonProfile(
        sourceId: provider.id,
        createdAtUtc: DateTime.now().toUtc(),
        latitude: _site.latitude,
        longitude: _site.longitude,
        observerElevationMeters: _site.elevationMeters,
        options: alternate,
        bearings: [
          for (var i = 0; i < 18; i++)
            TerrainBearing(azimuthDegrees: i * 20.0, altitudeDegrees: 2.0),
        ],
      );
      await store.setString(
        terrainRepo.cacheKey(_site, alternate),
        jsonEncode(profile.toJson()),
      );
      final result = await ObservingSiteConditionsReader(
        terrainRepository: terrainRepo,
      ).read(_site);
      expect(result.terrain?.options.azimuthStepDegrees, 20);
      expect(result.knownTerrainBearings, 18);
      expect(provider.calls, 0);
    },
  );

  test('stale terrain stays marked and never triggers refresh', () async {
    final now = DateTime.now().toUtc();
    final old = now.subtract(const Duration(days: 40));
    final terrainSource = _TerrainSource();
    final terrainStore = _TerrainStore();
    final terrainRepo = TerrainProfileRepository(
      provider: terrainSource,
      store: terrainStore,
    );
    await terrainStore.setString(
      terrainRepo.cacheKey(_site, const TerrainHorizonOptions()),
      jsonEncode(_profile(old).toJson()),
    );
    final result = await ObservingSiteConditionsReader(
      terrainRepository: terrainRepo,
    ).read(_site);
    expect(result.terrainStale, isTrue);
    expect(result.terrain?.sourceId, terrainSource.id);
    expect(terrainSource.calls, 0);
  });

  test('wrong-provider cache entry cannot appear', () async {
    final now = DateTime.now().toUtc();
    final terrainSource = _TerrainSource();
    final terrainStore = _TerrainStore();
    final terrainRepo = TerrainProfileRepository(
      provider: terrainSource,
      store: terrainStore,
    );
    await terrainStore.setString(
      terrainRepo.cacheKey(_site, const TerrainHorizonOptions()),
      jsonEncode(_profile(now).toJson()..['source'] = 'wrong-provider'),
    );
    final result = await ObservingSiteConditionsReader(
      terrainRepository: terrainRepo,
    ).read(_site);
    expect(result.terrain, isNull);
    // A foreign terrain cache entry is ignored, not rewritten or displayed.
    expect(terrainStore.data.length, 1);
  });
}
