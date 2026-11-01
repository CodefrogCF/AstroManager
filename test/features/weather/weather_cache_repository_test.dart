import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/weather/data/shared_preferences_weather_cache_repository.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';
import 'package:astromanager/features/weather/domain/repositories/weather_cache_repository.dart';

final class FakeWeatherCacheStore implements WeatherCacheStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();
  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

WeatherForecastRequest requestAt(int day) => WeatherForecastRequest(
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
  startUtc: DateTime.utc(2026, 11, day, 18),
  endUtc: DateTime.utc(2026, 11, day + 1, 6),
);

WeatherForecast example(
  WeatherForecastRequest request, {
  String providerId = 'open-meteo',
  DateTime? fetched,
}) => WeatherForecast(
  provider: WeatherProviderMetadata(
    id: providerId,
    name: 'Open-Meteo',
    model: 'best_match',
    attribution: 'Weather data by Open-Meteo.com (CC BY 4.0)',
  ),
  latitudeDegrees: request.latitudeDegrees,
  longitudeDegrees: request.longitudeDegrees,
  issuedAtUtc: DateTime.utc(2026, 11, 1, 12),
  issuedAtIsEstimated: true,
  fetchedAtUtc: fetched ?? DateTime.utc(2026, 11, 1, 15),
  hours: [
    HourlyWeatherForecast(
      timeUtc: request.startUtc,
      totalCloudCoverPercent: const WeatherValue.available(0),
      lowCloudCoverPercent: const WeatherValue.missing(),
      midCloudCoverPercent: const WeatherValue.unavailable(
        'model not supported',
      ),
      highCloudCoverPercent: const WeatherValue.available(95),
      visibilityMeters: const WeatherValue.available(7000),
    ),
  ],
);

void main() {
  group('Persistent cache repository', () {
    test('round-trips complete forecast and original metadata', () async {
      final store = FakeWeatherCacheStore();
      final request = requestAt(1);
      final key = WeatherCacheKey(providerId: 'open-meteo', request: request);
      final forecast = example(request);
      await SharedPreferencesWeatherCacheRepository(store: store)
          .write(key, forecast);

      // A NEW repository instance reads the previously written cache.
      final loaded = await SharedPreferencesWeatherCacheRepository(store: store)
          .read(key);
      expect(loaded, isNotNull);
      expect(loaded!.issuedAtUtc, forecast.issuedAtUtc);
      expect(loaded.fetchedAtUtc, forecast.fetchedAtUtc);
      expect(loaded.issuedAtIsEstimated, isTrue);
      expect(loaded.provider.attribution, forecast.provider.attribution);
      expect(loaded.hours.single.totalCloudCoverPercent.value, 0);
      expect(loaded.hours.single.lowCloudCoverPercent.isMissing, isTrue);
      expect(loaded.hours.single.midCloudCoverPercent.isUnavailable, isTrue);
      expect(
        loaded.hours.single.midCloudCoverPercent.reason,
        'model not supported',
      );
      expect(loaded.hours.single.highCloudCoverPercent.value, 95);
    });

    test('keys isolate provider, location and exact forecast window', () async {
      final store = FakeWeatherCacheStore();
      final request = requestAt(1);
      final cache = SharedPreferencesWeatherCacheRepository(store: store);
      await cache.write(
        WeatherCacheKey(providerId: 'open-meteo', request: request),
        example(request),
      );
      expect(
        await cache.read(
          WeatherCacheKey(providerId: 'other', request: request),
        ),
        isNull,
      );
      expect(
        await cache.read(
          WeatherCacheKey(
            providerId: 'open-meteo',
            model: 'icon_eu',
            request: request,
          ),
        ),
        isNull,
      );
      expect(
        await cache.read(
          WeatherCacheKey(providerId: 'open-meteo', request: requestAt(2)),
        ),
        isNull,
      );
      final elsewhere = WeatherForecastRequest(
        latitudeDegrees: 47.49,
        longitudeDegrees: request.longitudeDegrees,
        startUtc: request.startUtc,
        endUtc: request.endUtc,
      );
      expect(
        await cache.read(
          WeatherCacheKey(providerId: 'open-meteo', request: elsewhere),
        ),
        isNull,
      );
    });

    test(
      'corrupted entries are discarded without surfacing false weather',
      () async {
        final store = FakeWeatherCacheStore();
        final key = WeatherCacheKey(
          providerId: 'open-meteo',
          request: requestAt(1),
        );
        store.values[key.storageKey] = '{broken-json';
        final cache = SharedPreferencesWeatherCacheRepository(store: store);
        expect(await cache.read(key), isNull);
        expect(store.values.containsKey(key.storageKey), isFalse);
      },
    );

    test('keeps only the configured number of newest entries', () async {
      final store = FakeWeatherCacheStore();
      final cache = SharedPreferencesWeatherCacheRepository(
        store: store,
        maximumEntries: 2,
      );
      for (var day = 1; day <= 3; day++) {
        final request = requestAt(day);
        await cache.write(
          WeatherCacheKey(providerId: 'open-meteo', request: request),
          example(request, fetched: DateTime.utc(2026, 11, day, 17)),
        );
      }
      expect(
        await cache.read(
          WeatherCacheKey(providerId: 'open-meteo', request: requestAt(1)),
        ),
        isNull,
      );
      expect(
        await cache.read(
          WeatherCacheKey(providerId: 'open-meteo', request: requestAt(2)),
        ),
        isNotNull,
      );
      expect(
        await cache.read(
          WeatherCacheKey(providerId: 'open-meteo', request: requestAt(3)),
        ),
        isNotNull,
      );
      expect(store.values, hasLength(2));
    });

    test('clear does not remove unrelated application preferences', () async {
      final store = FakeWeatherCacheStore();
      store.values['unrelated.setting'] = 'keep';
      final cache = SharedPreferencesWeatherCacheRepository(store: store);
      final request = requestAt(1);
      await cache.write(
        WeatherCacheKey(providerId: 'open-meteo', request: request),
        example(request),
      );
      await cache.clear();
      expect(store.values, {'unrelated.setting': 'keep'});
    });
  });
}
