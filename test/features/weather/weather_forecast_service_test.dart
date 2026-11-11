import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/weather/application/weather_forecast_service.dart';
import 'package:astromanager/features/weather/application/weather_providers.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';

import '../../support/weather_fakes.dart';

final request = WeatherForecastRequest(
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
  startUtc: DateTime.utc(2026, 11, 1, 18),
  endUtc: DateTime.utc(2026, 11, 2, 6),
);

WeatherForecast sample(DateTime fetched) => WeatherForecast(
  provider: const WeatherProviderMetadata(id: 'mock', name: 'Mock'),
  latitudeDegrees: request.latitudeDegrees,
  longitudeDegrees: request.longitudeDegrees,
  issuedAtUtc: fetched.subtract(const Duration(minutes: 20)),
  fetchedAtUtc: fetched,
  hours: [
    HourlyWeatherForecast(
      timeUtc: request.startUtc,
      totalCloudCoverPercent: const WeatherValue.available(80),
    ),
  ],
);

const offline = WeatherException(
  type: WeatherErrorType.network,
  message: 'Offline',
  providerId: 'mock',
);

void main() {
  group('Weather cache policy', () {
    test('freshness expires at the exact threshold', () {
      final forecast = sample(DateTime.utc(2026, 11, 1, 17));
      const policy = WeatherCachePolicy(maximumAge: Duration(hours: 1));
      expect(
        policy.isFresh(forecast, DateTime.utc(2026, 11, 1, 17, 59)),
        isTrue,
      );
      expect(policy.isFresh(forecast, DateTime.utc(2026, 11, 1, 18)), isFalse);
    });

    test('a known old issue time makes a recently fetched forecast stale', () {
      final fetched = DateTime.utc(2026, 11, 2, 18);
      final forecast = WeatherForecast(
        provider: const WeatherProviderMetadata(id: 'mock', name: 'Mock'),
        latitudeDegrees: request.latitudeDegrees,
        longitudeDegrees: request.longitudeDegrees,
        issuedAtUtc: fetched.subtract(const Duration(days: 2)),
        fetchedAtUtc: fetched,
        hours: [HourlyWeatherForecast(timeUtc: request.startUtc)],
      );
      const policy = WeatherCachePolicy();
      expect(
        policy.isFresh(forecast, fetched.add(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('configurable maximum fallback age rejects excessively old data', () {
      const policy = WeatherCachePolicy(maximumFallbackAge: Duration(hours: 6));
      final forecast = sample(DateTime.utc(2026, 11, 1, 12));
      expect(
        policy.mayFallback(forecast, DateTime.utc(2026, 11, 1, 17)),
        isTrue,
      );
      expect(
        policy.mayFallback(forecast, DateTime.utc(2026, 11, 1, 19)),
        isFalse,
      );
    });

    test('a clock rollback cannot label a forecast fresh', () {
      const policy = WeatherCachePolicy();
      expect(
        policy.isFresh(
          sample(DateTime.utc(2026, 11, 1, 18)),
          DateTime.utc(2026, 11, 1, 17),
        ),
        isFalse,
      );
    });
  });

  group('Weather forecast service', () {
    test('first call downloads, second uses fresh cache', () async {
      final now = DateTime.utc(2026, 11, 1, 18);
      final provider = ControlledWeatherProvider((_) async => sample(now));
      final service = WeatherForecastService(
        provider: provider,
        cache: MemoryWeatherCache(),
        clock: () => now,
      );
      final first = await service.load(request);
      final second = await service.load(request);
      expect(first.origin, WeatherForecastOrigin.network);
      expect(second.origin, WeatherForecastOrigin.freshCache);
      expect(second.isStale, isFalse);
      expect(provider.calls, 1);
    });

    test(
      'refresh failure preserves stale data and original timestamps',
      () async {
        var now = DateTime.utc(2026, 11, 1, 18);
        final provider = ControlledWeatherProvider((_) async => sample(now));
        final cache = MemoryWeatherCache();
        final service = WeatherForecastService(
          provider: provider,
          cache: cache,
          clock: () => now,
        );
        final first = await service.load(request);
        now = now.add(const Duration(hours: 3));
        provider.respond = (_) async => throw offline;
        final result = await service.load(request);
        expect(result.origin, WeatherForecastOrigin.staleFallback);
        expect(result.isStale, isTrue);
        expect(result.isOfflineFallback, isTrue);
        expect(result.refreshError!.type, WeatherErrorType.network);
        expect(result.forecast.fetchedAtUtc, first.forecast.fetchedAtUtc);
        expect(result.forecast.issuedAtUtc, first.forecast.issuedAtUtc);
        expect(result.forecast.hours.single.totalCloudCoverPercent.value, 80);
      },
    );

    test('no cached forecast propagates typed network failure', () async {
      final provider = ControlledWeatherProvider((_) async => throw offline);
      final service = WeatherForecastService(
        provider: provider,
        cache: MemoryWeatherCache(),
      );
      await expectLater(
        service.load(request),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.network,
          ),
        ),
      );
    });

    test('concurrent requests share exactly one HTTP fetch', () async {
      final pending = Completer<WeatherForecast>();
      final now = DateTime.utc(2026, 11, 1, 18);
      final provider = ControlledWeatherProvider((_) => pending.future);
      final service = WeatherForecastService(
        provider: provider,
        cache: MemoryWeatherCache(),
        clock: () => now,
      );
      final first = service.load(request);
      final second = service.load(request);
      await Future<void>.delayed(Duration.zero);
      expect(provider.calls, 1);
      pending.complete(sample(now));
      expect((await first).forecast.fetchedAtUtc, now);
      expect((await second).forecast.fetchedAtUtc, now);
      expect(provider.calls, 1);
    });

    test(
      'stale-while-revalidate returns old data before refresh finishes',
      () async {
        var now = DateTime.utc(2026, 11, 1, 18);
        final pending = Completer<WeatherForecast>();
        final provider = ControlledWeatherProvider((_) async => sample(now));
        final service = WeatherForecastService(
          provider: provider,
          cache: MemoryWeatherCache(),
          clock: () => now,
        );
        await service.load(request);
        now = now.add(const Duration(hours: 4));
        provider.respond = (_) => pending.future;
        final stale = await service.load(request, staleWhileRevalidate: true);
        expect(stale.origin, WeatherForecastOrigin.staleCache);
        expect(stale.isStale, isTrue);
        expect(stale.refreshInProgress, isTrue);
        pending.complete(sample(now));
        await Future<void>.delayed(Duration.zero);
        final fresh = await service.load(request);
        expect(fresh.isStale, isFalse);
        expect(provider.calls, 2);
      },
    );

    test('Riverpod exposes full provenance and keeps legacy API', () async {
      final now = DateTime.utc(2026, 11, 1, 18);
      final mock = ControlledWeatherProvider((_) async => sample(now));
      final cache = MemoryWeatherCache();
      final container = ProviderContainer.test(
        overrides: [
          weatherProviderProvider.overrideWith((ref) => mock),
          weatherCacheRepositoryProvider.overrideWith((ref) => cache),
          weatherForecastServiceProvider.overrideWith(
            (ref) => WeatherForecastService(
              provider: ref.watch(weatherProviderProvider),
              cache: ref.watch(weatherCacheRepositoryProvider),
              clock: () => now,
            ),
          ),
        ],
      );
      final snapshot = await container.read(
        weatherForecastSnapshotProvider(request).future,
      );
      final forecast = await container.read(
        weatherForecastProvider(request).future,
      );
      expect(snapshot.origin, WeatherForecastOrigin.network);
      expect(forecast.provider.id, 'mock');
      expect(mock.calls, 1);
    });
  });
}
