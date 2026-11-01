import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/weather/data/open_meteo_forecast_parser.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';

final request = WeatherForecastRequest(
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
  startUtc: DateTime.utc(2026, 11, 1, 20),
  endUtc: DateTime.utc(2026, 11, 2, 2),
);

final fetched = DateTime.utc(2026, 11, 1, 19);

Map<String, dynamic> fixture({
  List<int>? timestamps,
  Map<String, dynamic>? fields,
}) => <String, dynamic>{
  'latitude': 47.5,
  'longitude': 8.2,
  'utc_offset_seconds': 0,
  'timezone': 'GMT',
  'hourly_units': {
    'wind_speed_10m': 'm/s',
    'wind_gusts_10m': 'm/s',
    'visibility': 'm',
    'cloud_cover': '%',
    'precipitation': 'mm',
  },
  'hourly': <String, dynamic>{
    'time':
        timestamps ??
        [
          DateTime.utc(2026, 11, 1, 19).millisecondsSinceEpoch ~/ 1000,
          DateTime.utc(2026, 11, 1, 20).millisecondsSinceEpoch ~/ 1000,
          DateTime.utc(2026, 11, 1, 21).millisecondsSinceEpoch ~/ 1000,
          DateTime.utc(2026, 11, 2, 2).millisecondsSinceEpoch ~/ 1000,
        ],
    ...?fields,
  },
};

void main() {
  group('Open-Meteo response parsing', () {
    test('filters [start, end), preserves UTC, maps units and attribution', () {
      final json = fixture(
        fields: {
          'cloud_cover': [100, 0, 70, 20],
          'cloud_cover_low': [0, 10, 20, 30],
          'cloud_cover_mid': [0, 20, null, 30],
          'cloud_cover_high': [0, 30, 40, 50],
          'precipitation': [1, 0.5, 0, 1],
          'precipitation_probability': [40, 15, 10, 5],
          'wind_speed_10m': [5, 3.5, 7, 1],
          'wind_gusts_10m': [7, 6, 11, 2],
          'wind_direction_10m': [120, 360, 210, 50],
          'relative_humidity_2m': [70, 80, 90, 60],
          'visibility': [12000, 16000, 8000, 5000],
        },
      );
      final result = OpenMeteoForecastParser.parse(
        json,
        request,
        fetchedAtUtc: fetched,
      );
      expect(result.hours, hasLength(2));
      expect(result.hours.first.timeUtc, DateTime.utc(2026, 11, 1, 20));
      expect(result.hours.last.timeUtc, DateTime.utc(2026, 11, 1, 21));
      expect(result.hours.every((hour) => hour.timeUtc.isUtc), isTrue);
      expect(result.hours.first.totalCloudCoverPercent.value, 0);
      expect(result.hours.first.windSpeedMetersPerSecond.value, 3.5);
      expect(result.hours.first.windGustMetersPerSecond.value, 6);
      expect(result.hours.first.windDirectionDegrees.value, 0);
      expect(result.hours.first.visibilityMeters.value, 16000);
      expect(result.hours.first.precipitationMillimeters.value, 0.5);
      expect(result.hours.first.precipitationProbabilityPercent.value, 15);
      expect(result.hours.first.relativeHumidityPercent.value, 80);
      expect(result.hours.last.midCloudCoverPercent.isMissing, isTrue);
      expect(result.provider.id, 'open_meteo');
      expect(result.provider.attribution, contains('Open-Meteo'));
      expect(result.issuedAtUtc, fetched);
      expect(result.issuedAtIsEstimated, isTrue);
      expect(result.fetchedAtUtc, fetched);
    });

    test('omitted data is unavailable, null data is missing, not zero', () {
      final json = fixture(
        fields: {
          'cloud_cover': [null, 0, null, 0],
        },
      );
      final result = OpenMeteoForecastParser.parse(
        json,
        request,
        fetchedAtUtc: fetched,
      );
      expect(result.hours.first.totalCloudCoverPercent.isAvailable, isTrue);
      expect(result.hours.last.totalCloudCoverPercent.isMissing, isTrue);
      expect(result.hours.last.totalCloudCoverPercent.valueOrNull, isNull);
      expect(result.hours.first.lowCloudCoverPercent.isUnavailable, isTrue);
      expect(
        result.hours.first.precipitationProbabilityPercent.isUnavailable,
        isTrue,
      );
      expect(result.hours.first.visibilityMeters.isUnavailable, isTrue);
    });

    test('explicitly rejected variables remain unavailable', () {
      final result = OpenMeteoForecastParser.parse(
        fixture(
          fields: {
            'visibility': [100, 100, 100, 100],
          },
        ),
        request,
        fetchedAtUtc: fetched,
        explicitlyUnsupported: {'visibility'},
      );
      expect(
        result.hours.first.visibilityMeters.status,
        WeatherValueStatus.unavailable,
      );
    });

    test('two physical hours remain distinct across the DST transition', () {
      final autumn = WeatherForecastRequest(
        latitudeDegrees: 47.48,
        longitudeDegrees: 8.21,
        startUtc: DateTime.utc(2026, 10, 25),
        endUtc: DateTime.utc(2026, 10, 25, 2),
      );
      final first = DateTime.utc(2026, 10, 25).millisecondsSinceEpoch ~/ 1000;
      final second =
          DateTime.utc(2026, 10, 25, 1).millisecondsSinceEpoch ~/ 1000;
      final forecast = OpenMeteoForecastParser.parse(
        fixture(timestamps: [first, second]),
        autumn,
        fetchedAtUtc: fetched,
      );
      expect(forecast.hours, hasLength(2));
      expect(
        forecast.hours.last.timeUtc.difference(forecast.hours.first.timeUtc),
        const Duration(hours: 1),
      );
    });

    test('rejects inconsistent arrays, incorrect units and bad numbers', () {
      final samples = [
        fixture(
          fields: {
            'cloud_cover': [1],
          },
        ),
        fixture(
          fields: {
            'cloud_cover': [10, -1, 50, 0],
          },
        ),
        fixture(
          fields: {
            'cloud_cover': [10, 'clear', 50, 0],
          },
        ),
        fixture(
          fields: {
            'wind_speed_10m': [1, double.nan, 2, 3],
          },
        ),
      ];
      for (final input in samples) {
        expect(
          () => OpenMeteoForecastParser.parse(
            input,
            request,
            fetchedAtUtc: fetched,
          ),
          throwsA(
            isA<WeatherException>().having(
              (error) => error.type,
              'type',
              WeatherErrorType.invalidResponse,
            ),
          ),
        );
      }
      final wrongUnits = fixture(
        fields: {
          'wind_speed_10m': [1, 2, 3, 4],
        },
      );
      (wrongUnits['hourly_units'] as Map<String, dynamic>)['wind_speed_10m'] =
          'km/h';
      expect(
        () => OpenMeteoForecastParser.parse(
          wrongUnits,
          request,
          fetchedAtUtc: fetched,
        ),
        throwsA(isA<WeatherException>()),
      );
    });

    test('rejects ambiguous times and non-UTC offsets', () {
      final invalidTimes = fixture();
      (invalidTimes['hourly'] as Map<String, dynamic>)['time'] = [
        '2026-11-01T20:00',
      ];
      expect(
        () => OpenMeteoForecastParser.parse(
          invalidTimes,
          request,
          fetchedAtUtc: fetched,
        ),
        throwsA(isA<WeatherException>()),
      );
      final wrongTimezone = fixture();
      wrongTimezone['utc_offset_seconds'] = 3600;
      expect(
        () => OpenMeteoForecastParser.parse(
          wrongTimezone,
          request,
          fetchedAtUtc: fetched,
        ),
        throwsA(isA<WeatherException>()),
      );
    });

    test('rejects empty selected window without inventing weather', () {
      final outsideWindow = fixture(
        timestamps: [
          DateTime.utc(2026, 11, 1, 17).millisecondsSinceEpoch ~/ 1000,
        ],
      );
      expect(
        () => OpenMeteoForecastParser.parse(
          outsideWindow,
          request,
          fetchedAtUtc: fetched,
        ),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.noForecastData,
          ),
        ),
      );
    });
  });
}
