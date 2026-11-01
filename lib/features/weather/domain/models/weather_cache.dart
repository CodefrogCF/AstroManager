import 'weather_error.dart';
import 'weather_forecast.dart';

/// Freshness is calculated at read time, never serialized as a permanent flag.
final class WeatherCachePolicy {
  const WeatherCachePolicy({
    this.maximumAge = const Duration(hours: 1),
    this.maximumKnownIssueAge = const Duration(hours: 12),
    this.maximumFallbackAge,
  });

  /// How long a retrieved forecast may be reused without contacting the API.
  final Duration maximumAge;

  /// Limit for a *known* model publication time. Estimated issue times are
  /// explicitly not treated as authoritative publication timestamps.
  final Duration maximumKnownIssueAge;

  /// Optional limit on offline fallback; null permits clearly marked stale
  /// data to remain accessible regardless of age.
  final Duration? maximumFallbackAge;

  bool isFresh(WeatherForecast forecast, DateTime now) {
    if (maximumAge.isNegative || maximumKnownIssueAge.isNegative) {
      throw ArgumentError('Weather cache age limits must not be negative.');
    }
    final instant = now.toUtc();
    final fetchedAge = instant.difference(forecast.fetchedAtUtc);
    if (fetchedAge.isNegative || fetchedAge >= maximumAge) return false;
    if (!forecast.issuedAtIsEstimated) {
      final issueAge = instant.difference(forecast.issuedAtUtc);
      if (issueAge.isNegative || issueAge >= maximumKnownIssueAge) {
        return false;
      }
    }
    return true;
  }

  bool mayFallback(WeatherForecast forecast, DateTime now) {
    final limit = maximumFallbackAge;
    if (limit == null) return true;
    if (limit.isNegative) return false;
    final age = now.toUtc().difference(forecast.fetchedAtUtc);
    return !age.isNegative && age <= limit;
  }
}

enum WeatherForecastOrigin {
  /// Downloaded and validated during this request.
  network,

  /// Reused a fresh local forecast without an API request.
  freshCache,

  /// Stale forecast shown immediately while an in-app refresh is attempted.
  staleCache,

  /// A refresh failed, so previously stored data is shown with a warning.
  staleFallback,
}

/// The UI must use this wrapper rather than infer freshness from the data.
/// The underlying WeatherForecast always retains its original timestamps.
final class WeatherForecastSnapshot {
  const WeatherForecastSnapshot({
    required this.forecast,
    required this.origin,
    required this.checkedAtUtc,
    required this.isStale,
    this.refreshInProgress = false,
    this.refreshError,
  });

  final WeatherForecast forecast;
  final WeatherForecastOrigin origin;
  final DateTime checkedAtUtc;
  final bool isStale;
  final bool refreshInProgress;
  final WeatherException? refreshError;

  /// Re-evaluate freshness when rendering after the original load, to avoid
  /// treating a long-lived Riverpod result as permanently fresh.
  bool isStaleAt(DateTime now, WeatherCachePolicy policy) =>
      !policy.isFresh(forecast, now);

  bool get isOfflineFallback => origin == WeatherForecastOrigin.staleFallback;
  bool get isFromCache => origin != WeatherForecastOrigin.network;
  Duration get age {
    final value = checkedAtUtc.difference(forecast.fetchedAtUtc);
    return value.isNegative ? Duration.zero : value;
  }
}
