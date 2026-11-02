import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/open_meteo_weather_provider.dart';
import '../data/shared_preferences_weather_cache_repository.dart';
import '../domain/models/weather_cache.dart';
import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/providers/weather_provider.dart';
import '../domain/repositories/weather_cache_repository.dart';
import 'weather_forecast_service.dart';

/// Replaceable weather provider selection for application and tests.
final weatherProviderProvider = Provider<WeatherProvider>((ref) {
  final provider = OpenMeteoWeatherProvider();
  ref.onDispose(provider.close);
  return provider;
});

final weatherCacheRepositoryProvider = Provider<WeatherCacheRepository>((ref) {
  return SharedPreferencesWeatherCacheRepository();
});

final weatherCachePolicyProvider = Provider<WeatherCachePolicy>(
  (ref) => const WeatherCachePolicy(),
);

final weatherForecastServiceProvider = Provider<WeatherForecastService>((ref) {
  return WeatherForecastService(
    provider: ref.watch(weatherProviderProvider),
    cache: ref.watch(weatherCacheRepositoryProvider),
    policy: ref.watch(weatherCachePolicyProvider),
  );
});

/// Only retry transient failures when no cached fallback can be returned.
Duration? weatherForecastRetry(int retryCount, Object error) {
  if (error is! WeatherException || !error.isRetryable || retryCount >= 3) {
    return null;
  }
  return Duration(milliseconds: 200 * (1 << retryCount));
}

/// UI-facing result with provenance, staleness and optional refresh error.
final weatherForecastSnapshotProvider =
    FutureProvider.family<WeatherForecastSnapshot, WeatherForecastRequest>(
      (ref, request) => ref.watch(weatherForecastServiceProvider).load(request),
      retry: weatherForecastRetry,
    );

/// Backward-compatible forecast-only API. It now benefits from the cache.
final weatherForecastProvider =
    FutureProvider.family<WeatherForecast, WeatherForecastRequest>(
      (ref, request) async =>
          (await ref.watch(weatherForecastSnapshotProvider(request).future))
              .forecast,
      // The underlying snapshot provider owns retries; avoid nesting them.
      retry: (retryCount, error) => null,
    );
