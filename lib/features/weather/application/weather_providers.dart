import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_weather_provider.dart';
import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/providers/weather_provider.dart';

/// Switch weather sources here (or override in tests), never inside widgets.
/// Issue #15 deliberately has no network-backed default implementation.
final weatherProviderProvider = Provider<WeatherProvider>(
  (ref) => const UnconfiguredWeatherProvider(),
);

/// Retry only transient weather errors. Permanent errors (including a missing
/// provider configuration) must be reported immediately instead of leaving
/// the forecast in a loading state.
Duration? weatherForecastRetry(int retryCount, Object error) {
  if (error is! WeatherException || !error.isRetryable || retryCount >= 3) {
    return null;
  }

  return Duration(milliseconds: 200 * (1 << retryCount));
}

/// Future provider keyed by the absolute UTC observation window and location.
final weatherForecastProvider =
    FutureProvider.family<WeatherForecast, WeatherForecastRequest>((
      ref,
      request,
    ) {
      final provider = ref.watch(weatherProviderProvider);
      return provider.fetchForecast(request);
    }, retry: weatherForecastRetry);
