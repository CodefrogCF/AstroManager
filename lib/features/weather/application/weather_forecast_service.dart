import 'dart:async';

import '../domain/models/weather_cache.dart';
import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/providers/weather_provider.dart';
import '../domain/repositories/weather_cache_repository.dart';

/// Coordinates caching and network refresh without depending on Flutter.
/// No timers or OS background tasks: any refresh is scoped to the app process.
final class WeatherForecastService {
  WeatherForecastService({
    required this.provider,
    required this.cache,
    this.policy = const WeatherCachePolicy(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WeatherProvider provider;
  final WeatherCacheRepository cache;
  final WeatherCachePolicy policy;
  final DateTime Function() _clock;

  /// One API request per exact key, even with concurrent callers.
  final Map<WeatherCacheKey, Future<WeatherForecast>> _refreshes = {};

  /// Returns a freshness-tagged forecast. Stale data is NEVER marked fresh.
  ///
  /// If [staleWhileRevalidate] is enabled, stale cached data is returned
  /// immediately and a safely handled refresh starts in the running app.
  /// Call [load] again after the refresh to obtain the latest cached result.
  Future<WeatherForecastSnapshot> load(
    WeatherForecastRequest request, {
    bool forceRefresh = false,
    bool staleWhileRevalidate = false,
  }) async {
    request.validate();
    final key = _cacheKey(request);
    final stored = await _readSafe(key);
    final now = _clock().toUtc();
    final fresh = stored != null && policy.isFresh(stored, now);

    if (fresh && !forceRefresh) {
      return _snapshot(stored, WeatherForecastOrigin.freshCache, now);
    }

    if (stored != null &&
        !fresh &&
        !forceRefresh &&
        staleWhileRevalidate &&
        policy.mayFallback(stored, now)) {
      // Handle the future's error even when nobody explicitly awaits it.
      unawaited(
        _refreshOnce(
          key,
          request,
        ).then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
      );
      return _snapshot(
        stored,
        WeatherForecastOrigin.staleCache,
        now,
        refreshInProgress: true,
      );
    }

    try {
      final downloaded = await _refreshOnce(key, request);
      return _snapshot(
        downloaded,
        WeatherForecastOrigin.network,
        _clock().toUtc(),
      );
    } catch (error) {
      final weatherError = error is WeatherException
          ? error
          : WeatherException(
              type: WeatherErrorType.unknown,
              message: 'Weather refresh failed unexpectedly.',
              providerId: provider.metadata.id,
              cause: error,
            );
      if (stored != null && policy.mayFallback(stored, _clock())) {
        final stale = !policy.isFresh(stored, _clock());
        return _snapshot(
          stored,
          stale
              ? WeatherForecastOrigin.staleFallback
              : WeatherForecastOrigin.freshCache,
          _clock().toUtc(),
          refreshError: weatherError,
        );
      }
      throw weatherError;
    }
  }

  /// Reads a previously requested window for use when a wider request fails.
  Future<WeatherForecastSnapshot?> cachedFallback(
    WeatherForecastRequest request,
  ) async {
    request.validate();
    final stored = await _readSafe(_cacheKey(request));
    final now = _clock().toUtc();
    if (stored == null || !policy.mayFallback(stored, now)) return null;
    return _snapshot(
      stored,
      policy.isFresh(stored, now)
          ? WeatherForecastOrigin.freshCache
          : WeatherForecastOrigin.staleFallback,
      now,
    );
  }

  WeatherCacheKey _cacheKey(WeatherForecastRequest request) => WeatherCacheKey(
    providerId: provider.metadata.id,
    model: provider.metadata.model,
    request: request,
  );

  Future<WeatherForecast?> _readSafe(WeatherCacheKey key) async {
    try {
      return await cache.read(key);
    } catch (_) {
      // An unavailable cache must not prevent online operation.
      return null;
    }
  }

  Future<WeatherForecast> _refreshOnce(
    WeatherCacheKey key,
    WeatherForecastRequest request,
  ) {
    final pending = _refreshes[key];
    if (pending != null) return pending;

    final completer = Completer<WeatherForecast>();
    _refreshes[key] = completer.future;
    // Start in a microtask rather than deferring to the next event-loop turn.
    // This lets same-key callers share the registered in-flight request even
    // when an earlier caller has not yet reached the HTTP invocation.
    Future<void>.microtask(() async {
      try {
        final forecast = await provider.fetchForecast(request);
        forecast.validate();
        if (forecast.provider.id != key.providerId) {
          throw WeatherException(
            type: WeatherErrorType.invalidResponse,
            message: 'Weather source differs from the selected provider.',
            providerId: key.providerId,
          );
        }
        try {
          await cache.write(key, forecast);
        } catch (_) {
          // Persistence failure does not invalidate a network forecast.
        }
        completer.complete(forecast);
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _refreshes.remove(key);
      }
    });
    return completer.future;
  }

  WeatherForecastSnapshot _snapshot(
    WeatherForecast forecast,
    WeatherForecastOrigin origin,
    DateTime checkedAtUtc, {
    bool refreshInProgress = false,
    WeatherException? refreshError,
  }) => WeatherForecastSnapshot(
    forecast: forecast,
    origin: origin,
    checkedAtUtc: checkedAtUtc,
    isStale: !policy.isFresh(forecast, checkedAtUtc),
    refreshInProgress: refreshInProgress,
    refreshError: refreshError,
  );
}
