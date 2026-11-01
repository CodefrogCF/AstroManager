import 'dart:convert';

import '../models/weather_forecast.dart';
import '../providers/weather_provider.dart';

/// A cache key is an exact request window, geographic point and source ID.
/// It intentionally does not mix forecasts from different providers/models.
final class WeatherCacheKey {
  const WeatherCacheKey({
    required this.providerId,
    required this.request,
    this.model,
  });

  final String providerId;
  final String? model;
  final WeatherForecastRequest request;

  String get storageKey =>
      'astromanager.weather.v1.'
      '${base64Url.encode(utf8.encode(jsonEncode([providerId, model, request.latitudeDegrees, request.longitudeDegrees, request.startUtc.microsecondsSinceEpoch, request.endUtc.microsecondsSinceEpoch])))}';

  @override
  bool operator ==(Object other) =>
      other is WeatherCacheKey &&
      other.providerId == providerId &&
      other.model == model &&
      other.request == request;

  @override
  int get hashCode => Object.hash(providerId, model, request);
}

abstract interface class WeatherCacheRepository {
  Future<WeatherForecast?> read(WeatherCacheKey key);
  Future<void> write(WeatherCacheKey key, WeatherForecast forecast);
  Future<void> remove(WeatherCacheKey key);
  Future<void> clear();
}
