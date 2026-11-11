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
    AsyncNotifierProvider.family<
      WeatherForecastSnapshotController,
      WeatherForecastSnapshot,
      WeatherForecastRequest
    >(WeatherForecastSnapshotController.new, retry: weatherForecastRetry);

final class WeatherForecastSnapshotController
    extends AsyncNotifier<WeatherForecastSnapshot> {
  WeatherForecastSnapshotController(this.request);

  final WeatherForecastRequest request;

  @override
  Future<WeatherForecastSnapshot> build() =>
      ref.watch(weatherForecastServiceProvider).load(request);

  Future<void> refreshForecast() async {
    if (state.isLoading) return;
    final refreshRef = ref;
    final service = refreshRef.read(weatherForecastServiceProvider);
    final previous = state.value;
    state = const AsyncLoading();
    final refreshed = await AsyncValue.guard(() async {
      final result = await service.load(request, forceRefresh: true);
      final error = result.refreshError;
      // A successful download can still be newer than the persisted cache.
      // Keep that in-memory forecast if the next refresh fails.
      if (error != null &&
          previous != null &&
          previous.forecast.fetchedAtUtc.isAfter(
            result.forecast.fetchedAtUtc,
          )) {
        throw error;
      }
      return result;
    });
    if (refreshRef.mounted) state = refreshed;
  }
}

/// Backward-compatible forecast-only API. It now benefits from the cache.
final weatherForecastProvider =
    FutureProvider.family<WeatherForecast, WeatherForecastRequest>(
      (ref, request) async =>
          (await ref.watch(weatherForecastSnapshotProvider(request).future))
              .forecast,
      // The underlying snapshot provider owns retries; avoid nesting them.
      retry: (retryCount, error) => null,
    );
