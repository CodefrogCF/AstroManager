import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/providers/weather_provider.dart';
import 'open_meteo_forecast_parser.dart';

/// Live forecast adapter. No weather APIs leak into UI or astronomy services.
///
/// Default endpoint: Open-Meteo's free non-commercial API, no API key.
/// Clients can be injected for deterministic tests. A caller-supplied client
/// remains owned by its caller; the provider closes only its own client.
final class OpenMeteoWeatherProvider implements WeatherProvider {
  OpenMeteoWeatherProvider({
    http.Client? client,
    Uri? endpoint,
    this.model = 'best_match',
    this.timeout = const Duration(seconds: 12),
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _endpoint =
           endpoint ?? Uri.parse('https://api.open-meteo.com/v1/forecast'),
       _clock = clock ?? DateTime.now;

  static const id = OpenMeteoForecastParser.providerId;

  static const requestedVariables = <String>[
    'cloud_cover',
    'cloud_cover_low',
    'cloud_cover_mid',
    'cloud_cover_high',
    'precipitation',
    'precipitation_probability',
    'wind_speed_10m',
    'wind_gusts_10m',
    'wind_direction_10m',
    'relative_humidity_2m',
    'visibility',
  ];

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  final DateTime Function() _clock;
  final String model;
  final Duration timeout;

  @override
  WeatherProviderMetadata get metadata => WeatherProviderMetadata(
    id: id,
    name: 'Open-Meteo',
    model: model,
    attribution: 'Weather data by Open-Meteo.com (CC BY 4.0)',
    homepageUrl: 'https://open-meteo.com/',
  );

  void close() {
    if (_ownsClient) _client.close();
  }

  @override
  Future<WeatherForecast> fetchForecast(WeatherForecastRequest request) async {
    request.validate();
    if (timeout <= Duration.zero) {
      throw const WeatherException(
        type: WeatherErrorType.invalidRequest,
        message: 'Open-Meteo timeout must be positive.',
        providerId: id,
      );
    }
    final variables = requestedVariables.toSet();
    final unsupported = <String>{};

    // When a manually selected model refuses one variable, retry without
    // that variable. Only an explicit 400 response naming the unsupported
    // variable enables this fallback. All other errors remain typed failures.
    while (variables.isNotEmpty) {
      final response = await _get(_uriFor(request, variables));
      if (response.statusCode == 200) {
        Object? parsed;
        try {
          parsed = jsonDecode(response.body);
        } on FormatException catch (error) {
          throw WeatherException(
            type: WeatherErrorType.invalidResponse,
            message: 'Open-Meteo returned malformed JSON.',
            providerId: id,
            cause: error,
          );
        }
        return OpenMeteoForecastParser.parse(
          parsed,
          request,
          fetchedAtUtc: _clock().toUtc(),
          model: model,
          explicitlyUnsupported: unsupported,
        );
      }
      final reason = _errorReason(response.body);
      if (response.statusCode == 400) {
        final badVariable = _unsupportedVariable(reason, variables);
        if (badVariable != null) {
          variables.remove(badVariable);
          unsupported.add(badVariable);
          continue;
        }
      }
      throw _httpFailure(response, reason);
    }
    throw const WeatherException(
      type: WeatherErrorType.providerUnavailable,
      message: 'Open-Meteo does not support the requested weather variables.',
      providerId: id,
    );
  }

  Uri _uriFor(WeatherForecastRequest request, Set<String> variables) {
    String dateUtc(DateTime value) =>
        value.toUtc().toIso8601String().substring(0, 10);

    // A midnight end is exclusive; do not fetch an additional date.
    final lastIncluded = request.endUtc.subtract(
      const Duration(microseconds: 1),
    );
    return _endpoint.replace(
      queryParameters: <String, String>{
        'latitude': request.latitudeDegrees.toStringAsFixed(5),
        'longitude': request.longitudeDegrees.toStringAsFixed(5),
        'hourly': variables.join(','),
        'timezone': 'UTC',
        'timeformat': 'unixtime',
        'wind_speed_unit': 'ms',
        'precipitation_unit': 'mm',
        'models': model,
        'start_date': dateUtc(request.startUtc),
        'end_date': dateUtc(lastIncluded),
      },
    );
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw WeatherException(
        type: WeatherErrorType.timeout,
        message: 'Open-Meteo request timed out.',
        providerId: id,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw WeatherException(
        type: WeatherErrorType.network,
        message: 'Open-Meteo network request failed.',
        providerId: id,
        cause: error,
      );
    } on WeatherException {
      rethrow;
    } catch (error) {
      // Includes platform-specific socket errors without importing dart:io,
      // which would break the Flutter web target.
      throw WeatherException(
        type: WeatherErrorType.network,
        message: 'Could not retrieve Open-Meteo forecast.',
        providerId: id,
        cause: error,
      );
    }
  }

  static String _errorReason(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic> && parsed['reason'] is String) {
        return parsed['reason'] as String;
      }
    } on FormatException {
      // Fall back to HTTP status without echoing HTML or arbitrary payloads.
    }
    return '';
  }

  static String? _unsupportedVariable(String reason, Set<String> variables) {
    final lower = reason.toLowerCase();
    if (!RegExp(r'not available|not supported|unsupported|invalid|unknown')
        .hasMatch(lower)) {
      return null;
    }
    for (final name in variables) {
      // Match whole variable names to avoid accidental partial matches.
      if (RegExp('(?<![a-z0-9_])${RegExp.escape(name)}(?![a-z0-9_])')
          .hasMatch(lower)) {
        return name;
      }
    }
    return null;
  }

  static WeatherException _httpFailure(http.Response response, String reason) {
    final status = response.statusCode;
    final kind = switch (status) {
      401 || 403 => WeatherErrorType.authentication,
      429 => WeatherErrorType.rateLimited,
      400 || 422 => WeatherErrorType.invalidRequest,
      404 || >= 500 => WeatherErrorType.providerUnavailable,
      _ => WeatherErrorType.unknown,
    };
    final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
    final retryAfter = retrySeconds != null && retrySeconds >= 0
        ? Duration(seconds: retrySeconds)
        : null;
    return WeatherException(
      type: kind,
      message: reason.isNotEmpty
          ? 'Open-Meteo HTTP $status: $reason'
          : 'Open-Meteo returned HTTP $status.',
      providerId: id,
      retryAfter: retryAfter,
    );
  }
}
