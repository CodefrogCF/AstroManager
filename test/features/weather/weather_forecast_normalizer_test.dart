import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/weather/data/weather_forecast_normalizer.dart';
import 'package:astromanager/features/weather/domain/models/weather_error.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';

const metadata = WeatherProviderMetadata(
  id: 'reference',
  name: 'Reference Forecast',
  model: 'hourly',
  attribution: 'Test fixture',
);

final issuedAt = DateTime.utc(2026, 11, 1, 6);
final fetchedAt = DateTime.utc(2026, 11, 1, 6, 30);

WeatherForecast normalize(
  List<RawHourlyWeather> hours, {
  WeatherSourceUnits units = const WeatherSourceUnits(),
}) => WeatherForecastNormalizer.normalize(
  provider: metadata,
  latitudeDegrees: 47.48,
  longitudeDegrees: 8.21,
  issuedAtUtc: issuedAt,
  fetchedAtUtc: fetchedAt,
  hours: hours,
  units: units,
);

void main() {
  group('Value availability', () {
    test('zero cloud coverage is real data, not a missing value', () {
      const clear = WeatherValue<double>.available(0);
      const missing = WeatherValue<double>.missing();
      const unavailable = WeatherValue<double>.unavailable('not offered');

      expect(clear.isAvailable, isTrue);
      expect(clear.valueOrNull, 0);
      expect(missing.isMissing, isTrue);
      expect(missing.valueOrNull, isNull);
      expect(unavailable.isUnavailable, isTrue);
      expect(unavailable.valueOrNull, isNull);
      expect(unavailable.reason, 'not offered');
    });

    test('conversions preserve missing and unavailable states', () {
      const missing = WeatherValue<double>.missing();
      const unavailable = WeatherValue<double>.unavailable('not modeled');

      expect(missing.map((value) => value * 100).isMissing, isTrue);
      final converted = unavailable.map((value) => value * 100);
      expect(converted.isUnavailable, isTrue);
      expect(converted.reason, 'not modeled');
    });
  });

  group('Normalization', () {
    test('converts every supported unit without altering zero', () {
      final forecast = normalize(
        [
          RawHourlyWeather(
            timeUtc: DateTime.utc(2026, 11, 1, 22),
            totalCloudCover: const WeatherValue.available(0.15),
            lowCloudCover: const WeatherValue.available(0.25),
            midCloudCover: const WeatherValue.available(0.50),
            highCloudCover: const WeatherValue.unavailable('unsupported'),
            precipitation: const WeatherValue.available(0.1),
            precipitationProbability: const WeatherValue.available(0.4),
            windSpeed: const WeatherValue.available(36),
            windGust: const WeatherValue.available(72),
            windDirectionDegrees: const WeatherValue.available(360),
            humidity: const WeatherValue.available(0.8),
            visibility: const WeatherValue.available(12),
          ),
        ],
        units: const WeatherSourceUnits(
          cloudCover: PercentageUnit.fraction,
          precipitationProbability: PercentageUnit.fraction,
          humidity: PercentageUnit.fraction,
          precipitation: PrecipitationUnit.inchesPerHour,
          windSpeed: WindSpeedUnit.kilometersPerHour,
          visibility: VisibilityUnit.kilometers,
        ),
      );
      final hour = forecast.hours.single;

      expect(hour.totalCloudCoverPercent.value, closeTo(15, 1e-10));
      expect(hour.lowCloudCoverPercent.value, closeTo(25, 1e-10));
      expect(hour.midCloudCoverPercent.value, closeTo(50, 1e-10));
      expect(hour.highCloudCoverPercent.isUnavailable, isTrue);
      expect(hour.highCloudCoverPercent.reason, 'unsupported');
      expect(hour.precipitationMillimeters.value, closeTo(2.54, 1e-10));
      expect(hour.precipitationProbabilityPercent.value, closeTo(40, 1e-10));
      expect(hour.windSpeedMetersPerSecond.value, closeTo(10, 1e-10));
      expect(hour.windGustMetersPerSecond.value, closeTo(20, 1e-10));
      expect(hour.windDirectionDegrees.value, 0);
      expect(hour.relativeHumidityPercent.value, closeTo(80, 1e-10));
      expect(hour.visibilityMeters.value, 12000);
      expect(forecast.provider.id, 'reference');
      expect(forecast.provider.model, 'hourly');
    });

    test('alternative wind and visibility units are supported', () {
      final mph = normalize(
        [
          RawHourlyWeather(
            timeUtc: DateTime.utc(2026, 11, 1, 0),
            windSpeed: const WeatherValue.available(10),
            visibility: const WeatherValue.available(2),
          ),
        ],
        units: const WeatherSourceUnits(
          windSpeed: WindSpeedUnit.milesPerHour,
          visibility: VisibilityUnit.miles,
        ),
      );
      expect(
        mph.hours.single.windSpeedMetersPerSecond.value,
        closeTo(4.4704, 1e-8),
      );
      expect(mph.hours.single.visibilityMeters.value, closeTo(3218.688, 1e-6));

      final knots = normalize([
        RawHourlyWeather(
          timeUtc: DateTime.utc(2026, 11, 1, 1),
          windSpeed: const WeatherValue.available(10),
        ),
      ], units: const WeatherSourceUnits(windSpeed: WindSpeedUnit.knots));
      expect(
        knots.hours.single.windSpeedMetersPerSecond.value,
        closeTo(5.144444, 1e-5),
      );
    });

    test('unspecified values never default to ideal weather', () {
      final hour = normalize([
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 22)),
      ]).hours.single;
      expect(hour.totalCloudCoverPercent.isMissing, isTrue);
      expect(hour.lowCloudCoverPercent.isMissing, isTrue);
      expect(hour.precipitationMillimeters.isMissing, isTrue);
      expect(hour.windSpeedMetersPerSecond.isMissing, isTrue);
      expect(hour.relativeHumidityPercent.isMissing, isTrue);
      expect(hour.visibilityMeters.isMissing, isTrue);
      expect(hour.totalCloudCoverPercent.valueOrNull, isNull);
    });

    test('sorts hours without interpolating missing forecast periods', () {
      final forecast = normalize([
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 23)),
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 21)),
      ]);
      expect(forecast.hours, hasLength(2));
      expect(forecast.hours.first.timeUtc.hour, 21);
      expect(forecast.hours.last.timeUtc.hour, 23);
    });

    test('UTC hours remain distinct across the autumn DST transition', () {
      // 00:00Z and 01:00Z both correspond to 02:00 in Zurich, but are
      // different physical hours and must not be deduplicated.
      final forecast = normalize([
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 10, 25, 0)),
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 10, 25, 1)),
      ]);
      expect(forecast.hours, hasLength(2));
      expect(
        forecast.hours.last.timeUtc.difference(forecast.hours.first.timeUtc),
        const Duration(hours: 1),
      );
    });

    test('rejects duplicate hours as a typed response error', () {
      expect(
        () => normalize([
          RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 22)),
          RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 22)),
        ]),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.invalidResponse,
          ),
        ),
      );
    });

    test('rejects percentage values outside the valid range', () {
      expect(
        () => normalize([
          RawHourlyWeather(
            timeUtc: DateTime.utc(2026, 11, 1, 22),
            totalCloudCover: const WeatherValue.available(125),
          ),
        ]),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.type,
            'type',
            WeatherErrorType.invalidResponse,
          ),
        ),
      );
    });

    test('rejects non-finite and negative readings', () {
      for (final value in [double.nan, double.infinity, -1.0]) {
        expect(
          () => normalize([
            RawHourlyWeather(
              timeUtc: DateTime.utc(2026, 11, 1, 22),
              precipitation: WeatherValue.available(value),
            ),
          ]),
          throwsA(isA<WeatherException>()),
        );
      }
    });

    test('rejects ambiguous timestamps and fractional hours', () {
      expect(
        () => normalize([RawHourlyWeather(timeUtc: DateTime(2026, 11, 1, 22))]),
        throwsA(isA<WeatherException>()),
      );
      expect(
        () => normalize([
          RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 22, 30)),
        ]),
        throwsA(isA<WeatherException>()),
      );
    });

    test('an empty response is not treated as clear weather', () {
      expect(
        () => normalize([]),
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

  group('Forecast freshness', () {
    test('uses fetch time, not issue time, for cache age', () {
      final forecast = normalize([
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 22)),
      ]);
      expect(forecast.issuedAtUtc, issuedAt);
      expect(forecast.fetchedAtUtc, fetchedAt);
      expect(
        forecast
            .freshnessAt(
              DateTime.utc(2026, 11, 1, 7),
              maximumAge: const Duration(hours: 2),
            )
            .isStale,
        isFalse,
      );
      final freshness = forecast.freshnessAt(
        DateTime.utc(2026, 11, 1, 9),
        maximumAge: const Duration(hours: 2),
      );
      expect(freshness.isStale, isTrue);
      expect(freshness.age, const Duration(hours: 2, minutes: 30));
    });

    test('future fetch timestamps never produce negative age', () {
      final forecast = normalize([
        RawHourlyWeather(timeUtc: DateTime.utc(2026, 11, 1, 22)),
      ]);
      final freshness = forecast.freshnessAt(
        DateTime.utc(2026, 11, 1, 6),
        maximumAge: const Duration(hours: 1),
      );
      expect(freshness.age, Duration.zero);
      expect(freshness.isStale, isFalse);
    });
  });
}
