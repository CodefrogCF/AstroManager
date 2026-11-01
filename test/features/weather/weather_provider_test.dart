import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/data/mock_weather_provider.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';
import 'package:astromanager/features/weather/domain/repositories/weather_cache_repository.dart';

const mockMetadata = WeatherProviderMetadata(
  id: 'mock',
  name: 'Mock Sky Forecast',
);

final request = WeatherForecastRequest(
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
  startUtc: DateTime.utc(2026, 11, 1, 20),
  endUtc: DateTime.utc(2026, 11, 2, 6),
);

WeatherForecast response(WeatherForecastRequest request) => WeatherForecast(
  provider: mockMetadata,
  latitudeDegrees: request.latitudeDegrees,
  longitudeDegrees: request.longitudeDegrees,
  issuedAtUtc: DateTime.utc(2026, 11, 1, 18),
  fetchedAtUtc: DateTime.utc(2026, 11, 1, 19),
  hours: [
    HourlyWeatherForecast(
      timeUtc: DateTime.utc(2026, 11, 1, 22),
      totalCloudCoverPercent: const WeatherValue.available(0),
      highCloudCoverPercent: const WeatherValue.unavailable('not provided'),
    ),
  ],
);

/// Isolates provider-contract tests from platform-backed persistence.
final class _MemoryWeatherCache implements WeatherCacheRepository {
  final Map<WeatherCacheKey, WeatherForecast> _entries = {};

  @override
  Future<WeatherForecast?> read(WeatherCacheKey key) async => _entries[key];

  @override
  Future<void> write(WeatherCacheKey key, WeatherForecast forecast) async {
    _entries[key] = forecast;
  }

  @override
  Future<void> remove(WeatherCacheKey key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}

void main() {
  group('Weather provider contract', () {
    test('mock returns normalized data and records requests', () async {
      final mock = MockWeatherProvider(
        metadata: mockMetadata,
        respond: response,
      );
      final result = await mock.fetchForecast(request);
      expect(mock.requests, [request]);
      expect(result.provider.id, 'mock');
      expect(result.hours.single.totalCloudCoverPercent.value, 0);
      expect(result.hours.single.highCloudCoverPercent.isUnavailable, isTrue);
    });

    test('provider can be replaced without modifying consumers', () async {
      final mock = MockWeatherProvider(
        metadata: mockMetadata,
        respond: response,
      );
      final container = ProviderContainer.test(
        overrides: [
          weatherProviderProvider.overrideWith((ref) => mock),
          weatherCacheRepositoryProvider.overrideWith(
            (ref) => _MemoryWeatherCache(),
          ),
        ],
      );
      final forecast = await container.read(
        weatherForecastProvider(request).future,
      );
      expect(forecast.provider.name, 'Mock Sky Forecast');
      expect(mock.requests, hasLength(1));
    });

    test('without a configured provider the failure is typed', () async {
      final container = ProviderContainer.test(
        overrides: [
          weatherProviderProvider.overrideWith(
            (ref) => const UnconfiguredWeatherProvider(),
          ),
          weatherCacheRepositoryProvider.overrideWith(
            (ref) => _MemoryWeatherCache(),
          ),
        ],
      );
      await expectLater(
        container.read(weatherForecastProvider(request).future),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.notConfigured,
          ),
        ),
      );
    });

    test('mock can simulate a rate-limited provider', () async {
      final mock = MockWeatherProvider(
        metadata: mockMetadata,
        respond: response,
        failure: const WeatherException(
          type: WeatherErrorType.rateLimited,
          message: 'Rate limit exceeded.',
          providerId: 'mock',
          retryAfter: Duration(minutes: 5),
        ),
      );
      await expectLater(
        mock.fetchForecast(request),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(minutes: 5),
          ),
        ),
      );
      expect(mock.requests, hasLength(1));
    });

    test('invalid requests are rejected before provider execution', () async {
      final invalid = WeatherForecastRequest(
        latitudeDegrees: double.nan,
        longitudeDegrees: 8,
        startUtc: request.startUtc,
        endUtc: request.endUtc,
      );
      final mock = MockWeatherProvider(
        metadata: mockMetadata,
        respond: response,
      );
      await expectLater(
        mock.fetchForecast(invalid),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.invalidRequest,
          ),
        ),
      );
      expect(mock.requests, isEmpty);
    });

    test('non-UTC or reversed windows are rejected', () {
      final localTime = WeatherForecastRequest(
        latitudeDegrees: 47,
        longitudeDegrees: 8,
        startUtc: DateTime(2026, 11, 1, 20),
        endUtc: DateTime.utc(2026, 11, 2, 6),
      );
      final reverse = WeatherForecastRequest(
        latitudeDegrees: 47,
        longitudeDegrees: 8,
        startUtc: request.endUtc,
        endUtc: request.startUtc,
      );
      expect(localTime.validate, throwsA(isA<WeatherException>()));
      expect(reverse.validate, throwsA(isA<WeatherException>()));
    });

    test('provider failures indicate whether retry can help', () {
      expect(
        const WeatherException(
          type: WeatherErrorType.network,
          message: 'Offline',
        ).isRetryable,
        isTrue,
      );
      expect(
        const WeatherException(
          type: WeatherErrorType.authentication,
          message: 'Invalid key',
        ).isRetryable,
        isFalse,
      );
      expect(
        const WeatherException(
          type: WeatherErrorType.invalidResponse,
          message: 'Malformed data',
        ).isRetryable,
        isFalse,
      );
    });
  });
}
