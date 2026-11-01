import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/models/weather_value.dart';
import '../domain/providers/weather_provider.dart';
import 'weather_forecast_normalizer.dart';

/// Converts an Open-Meteo /v1/forecast JSON object to the domain model.
///
/// Expected request format: timezone=UTC, timeformat=unixtime,
/// wind_speed_unit=ms, precipitation_unit=mm. No local-time parsing is used.
/// An omitted variable is unsupported/unavailable; a null element in an
/// existing variable's array is missing for that particular UTC hour.
abstract final class OpenMeteoForecastParser {
  static const providerId = 'open_meteo';

  static WeatherForecast parse(
    Object? json,
    WeatherForecastRequest request, {
    required DateTime fetchedAtUtc,
    String model = 'best_match',
    Set<String> explicitlyUnsupported = const {},
  }) {
    WeatherException invalid(String message) => WeatherException(
      type: WeatherErrorType.invalidResponse,
      message: message,
      providerId: providerId,
    );

    if (json is! Map<String, dynamic>) {
      throw invalid('Open-Meteo response must be a JSON object.');
    }
    if (json['error'] == true) {
      throw invalid('Open-Meteo returned an error in a successful response.');
    }
    if (json['utc_offset_seconds'] != null && json['utc_offset_seconds'] != 0) {
      throw invalid('Open-Meteo returned non-UTC forecast timestamps.');
    }
    final timeZone = json['timezone'];
    if (timeZone != null &&
        timeZone != 'GMT' &&
        timeZone != 'UTC' &&
        timeZone != 'Etc/UTC') {
      throw invalid('Open-Meteo returned an unexpected forecast time zone.');
    }

    final hourly = json['hourly'];
    if (hourly is! Map<String, dynamic>) {
      throw invalid('Open-Meteo response has no hourly object.');
    }
    final rawTimes = hourly['time'];
    if (rawTimes is! List) {
      throw invalid('Open-Meteo hourly.time must be an array.');
    }

    final units = json['hourly_units'];
    if (units != null && units is! Map<String, dynamic>) {
      throw invalid('Open-Meteo hourly_units must be an object.');
    }
    if (units is Map<String, dynamic>) {
      // Requests explicitly select these units. Never silently reinterpret a
      // response if the server returns different units than requested.
      final expected = <String, String>{
        'cloud_cover': '%',
        'cloud_cover_low': '%',
        'cloud_cover_mid': '%',
        'cloud_cover_high': '%',
        'precipitation_probability': '%',
        'precipitation': 'mm',
        'wind_speed_10m': 'm/s',
        'wind_gusts_10m': 'm/s',
        'wind_direction_10m': '°',
        'relative_humidity_2m': '%',
        'visibility': 'm',
      };
      for (final entry in expected.entries) {
        if (hourly.containsKey(entry.key) &&
            units.containsKey(entry.key) &&
            units[entry.key] != entry.value) {
          throw invalid(
            'Unexpected Open-Meteo unit for ${entry.key}: '
            '${units[entry.key]}.',
          );
        }
      }
    }

    // Validate the WHOLE array, including hours outside the selected window.
    // Truncated or malformed columns are not mistaken for missing readings.
    for (final entry in hourly.entries) {
      if (entry.key == 'time') continue;
      final value = entry.value;
      if (value is! List || value.length != rawTimes.length) {
        throw invalid('Open-Meteo hourly.${entry.key} has a wrong length.');
      }
    }

    WeatherValue<double> reading(String name, int index) {
      if (explicitlyUnsupported.contains(name)) {
        return const WeatherValue<double>.unavailable(
          'Not supported by the selected Open-Meteo forecast model.',
        );
      }
      if (!hourly.containsKey(name)) {
        return const WeatherValue<double>.unavailable(
          'Not included in the Open-Meteo response.',
        );
      }
      final value = (hourly[name] as List)[index];
      if (value == null) return const WeatherValue<double>.missing();
      if (value is! num || !value.isFinite) {
        throw invalid('Open-Meteo hourly.$name contains an invalid number.');
      }
      return WeatherValue<double>.available(value.toDouble());
    }

    final rows = <RawHourlyWeather>[];
    for (var index = 0; index < rawTimes.length; index++) {
      final seconds = rawTimes[index];
      if (seconds is! num ||
          !seconds.isFinite ||
          seconds != seconds.truncateToDouble()) {
        throw invalid('Open-Meteo hourly.time contains a non-integer epoch.');
      }
      late final DateTime instant;
      try {
        instant = DateTime.fromMillisecondsSinceEpoch(
          seconds.toInt() * 1000,
          isUtc: true,
        );
      } on RangeError catch (error) {
        throw WeatherException(
          type: WeatherErrorType.invalidResponse,
          message: 'Open-Meteo hourly.time is out of range.',
          providerId: providerId,
          cause: error,
        );
      }
      // The domain uses [startUtc, endUtc), and only entire UTC hour samples.
      if (instant.isBefore(request.startUtc) ||
          !instant.isBefore(request.endUtc)) {
        continue;
      }
      rows.add(
        RawHourlyWeather(
          timeUtc: instant,
          totalCloudCover: reading('cloud_cover', index),
          lowCloudCover: reading('cloud_cover_low', index),
          midCloudCover: reading('cloud_cover_mid', index),
          highCloudCover: reading('cloud_cover_high', index),
          precipitation: reading('precipitation', index),
          precipitationProbability: reading('precipitation_probability', index),
          windSpeed: reading('wind_speed_10m', index),
          windGust: reading('wind_gusts_10m', index),
          windDirectionDegrees: reading('wind_direction_10m', index),
          humidity: reading('relative_humidity_2m', index),
          visibility: reading('visibility', index),
        ),
      );
    }

    // The Forecast API does not expose a reliable model-run issuance time.
    // The mandatory issue field therefore uses retrieval time as a proxy.
    // Consumers should use fetchedAtUtc to assess freshness, and must NOT
    // present issuedAtUtc as a verified numerical-model run timestamp.
    return WeatherForecastNormalizer.normalize(
      provider: WeatherProviderMetadata(
        id: providerId,
        name: 'Open-Meteo',
        model: model,
        attribution: 'Weather data by Open-Meteo.com (CC BY 4.0)',
        homepageUrl: 'https://open-meteo.com/',
      ),
      latitudeDegrees: request.latitudeDegrees,
      longitudeDegrees: request.longitudeDegrees,
      issuedAtUtc: fetchedAtUtc.toUtc(),
      issuedAtIsEstimated: true,
      fetchedAtUtc: fetchedAtUtc.toUtc(),
      hours: rows,
      units: const WeatherSourceUnits(),
    );
  }
}
