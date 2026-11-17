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

  static const storagePrefix = 'astromanager.weather.v1.';

  String get storageKey {
    final parts = [
      providerId,
      model,
      request.latitudeDegrees,
      request.longitudeDegrees,
      request.startUtc.microsecondsSinceEpoch,
      request.endUtc.microsecondsSinceEpoch,
    ];
    return '$storagePrefix${base64Url.encode(utf8.encode(jsonEncode(parts)))}';
  }

  static WeatherCacheKey? tryParseStorageKey(String name) {
    if (!name.startsWith(storagePrefix)) return null;
    try {
      final parts = jsonDecode(
        utf8.decode(base64Url.decode(name.substring(storagePrefix.length))),
      );
      if (parts case [
        String providerId,
        String? model,
        num latitude,
        num longitude,
        int start,
        int end,
      ]) {
        return WeatherCacheKey(
          providerId: providerId,
          model: model,
          request: WeatherForecastRequest(
            latitudeDegrees: latitude.toDouble(),
            longitudeDegrees: longitude.toDouble(),
            startUtc: DateTime.fromMicrosecondsSinceEpoch(start, isUtc: true),
            endUtc: DateTime.fromMicrosecondsSinceEpoch(end, isUtc: true),
          ),
        );
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    return null;
  }

  bool covers(WeatherCacheKey other) =>
      providerId == other.providerId &&
      model == other.model &&
      request.latitudeDegrees == other.request.latitudeDegrees &&
      request.longitudeDegrees == other.request.longitudeDegrees &&
      !request.startUtc.isAfter(other.request.startUtc) &&
      !request.endUtc.isBefore(other.request.endUtc);

  /// Reuses a wider forecast only if its response actually contains every
  /// hourly sample in the requested window. Exact cache hits may be partial.
  WeatherForecast? forecastFor(
    WeatherCacheKey other,
    WeatherForecast forecast,
  ) {
    if (this == other) return forecast;
    if (!covers(other)) return null;

    final start = other.request.startUtc;
    final end = other.request.endUtc;
    final hours = forecast.hours
        .where(
          (hour) => !hour.timeUtc.isBefore(start) && hour.timeUtc.isBefore(end),
        )
        .toList();
    if (hours.isEmpty) return null;

    // Match the provider's [start, end) UTC timestamp filter, including for
    // observing sites whose local noon falls between UTC hour boundaries.
    const hour = Duration(hours: 1);
    final first = hours.first.timeUtc;
    if (first.subtract(hour).isBefore(start) &&
        !hours.last.timeUtc.add(hour).isBefore(end) &&
        hours.last.timeUtc.difference(first).inHours == hours.length - 1) {
      return WeatherForecast(
        provider: forecast.provider,
        latitudeDegrees: forecast.latitudeDegrees,
        longitudeDegrees: forecast.longitudeDegrees,
        issuedAtUtc: forecast.issuedAtUtc,
        issuedAtIsEstimated: forecast.issuedAtIsEstimated,
        fetchedAtUtc: forecast.fetchedAtUtc,
        hours: hours,
      );
    }
    return null;
  }

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
  /// Returns the most recently fetched exact or fully covering forecast.
  Future<WeatherForecast?> read(WeatherCacheKey key);
  Future<void> write(WeatherCacheKey key, WeatherForecast forecast);
  Future<void> remove(WeatherCacheKey key);
  Future<void> clear();
}
