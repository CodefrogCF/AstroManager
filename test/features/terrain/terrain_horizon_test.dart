import 'dart:convert';
import 'dart:math' as math;

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/core/astronomy/target_visibility.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/terrain/data/open_topo_data_provider.dart';
import 'package:astromanager/features/terrain/data/terrain_profile_repository.dart';
import 'package:astromanager/features/terrain/domain/terrain_horizon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _site = ObservingLocation(
  id: 'zurich',
  name: 'Zurich',
  latitude: 47.3769,
  longitude: 8.5417,
  elevationMeters: 408,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

class _Heights implements TerrainElevationProvider {
  _Heights(this.function);
  final double? Function(TerrainPoint) function;
  int calls = 0;
  @override
  String get id => 'fixture:mountain';
  @override
  Future<List<double?>> elevations(List<TerrainPoint> points) async {
    calls++;
    return points.map(function).toList();
  }
}

class _MemoryStore implements TerrainProfileStore {
  final values = <String, String>{};
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

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();
}

TerrainHorizonProfile _flatProfile({double altitude = 0}) =>
    TerrainHorizonProfile(
      sourceId: 'fixture',
      createdAtUtc: DateTime.utc(2026, 11, 2),
      latitude: _site.latitude,
      longitude: _site.longitude,
      observerElevationMeters: _site.elevationMeters,
      options: const TerrainHorizonOptions(
        azimuthStepDegrees: 30,
        maximumDistanceMeters: 1000,
        distanceStepMeters: 1000,
      ),
      bearings: [
        for (var i = 0; i < 12; i++)
          TerrainBearing(azimuthDegrees: i * 30, altitudeDegrees: altitude),
      ],
    );

void main() {
  test(
    'spherical destinations match cardinal directions, including dateline wrap',
    () {
      const origin = TerrainPoint(0, 0);
      final north = TerrainHorizonCalculator.destination(origin, 0, 1000);
      final east = TerrainHorizonCalculator.destination(origin, 90, 1000);
      expect(north.latitude, closeTo(0.008993, 0.00001));
      expect(north.longitude, closeTo(0, 0.00001));
      expect(east.longitude, closeTo(0.008993, 0.00001));
      final crossing = TerrainHorizonCalculator.destination(
        const TerrainPoint(0, 179.999),
        90,
        1000,
      );
      expect(crossing.longitude, lessThan(-179));
    },
  );

  test(
    'reference geometric angles account for observer altitude and curvature',
    () {
      // Independent angle reference: +100 m at 1000 m yields ~5.71 degrees.
      final up = TerrainHorizonCalculator.elevationAngleDegrees(
        observerElevationMeters: 1000,
        terrainElevationMeters: 1100,
        distanceMeters: 1000,
      );
      expect(up, closeTo(math.atan(0.1) * 180 / math.pi, 0.005));
      final level = TerrainHorizonCalculator.elevationAngleDegrees(
        observerElevationMeters: 1000,
        terrainElevationMeters: 1000,
        distanceMeters: 10000,
      );
      expect(level, closeTo(-0.045, 0.003));
      expect(
        () => TerrainHorizonCalculator.elevationAngleDegrees(
          observerElevationMeters: 0,
          terrainElevationMeters: 0,
          distanceMeters: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  test('synthetic eastern ridge obstructs east but not west', () async {
    final provider = _Heights(
      (point) =>
          point.longitude > _site.longitude ? 1008 : _site.elevationMeters,
    );
    const options = TerrainHorizonOptions(
      azimuthStepDegrees: 30,
      maximumDistanceMeters: 1000,
      distanceStepMeters: 1000,
    );
    final profile = await TerrainHorizonCalculator.calculate(
      site: _site,
      provider: provider,
      options: options,
      nowUtc: DateTime.utc(2026),
    );
    expect(profile.bearings, hasLength(12));
    expect(profile.altitudeAt(90)!, greaterThan(25));
    expect(profile.altitudeAt(270)!, lessThan(0));
    expect(
      profile.blocks(azimuthDegrees: 90, targetAltitudeDegrees: 20),
      isTrue,
    );
    expect(
      profile.blocks(azimuthDegrees: 270, targetAltitudeDegrees: 20),
      isFalse,
    );
    expect(profile.altitudeAt(360), closeTo(profile.altitudeAt(0)!, 1e-8));
    expect(
      TerrainHorizonProfile.fromJson(profile.toJson()).altitudeAt(90),
      closeTo(profile.altitudeAt(90)!, 1e-8),
    );
  });

  test(
    'missing elevation is explicitly unknown, never assumed clear',
    () async {
      final provider = _Heights((point) => null);
      const options = TerrainHorizonOptions(
        azimuthStepDegrees: 30,
        maximumDistanceMeters: 1000,
        distanceStepMeters: 1000,
      );
      final profile = await TerrainHorizonCalculator.calculate(
        site: _site,
        provider: provider,
        options: options,
      );
      expect(profile.knownBearings, 0);
      expect(
        profile.blocks(azimuthDegrees: 0, targetAltitudeDegrees: 80),
        isNull,
      );
      expect(profile.altitudeAt(45), isNull);
      expect(
        () => TerrainHorizonOptions(azimuthStepDegrees: 7).validate(),
        throwsArgumentError,
      );
      // Keep the production maximum of 60° enforced.
      expect(
        () => const TerrainHorizonOptions(azimuthStepDegrees: 90).validate(),
        throwsArgumentError,
      );
    },
  );

  test(
    'cache survives repository recreation and invalidates site changes',
    () async {
      final store = _MemoryStore();
      final provider = _Heights((point) => 700);
      const options = TerrainHorizonOptions(
        azimuthStepDegrees: 30,
        maximumDistanceMeters: 1000,
        distanceStepMeters: 1000,
      );
      final first = TerrainProfileRepository(provider: provider, store: store);
      final initial = await first.load(_site, options);
      final second = TerrainProfileRepository(provider: provider, store: store);
      final restored = await second.load(_site, options);
      expect(restored.altitudeAt(0), initial.altitudeAt(0));
      expect(provider.calls, 1);
      await second.remove(_site, options);
      await second.load(_site, options);
      expect(provider.calls, 2);
    },
  );

  test('missing dataset is not cached and yields an explicit error', () async {
    final provider = _Heights((point) => null);
    final store = _MemoryStore();
    final repo = TerrainProfileRepository(provider: provider, store: store);
    await expectLater(
      repo.load(
        _site,
        const TerrainHorizonOptions(
          azimuthStepDegrees: 30,
          maximumDistanceMeters: 1000,
          distanceStepMeters: 1000,
        ),
      ),
      throwsStateError,
    );
    expect(store.values, isEmpty);
  });

  test(
    'partially missing radial data marks the complete bearing unknown',
    () async {
      var index = 0;
      final provider = _Heights((point) {
        index++;
        // Two radial samples per bearing: #7 is the first one at 90°.
        return index == 7 ? null : 550;
      });
      final profile = await TerrainHorizonCalculator.calculate(
        site: _site,
        provider: provider,
        options: const TerrainHorizonOptions(
          azimuthStepDegrees: 30,
          maximumDistanceMeters: 2000,
          distanceStepMeters: 1000,
        ),
      );
      expect(profile.knownBearings, 11);
      expect(profile.altitudeAt(90), isNull);
      // The 60° ray is complete. Interpolation into the unknown 90° ray
      // must remain unknown instead of suggesting unobstructed visibility.
      expect(profile.altitudeAt(60), isNotNull);
      expect(profile.altitudeAt(75), isNull);
      expect(profile.altitudeAt(105), isNull);
      expect(profile.altitudeAt(270), isNotNull);
    },
  );

  test('profiles from a different observing site are rejected', () {
    expect(
      () => TargetVisibility.calculate(
        targetJ2000: const EquatorialPosition(raDegrees: 0, decDegrees: 0),
        observer: const ObserverPosition(
          latitudeDegrees: 0,
          longitudeDegrees: 0,
        ),
        startUtc: DateTime.utc(2026),
        endUtc: DateTime.utc(2026, 1, 2),
        terrainHorizon: _flatProfile(),
      ),
      throwsArgumentError,
    );
  });

  test('batched HTTP elevations preserve order and null values', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final locations = request.url.queryParameters['locations']!.split('|');
      return http.Response(
        jsonEncode({
          'status': 'OK',
          'results': [
            for (final value in locations)
              {'elevation': value.contains('8.5417') ? null : 553.6},
          ],
        }),
        200,
      );
    });
    final provider = OpenTopoDataElevationProvider(
      client: client,
      batchSize: 2,
      betweenRequests: Duration.zero,
    );
    final heights = await provider.elevations([
      const TerrainPoint(47.37, 8.54),
      const TerrainPoint(47.38, 8.5417),
      const TerrainPoint(47.39, 8.55),
    ]);
    expect(heights, [553.6, null, 553.6]);
    expect(requests, hasLength(2));
    expect(requests.first.path, '/v1/eudem25m');
    client.close();
  });

  test('terrain is optional; high ridges remove available visibility', () {
    final start = DateTime.utc(2026, 11, 2, 18);
    final end = start.add(const Duration(hours: 6));
    const target = EquatorialPosition(raDegrees: 10.6847, decDegrees: 41.2687);
    const observer = ObserverPosition(
      latitudeDegrees: 47.3769,
      longitudeDegrees: 8.5417,
      elevationMeters: 408,
    );
    TargetVisibilityResult calculate(TerrainHorizonProfile? terrain) =>
        TargetVisibility.calculate(
          targetJ2000: target,
          observer: observer,
          startUtc: start,
          endUtc: end,
          minimumAltitudeDegrees: 0,
          terrainHorizon: terrain,
        );
    final baseline = calculate(null);
    final flat = calculate(_flatProfile());
    final blocked = calculate(_flatProfile(altitude: 90));
    expect(baseline.totalVisibleDuration, greaterThan(Duration.zero));
    expect(flat.totalVisibleDuration, baseline.totalVisibleDuration);
    expect(blocked.totalVisibleDuration, Duration.zero);
  });
}
