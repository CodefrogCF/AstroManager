import 'dart:convert';

import '../domain/models/weather_forecast.dart';
import '../domain/models/weather_value.dart';
import '../domain/repositories/weather_cache_repository.dart';

/// Versioned JSON serialization without silently inventing missing readings.
abstract final class WeatherForecastCodec {
  static const schemaVersion = 1;

  static String encode(WeatherCacheKey key, WeatherForecast forecast) {
    forecast.validate();
    return jsonEncode({
      'schema': schemaVersion,
      'key': {
        'providerId': key.providerId,
        'model': key.model,
        'latitude': key.request.latitudeDegrees,
        'longitude': key.request.longitudeDegrees,
        'startUtc': _date(key.request.startUtc),
        'endUtc': _date(key.request.endUtc),
      },
      'provider': {
        'id': forecast.provider.id,
        'name': forecast.provider.name,
        'model': forecast.provider.model,
        'attribution': forecast.provider.attribution,
        'homepageUrl': forecast.provider.homepageUrl,
      },
      'latitude': forecast.latitudeDegrees,
      'longitude': forecast.longitudeDegrees,
      'issuedAtUtc': _date(forecast.issuedAtUtc),
      'issuedAtIsEstimated': forecast.issuedAtIsEstimated,
      'fetchedAtUtc': _date(forecast.fetchedAtUtc),
      'hours': [
        for (final hour in forecast.hours)
          {
            'timeUtc': _date(hour.timeUtc),
            'totalCloud': _value(hour.totalCloudCoverPercent),
            'lowCloud': _value(hour.lowCloudCoverPercent),
            'midCloud': _value(hour.midCloudCoverPercent),
            'highCloud': _value(hour.highCloudCoverPercent),
            'precipitation': _value(hour.precipitationMillimeters),
            'precipitationProbability': _value(
              hour.precipitationProbabilityPercent,
            ),
            'windSpeed': _value(hour.windSpeedMetersPerSecond),
            'windGust': _value(hour.windGustMetersPerSecond),
            'windDirection': _value(hour.windDirectionDegrees),
            'humidity': _value(hour.relativeHumidityPercent),
            'visibility': _value(hour.visibilityMeters),
          },
      ],
    });
  }

  static WeatherForecast decode(String source, WeatherCacheKey expectedKey) {
    try {
      final root = _object(jsonDecode(source));
      if (root['schema'] != schemaVersion) {
        throw const FormatException('Unsupported weather cache schema.');
      }
      final key = _object(root['key']);
      if (key['providerId'] != expectedKey.providerId ||
          key['model'] != expectedKey.model ||
          _number(key['latitude']) != expectedKey.request.latitudeDegrees ||
          _number(key['longitude']) != expectedKey.request.longitudeDegrees ||
          _utc(key['startUtc']) != expectedKey.request.startUtc ||
          _utc(key['endUtc']) != expectedKey.request.endUtc) {
        throw const FormatException('Weather cache key mismatch.');
      }
      final provider = _object(root['provider']);
      final rawHours = root['hours'];
      if (rawHours is! List) {
        throw const FormatException('Invalid weather cache hours.');
      }
      final forecast = WeatherForecast(
        provider: WeatherProviderMetadata(
          id: _string(provider['id']),
          name: _string(provider['name']),
          model: _optionalString(provider['model']),
          attribution: _optionalString(provider['attribution']),
          homepageUrl: _optionalString(provider['homepageUrl']),
        ),
        latitudeDegrees: _number(root['latitude']),
        longitudeDegrees: _number(root['longitude']),
        issuedAtUtc: _utc(root['issuedAtUtc']),
        issuedAtIsEstimated: _boolean(root['issuedAtIsEstimated']),
        fetchedAtUtc: _utc(root['fetchedAtUtc']),
        hours: [for (final raw in rawHours) _hour(_object(raw))],
      );
      if (forecast.provider.id != expectedKey.providerId) {
        throw const FormatException(
          'Forecast source does not match cache key.',
        );
      }
      return forecast;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid cached weather forecast: $error');
    }
  }

  static HourlyWeatherForecast _hour(Map<String, dynamic> data) =>
      HourlyWeatherForecast(
        timeUtc: _utc(data['timeUtc']),
        totalCloudCoverPercent: _reading(data['totalCloud']),
        lowCloudCoverPercent: _reading(data['lowCloud']),
        midCloudCoverPercent: _reading(data['midCloud']),
        highCloudCoverPercent: _reading(data['highCloud']),
        precipitationMillimeters: _reading(data['precipitation']),
        precipitationProbabilityPercent: _reading(
          data['precipitationProbability'],
        ),
        windSpeedMetersPerSecond: _reading(data['windSpeed']),
        windGustMetersPerSecond: _reading(data['windGust']),
        windDirectionDegrees: _reading(data['windDirection']),
        relativeHumidityPercent: _reading(data['humidity']),
        visibilityMeters: _reading(data['visibility']),
      );

  static Object _value(WeatherValue<double> reading) => {
    'status': reading.status.name,
    'value': reading.value,
    'reason': reading.reason,
  };

  static WeatherValue<double> _reading(Object? raw) {
    final value = _object(raw);
    return switch (_string(value['status'])) {
      'available' => WeatherValue<double>.available(_number(value['value'])),
      'missing' => const WeatherValue<double>.missing(),
      'unavailable' => WeatherValue<double>.unavailable(
        _optionalString(value['reason']),
      ),
      _ => throw const FormatException('Invalid weather value status.'),
    };
  }

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    throw const FormatException('Expected JSON object.');
  }

  static String _string(Object? raw) {
    if (raw is String) return raw;
    throw const FormatException('Expected JSON string.');
  }

  static String? _optionalString(Object? raw) {
    if (raw == null || raw is String) return raw as String?;
    throw const FormatException('Expected nullable JSON string.');
  }

  static double _number(Object? raw) {
    if (raw is num) return raw.toDouble();
    throw const FormatException('Expected JSON number.');
  }

  static bool _boolean(Object? raw) {
    if (raw is bool) return raw;
    throw const FormatException('Expected JSON boolean.');
  }

  static String _date(DateTime date) => date.toUtc().toIso8601String();

  static DateTime _utc(Object? raw) {
    final value = _string(raw);
    if (!value.endsWith('Z')) {
      throw const FormatException('Cached timestamp is not explicit UTC.');
    }
    final parsed = DateTime.parse(value);
    if (!parsed.isUtc) {
      throw const FormatException('Expected UTC timestamp.');
    }
    return parsed;
  }
}
