import 'dart:convert';

import 'package:astromanager/features/light_pollution/data/arcgis_viirs_provider.dart';
import 'package:astromanager/features/light_pollution/data/light_pollution_repository.dart';
import 'package:astromanager/features/light_pollution/domain/light_pollution.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class _MemoryStore implements LightPollutionCacheStore {
  final map = <String, String>{};
  @override
  Future<String?> getString(String key) async => map[key];
  @override
  Future<void> setString(String key, String value) async {
    map[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    map.remove(key);
  }
}

final class _FakeProvider implements LightPollutionProvider {
  _FakeProvider({this.value}) : fail = false;
  LightPollutionReading? value;
  bool fail;
  int calls = 0;
  @override
  String get id => 'fake-v1';
  @override
  Future<LightPollutionReading?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    if (fail) throw StateError('offline');
    return value;
  }
}

LightPollutionReading fixture({
  double radiance = 2,
  double latitude = 47.38,
  double longitude = 8.54,
}) => LightPollutionReading(
  kind: NightLightKind.satelliteRadiance,
  value: radiance,
  sourceId: 'fake-v1',
  sourceName: 'Synthetic VIIRS fixture',
  datasetDate: DateTime.utc(2025, 12, 31),
  latitude: latitude,
  longitude: longitude,
  description: 'Synthetic monthly radiance, not an SQM reading.',
);

void main() {
  test('units, dataset date and kind survive JSON serialization', () {
    final original = fixture();
    final output = LightPollutionReading.fromJson(original.toJson());
    expect(output.unit, 'nW/cm²/sr');
    expect(output.kind, NightLightKind.satelliteRadiance);
    expect(output.datasetDate, DateTime.utc(2025, 12, 31));
    expect(output.value, 2);
    expect(output.kindLabel, contains('Satellite'));
  });

  test('measured sky brightness is not treated as VIIRS radiance', () {
    final measured = LightPollutionReading(
      kind: NightLightKind.measuredSkyBrightness,
      value: 21.3,
      sourceId: 'sqm',
      sourceName: 'SQM',
      datasetDate: DateTime.utc(2026, 1, 1),
      latitude: 47.38,
      longitude: 8.54,
      description: 'Instrument reading',
    );
    expect(measured.unit, 'mag/arcsec²');
    expect(SatelliteRadianceIndicator.relativeDarknessScore(measured), isNull);
    expect(SatelliteRadianceIndicator.relativeDarknessScore(null), isNull);
    expect(
      SatelliteRadianceIndicator.relativeDarknessScore(fixture(radiance: 0)),
      100,
    );
    expect(
      SatelliteRadianceIndicator.relativeDarknessScore(fixture(radiance: 20)),
      closeTo(20, 1e-9),
    );
  });

  test('rejects impossible and nonfinite values', () {
    expect(() => fixture(radiance: -1).validate(), throwsFormatException);
    expect(
      () => fixture(radiance: double.nan).validate(),
      throwsFormatException,
    );
    expect(() => fixture(latitude: 200).validate(), throwsFormatException);
  });

  test('ArcGIS query pins dataset, requests raw values and cloud coverage', () {
    final provider = ArcGisViirsProvider();
    final uri = provider.identifyUri(
      latitude: 47.38,
      longitude: 8.54,
      rasterFunction: 'Average Monthly Radiance (Raw Values)',
    );
    final params = uri.queryParameters;
    expect(params['mosaicRule'], contains('year = 2025 AND month = 12'));
    expect(params['renderingRule'], contains('Raw Values'));
    expect(params['geometry'], contains('47.38'));
    expect(params['geometry'], contains('8.54'));
    provider.close();
  });

  test('ArcGIS rejects no data, invalid values and service error payloads', () {
    expect(ArcGisViirsProvider.parsePixel({'value': 'NoData'}), isNull);
    expect(ArcGisViirsProvider.parsePixel({'value': -9999}), isNull);
    expect(ArcGisViirsProvider.parsePixel({'value': 'Infinity'}), isNull);
    expect(ArcGisViirsProvider.parsePixel({'value': '0.0'}), 0);
    expect(
      () => ArcGisViirsProvider.parsePixel({
        'error': {'code': 403},
      }),
      throwsFormatException,
    );
  });

  test(
    'HTTP normalizes raw radiance, source, month and cloud-free coverage',
    () async {
      final functions = <String>[];
      final client = MockClient((request) async {
        final function = jsonDecode(
          request.url.queryParameters['renderingRule']!,
        ) as Map<String, dynamic>;
        final name = function['rasterFunction'] as String;
        functions.add(name);
        return http.Response(
          jsonEncode({
            'value': name == 'Monthly Cloud Free Observations' ? 8 : 2.75,
          }),
          200,
        );
      });
      final provider = ArcGisViirsProvider(client: client);
      final result = await provider.fetch(latitude: 47.38, longitude: 8.54);
      expect(result!.value, 2.75);
      expect(result.sourceName, contains('NOAA'));
      expect(result.datasetDate, DateTime.utc(2025, 12, 31));
      expect(result.description, contains('8 cloud-free'));
      expect(
        functions,
        containsAll([
          'Average Monthly Radiance (Raw Values)',
          'Monthly Cloud Free Observations',
        ]),
      );
      provider.close();
    },
  );

  test('zero cloud-free observations cannot imply a dark site', () async {
    final client = MockClient((request) async {
      final isCoverage = request.url.queryParameters['renderingRule']!.contains(
        'Cloud Free',
      );
      return http.Response(jsonEncode({'value': isCoverage ? 0 : 0.0}), 200);
    });
    final provider = ArcGisViirsProvider(client: client);
    expect(await provider.fetch(latitude: 47.38, longitude: 8.54), isNull);
    provider.close();
  });

  test(
    'cache persists, is location keyed and supports offline fallback',
    () async {
      final store = _MemoryStore();
      final provider = _FakeProvider(value: fixture());
      var now = DateTime.utc(2026, 11, 2);
      LightPollutionRepository repository() => LightPollutionRepository(
        provider: provider,
        cache: store,
        now: () => now,
        maximumAge: const Duration(days: 30),
      );
      final first = await repository().load(latitude: 47.38, longitude: 8.54);
      expect(first.fromCache, isFalse);
      expect(provider.calls, 1);
      provider.fail = true;
      final second = await repository().load(latitude: 47.38, longitude: 8.54);
      expect(second.fromCache, isTrue);
      expect(second.isStale, isFalse);
      expect(provider.calls, 1);
      now = now.add(const Duration(days: 31));
      final old = await repository().load(latitude: 47.38, longitude: 8.54);
      expect(old.isStale, isTrue);
      expect(old.refreshError, contains('offline'));
      expect(provider.calls, 2);
      await expectLater(
        repository().load(latitude: 47.39, longitude: 8.54),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'genuine no-data invalidates old entry, not silently keeps dark site',
    () async {
      final store = _MemoryStore();
      final provider = _FakeProvider(value: fixture());
      final repo = LightPollutionRepository(provider: provider, cache: store);
      await repo.load(latitude: 47.38, longitude: 8.54);
      provider.value = null;
      final result = await repo.load(
        latitude: 47.38,
        longitude: 8.54,
        forceRefresh: true,
      );
      expect(result.reading, isNull);
      expect(store.map, isEmpty);
    },
  );
}
