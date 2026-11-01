import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:astromanager/features/weather/data/open_meteo_weather_provider.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';

final request = WeatherForecastRequest(
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
  startUtc: DateTime.utc(2026, 11, 1, 22),
  endUtc: DateTime.utc(2026, 11, 2, 1),
);
final fetched = DateTime.utc(2026, 11, 1, 20);

String fixture({bool omittedVisibility = false}) => jsonEncode({
  'utc_offset_seconds': 0,
  'hourly': {
    'time': [
      DateTime.utc(2026, 11, 1, 22).millisecondsSinceEpoch ~/ 1000,
      DateTime.utc(2026, 11, 1, 23).millisecondsSinceEpoch ~/ 1000,
      DateTime.utc(2026, 11, 2).millisecondsSinceEpoch ~/ 1000,
    ],
    'cloud_cover': [12, 20, 35],
    if (!omittedVisibility) 'visibility': [18000, 14000, null],
  },
});

void main() {
  group('Open-Meteo HTTP provider', () {
    test(
      'sends coordinates, requested variables, UTC and custom date span',
      () async {
        late Uri captured;
        final provider = OpenMeteoWeatherProvider(
          clock: () => fetched,
          client: MockClient((req) async {
            captured = req.url;
            return http.Response(fixture(), 200);
          }),
        );
        final forecast = await provider.fetchForecast(request);
        expect(captured.host, 'api.open-meteo.com');
        expect(captured.queryParameters['latitude'], '47.48000');
        expect(captured.queryParameters['longitude'], '8.21000');
        expect(captured.queryParameters['timezone'], 'UTC');
        expect(captured.queryParameters['timeformat'], 'unixtime');
        expect(captured.queryParameters['wind_speed_unit'], 'ms');
        expect(captured.queryParameters['precipitation_unit'], 'mm');
        expect(captured.queryParameters['models'], 'best_match');
        expect(captured.queryParameters['start_date'], '2026-11-01');
        expect(captured.queryParameters['end_date'], '2026-11-02');
        final variables = captured.queryParameters['hourly']!.split(',');
        expect(
          variables,
          containsAll(OpenMeteoWeatherProvider.requestedVariables),
        );
        expect(forecast.hours, hasLength(3));
        expect(forecast.hours.first.totalCloudCoverPercent.value, 12);
        expect(forecast.hours.last.visibilityMeters.isMissing, isTrue);
      },
    );

    test('end exactly at midnight excludes the next date', () async {
      late Uri captured;
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(fixture(), 200);
        }),
      );
      final midnight = WeatherForecastRequest(
        latitudeDegrees: request.latitudeDegrees,
        longitudeDegrees: request.longitudeDegrees,
        startUtc: request.startUtc,
        endUtc: DateTime.utc(2026, 11, 2),
      );
      final result = await provider.fetchForecast(midnight);
      expect(captured.queryParameters['end_date'], '2026-11-01');
      expect(result.hours, hasLength(2));
    });

    test('retries unsupported variable and marks it unavailable', () async {
      final calls = <Uri>[];
      final provider = OpenMeteoWeatherProvider(
        model: 'icon_global',
        client: MockClient((req) async {
          calls.add(req.url);
          if (calls.length == 1) {
            return http.Response(
              jsonEncode({
                'error': true,
                'reason':
                    "Variable 'visibility' is not available for this model",
              }),
              400,
            );
          }
          return http.Response(fixture(omittedVisibility: true), 200);
        }),
      );
      final result = await provider.fetchForecast(request);
      expect(calls, hasLength(2));
      expect(calls[0].queryParameters['hourly'], contains('visibility'));
      expect(
        calls[1].queryParameters['hourly']!.split(','),
        isNot(contains('visibility')),
      );
      expect(result.hours.first.visibilityMeters.isUnavailable, isTrue);
      expect(result.provider.model, 'icon_global');
    });

    test('converts status codes to typed errors', () async {
      final cases = <int, WeatherErrorType>{
        400: WeatherErrorType.invalidRequest,
        401: WeatherErrorType.authentication,
        429: WeatherErrorType.rateLimited,
        500: WeatherErrorType.providerUnavailable,
      };
      for (final entry in cases.entries) {
        final provider = OpenMeteoWeatherProvider(
          client: MockClient((req) async {
            return http.Response(
              jsonEncode({'error': true, 'reason': 'Service error'}),
              entry.key,
              headers: {'retry-after': '15'},
            );
          }),
        );
        await expectLater(
          provider.fetchForecast(request),
          throwsA(
            isA<WeatherException>().having(
              (error) => error.type,
              'type',
              entry.value,
            ),
          ),
        );
      }
    });

    test('429 preserves Retry-After', () async {
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((req) async {
          return http.Response('{}', 429, headers: {'retry-after': '120'});
        }),
      );
      await expectLater(
        provider.fetchForecast(request),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(minutes: 2),
          ),
        ),
      );
    });

    test('network exceptions are translated and remain retryable', () async {
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((req) async {
          throw http.ClientException('Connection failed');
        }),
      );
      await expectLater(
        provider.fetchForecast(request),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.network,
          ),
        ),
      );
    });

    test('invalid JSON produces a non-retryable invalid response', () async {
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((req) async {
          return http.Response('<html>Not JSON</html>', 200);
        }),
      );
      await expectLater(
        provider.fetchForecast(request),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.invalidResponse,
          ),
        ),
      );
    });

    test('no useful hours raises noForecastData', () async {
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((req) async {
          return http.Response(
            jsonEncode({
              'hourly': {'time': []},
            }),
            200,
          );
        }),
      );
      await expectLater(
        provider.fetchForecast(request),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.noForecastData,
          ),
        ),
      );
    });

    test('invalid requests never reach HTTP', () async {
      var calls = 0;
      final provider = OpenMeteoWeatherProvider(
        client: MockClient((req) async {
          calls++;
          return http.Response(fixture(), 200);
        }),
      );
      final invalid = WeatherForecastRequest(
        latitudeDegrees: double.nan,
        longitudeDegrees: 8.21,
        startUtc: request.startUtc,
        endUtc: request.endUtc,
      );
      await expectLater(
        provider.fetchForecast(invalid),
        throwsA(isA<WeatherException>()),
      );
      expect(calls, 0);
    });
  });
}
