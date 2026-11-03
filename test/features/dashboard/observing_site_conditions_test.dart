import 'dart:convert';

import 'package:astromanager/features/dashboard/domain/observing_site_conditions.dart';
import 'package:astromanager/features/light_pollution/data/light_pollution_repository.dart';
import 'package:astromanager/features/light_pollution/domain/light_pollution.dart';
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

class _NightSource implements LightPollutionProvider {
  int calls = 0;
  @override
  String get id => 'viirs-fixture';
  @override
  Future<LightPollutionReading?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    throw StateError('Dashboard must not request night-light data');
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

class _NightStore implements LightPollutionCacheStore {
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

LightPollutionReading _reading() => LightPollutionReading(
  kind: NightLightKind.satelliteRadiance,
  value: 3.25,
  sourceId: 'viirs-fixture',
  sourceName: 'EOG/NOAA via Esri',
  datasetDate: DateTime.utc(2025, 12, 31),
  latitude: _site.latitude,
  longitude: _site.longitude,
  description: 'Monthly upward radiance, not Bortle or SQM.',
  sourceUrl: 'https://example.test/viirs',
  license: 'EOG/NOAA attribution',
);

void main() {
  test(
    'dashboard reads cached terrain and radiance without any network calls',
    () async {
      final now = DateTime.now().toUtc();
      final terrainSource = _TerrainSource();
      final lightSource = _NightSource();
      final terrainStore = _TerrainStore();
      final nightStore = _NightStore();
      final terrainRepo = TerrainProfileRepository(
        provider: terrainSource,
        store: terrainStore,
      );
      final lightRepo = LightPollutionRepository(
        provider: lightSource,
        cache: nightStore,
        now: () => now,
      );
      await terrainStore.setString(
        terrainRepo.cacheKey(_site, const TerrainHorizonOptions()),
        jsonEncode(_profile(now).toJson()),
      );
      await nightStore.setString(
        lightRepo.cacheKey(_site.latitude, _site.longitude),
        jsonEncode({
          'checkedAt': now.toIso8601String(),
          'reading': _reading().toJson(),
        }),
      );
      final reader = ObservingSiteConditionsReader(
        terrainRepository: terrainRepo,
        lightPollutionRepository: lightRepo,
      );
      final result = await reader.read(_site);
      expect(result.site.id, 'site-a');
      expect(result.knownTerrainBearings, 18);
      expect(result.terrainCoverage, 0.5);
      expect(result.terrainStale, isFalse);
      expect(result.nightLightReading?.unit, 'nW/cm²/sr');
      expect(result.nightLightReading?.kind, NightLightKind.satelliteRadiance);
      expect(result.nightLights?.checkedAtUtc, now);
      expect(terrainSource.calls, 0);
      expect(lightSource.calls, 0);
      final missing = await reader.read(_other);
      expect(missing.terrain, isNull);
      expect(missing.nightLightReading, isNull);
      expect(terrainSource.calls, 0);
      expect(lightSource.calls, 0);
    },
  );

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
        lightPollutionRepository: LightPollutionRepository(
          provider: _NightSource(),
          cache: _NightStore(),
        ),
      ).read(_site);
      expect(result.terrain?.options.azimuthStepDegrees, 20);
      expect(result.knownTerrainBearings, 18);
      expect(provider.calls, 0);
    },
  );

  test(
    'stale readings remain explicitly marked and never trigger refresh',
    () async {
      final now = DateTime.now().toUtc();
      final old = now.subtract(const Duration(days: 40));
      final terrainSource = _TerrainSource();
      final lightSource = _NightSource();
      final terrainStore = _TerrainStore();
      final nightStore = _NightStore();
      final terrainRepo = TerrainProfileRepository(
        provider: terrainSource,
        store: terrainStore,
      );
      final lightRepo = LightPollutionRepository(
        provider: lightSource,
        cache: nightStore,
        now: () => now,
      );
      await terrainStore.setString(
        terrainRepo.cacheKey(_site, const TerrainHorizonOptions()),
        jsonEncode(_profile(old).toJson()),
      );
      await nightStore.setString(
        lightRepo.cacheKey(_site.latitude, _site.longitude),
        jsonEncode({
          'checkedAt': old.toIso8601String(),
          'reading': _reading().toJson(),
        }),
      );
      final result = await ObservingSiteConditionsReader(
        terrainRepository: terrainRepo,
        lightPollutionRepository: lightRepo,
      ).read(_site);
      expect(result.terrainStale, isTrue);
      expect(result.nightLights?.isStale, isTrue);
      expect(result.terrain?.sourceId, terrainSource.id);
      expect(terrainSource.calls, 0);
      expect(lightSource.calls, 0);
    },
  );

  test(
    'wrong-location and wrong-provider cache entries cannot appear',
    () async {
      final now = DateTime.now().toUtc();
      final terrainSource = _TerrainSource();
      final lightSource = _NightSource();
      final terrainStore = _TerrainStore();
      final lightStore = _NightStore();
      final terrainRepo = TerrainProfileRepository(
        provider: terrainSource,
        store: terrainStore,
      );
      final lightRepo = LightPollutionRepository(
        provider: lightSource,
        cache: lightStore,
        now: () => now,
      );
      await terrainStore.setString(
        terrainRepo.cacheKey(_site, const TerrainHorizonOptions()),
        jsonEncode(_profile(now).toJson()..['source'] = 'wrong-provider'),
      );
      await lightStore.setString(
        lightRepo.cacheKey(_site.latitude, _site.longitude),
        jsonEncode({
          'checkedAt': now.toIso8601String(),
          'reading': _reading().toJson()..['longitude'] = _other.longitude,
        }),
      );
      final result = await ObservingSiteConditionsReader(
        terrainRepository: terrainRepo,
        lightPollutionRepository: lightRepo,
      ).read(_site);
      expect(result.terrain, isNull);
      expect(result.nightLightReading, isNull);
      // A foreign terrain cache entry is ignored, not rewritten or displayed.
      expect(terrainStore.data.length, 1);
      expect(lightStore.data, isEmpty);
    },
  );
}
