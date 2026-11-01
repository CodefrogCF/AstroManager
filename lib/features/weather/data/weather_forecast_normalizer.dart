import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/models/weather_value.dart';

/// Units used by a third-party forecast. Conversion happens once, at ingress.
enum PercentageUnit { percent, fraction }

enum PrecipitationUnit { millimetersPerHour, inchesPerHour }

enum WindSpeedUnit { metersPerSecond, kilometersPerHour, milesPerHour, knots }

enum VisibilityUnit { meters, kilometers, miles }

final class WeatherSourceUnits {
  const WeatherSourceUnits({
    this.cloudCover = PercentageUnit.percent,
    this.precipitationProbability = PercentageUnit.percent,
    this.humidity = PercentageUnit.percent,
    this.precipitation = PrecipitationUnit.millimetersPerHour,
    this.windSpeed = WindSpeedUnit.metersPerSecond,
    this.visibility = VisibilityUnit.meters,
  });

  final PercentageUnit cloudCover;
  final PercentageUnit precipitationProbability;
  final PercentageUnit humidity;
  final PrecipitationUnit precipitation;
  final WindSpeedUnit windSpeed;
  final VisibilityUnit visibility;
}

/// Raw provider measurements with explicit availability.
///
/// Raw values use the units specified by [WeatherSourceUnits]. Provider
/// adapters are responsible for preserving missing and unsupported parameters.
final class RawHourlyWeather {
  const RawHourlyWeather({
    required this.timeUtc,
    this.totalCloudCover = const WeatherValue<double>.missing(),
    this.lowCloudCover = const WeatherValue<double>.missing(),
    this.midCloudCover = const WeatherValue<double>.missing(),
    this.highCloudCover = const WeatherValue<double>.missing(),
    this.precipitation = const WeatherValue<double>.missing(),
    this.precipitationProbability = const WeatherValue<double>.missing(),
    this.windSpeed = const WeatherValue<double>.missing(),
    this.windGust = const WeatherValue<double>.missing(),
    this.windDirectionDegrees = const WeatherValue<double>.missing(),
    this.humidity = const WeatherValue<double>.missing(),
    this.visibility = const WeatherValue<double>.missing(),
  });

  final DateTime timeUtc;
  final WeatherValue<double> totalCloudCover;
  final WeatherValue<double> lowCloudCover;
  final WeatherValue<double> midCloudCover;
  final WeatherValue<double> highCloudCover;
  final WeatherValue<double> precipitation;
  final WeatherValue<double> precipitationProbability;
  final WeatherValue<double> windSpeed;
  final WeatherValue<double> windGust;
  final WeatherValue<double> windDirectionDegrees;
  final WeatherValue<double> humidity;
  final WeatherValue<double> visibility;
}

/// Provider-agnostic conversion and validation of hourly forecast responses.
///
/// It sorts out-of-order hours but rejects duplicates. It never fills gaps,
/// assumes clear skies, or silently clamps invalid weather measurements.
abstract final class WeatherForecastNormalizer {
  static WeatherForecast normalize({
    required WeatherProviderMetadata provider,
    required double latitudeDegrees,
    required double longitudeDegrees,
    required DateTime issuedAtUtc,
    bool issuedAtIsEstimated = false,
    required DateTime fetchedAtUtc,
    required Iterable<RawHourlyWeather> hours,
    WeatherSourceUnits units = const WeatherSourceUnits(),
  }) {
    final normalized = hours.map((raw) {
      return HourlyWeatherForecast(
        timeUtc: raw.timeUtc,
        totalCloudCoverPercent: _percent(raw.totalCloudCover, units.cloudCover),
        lowCloudCoverPercent: _percent(raw.lowCloudCover, units.cloudCover),
        midCloudCoverPercent: _percent(raw.midCloudCover, units.cloudCover),
        highCloudCoverPercent: _percent(raw.highCloudCover, units.cloudCover),
        precipitationMillimeters: raw.precipitation.map(
          (value) => switch (units.precipitation) {
            PrecipitationUnit.millimetersPerHour => value,
            PrecipitationUnit.inchesPerHour => value * 25.4,
          },
        ),
        precipitationProbabilityPercent: _percent(
          raw.precipitationProbability,
          units.precipitationProbability,
        ),
        windSpeedMetersPerSecond: _wind(raw.windSpeed, units.windSpeed),
        windGustMetersPerSecond: _wind(raw.windGust, units.windSpeed),
        windDirectionDegrees: raw.windDirectionDegrees.map(
          (direction) => direction == 360 ? 0.0 : direction,
        ),
        relativeHumidityPercent: _percent(raw.humidity, units.humidity),
        visibilityMeters: raw.visibility.map(
          (value) => switch (units.visibility) {
            VisibilityUnit.meters => value,
            VisibilityUnit.kilometers => value * 1000,
            VisibilityUnit.miles => value * 1609.344,
          },
        ),
      );
    }).toList()..sort((a, b) => a.timeUtc.compareTo(b.timeUtc));

    return WeatherForecast(
      provider: provider,
      latitudeDegrees: latitudeDegrees,
      longitudeDegrees: longitudeDegrees,
      issuedAtUtc: issuedAtUtc,
      issuedAtIsEstimated: issuedAtIsEstimated,
      fetchedAtUtc: fetchedAtUtc,
      hours: normalized,
    );
  }

  static WeatherValue<double> _percent(
    WeatherValue<double> value,
    PercentageUnit unit,
  ) => value.map(
    (number) => unit == PercentageUnit.fraction ? number * 100 : number,
  );

  static WeatherValue<double> _wind(
    WeatherValue<double> value,
    WindSpeedUnit unit,
  ) => value.map(
    (number) => switch (unit) {
      WindSpeedUnit.metersPerSecond => number,
      WindSpeedUnit.kilometersPerHour => number / 3.6,
      WindSpeedUnit.milesPerHour => number * 0.44704,
      WindSpeedUnit.knots => number * (1852 / 3600),
    },
  );

  /// Provider implementations can use this for raw error translation.
  static WeatherException invalidResponse(
    String providerId,
    String details, {
    Object? cause,
  }) => WeatherException(
    type: WeatherErrorType.invalidResponse,
    message: details,
    providerId: providerId,
    cause: cause,
  );
}
