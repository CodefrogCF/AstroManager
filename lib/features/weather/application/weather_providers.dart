import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/open_meteo_weather_provider.dart';
import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/providers/weather_provider.dart';

/// A weather source can still be replaced using a Riverpod override.
/// The default live provider is Open-Meteo (non-commercial API).
final weatherProviderProvider = Provider<WeatherProvider>((ref) {
  final provider = OpenMeteoWeatherProvider();
  ref.onDispose(provider.close);
  return provider;
});

/// Retry only transient weather errors. Non-retryable errors (including
/// unconfigured providers, authentication errors and malformed responses)
/// must not hang the UI or tests in a loading state.
Duration? weatherForecastRetry(int retryCount, Object error) {
  if (error is! WeatherException || !error.isRetryable || retryCount >= 3) {
    return null;
  }
  return Duration(milliseconds: 200 * (1 << retryCount));
}

final weatherForecastProvider =
    FutureProvider.family<WeatherForecast, WeatherForecastRequest>(
      (ref, request) =>
          ref.watch(weatherProviderProvider).fetchForecast(request),
      retry: weatherForecastRetry,
    );
