import 'dart:async';

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
  final service = WeatherForecastService(
    provider: ref.watch(weatherProviderProvider),
    cache: ref.watch(weatherCacheRepositoryProvider),
    policy: ref.watch(weatherCachePolicyProvider),
  );
  ref.onDispose(service.dispose);
  return service;
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

/// For screens that calculate with an awaited snapshot. The initial load
/// already resolves their pending calculation, and a failure retains its data.
bool weatherForecastWasUpdated(
  AsyncValue<WeatherForecastSnapshot>? previous,
  AsyncValue<WeatherForecastSnapshot> next,
) {
  final update = next.asData?.value;
  if (update == null || update.refreshError != null || previous == null) {
    return false;
  }
  final prior = previous.value;
  if (prior == null) return !previous.isLoading;
  return update.forecast.fetchedAtUtc.isAfter(prior.forecast.fetchedAtUtc);
}

final class WeatherForecastSnapshotController
    extends AsyncNotifier<WeatherForecastSnapshot> {
  WeatherForecastSnapshotController(this.request);

  final WeatherForecastRequest request;

  @override
  Future<WeatherForecastSnapshot> build() {
    final service = ref.watch(weatherForecastServiceProvider);
    final subscription = service.manualRefreshesFor(request).listen((snapshot) {
      final previous = state.value;
      if (previous == null ||
          snapshot.forecast.fetchedAtUtc.isAfter(
            previous.forecast.fetchedAtUtc,
          )) {
        state = AsyncData(snapshot);
      }
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return service.load(request);
  }

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
      final latest = refreshRef.mounted ? state.value ?? previous : previous;
      if (latest != null &&
          latest.forecast.fetchedAtUtc.isAfter(result.forecast.fetchedAtUtc)) {
        if (error != null) throw error;
        return latest;
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
