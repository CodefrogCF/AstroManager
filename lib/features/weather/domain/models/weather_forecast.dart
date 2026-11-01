import 'weather_error.dart';
import 'weather_value.dart';

/// Metadata identifying the origin and forecast model of a result.
final class WeatherProviderMetadata {
  const WeatherProviderMetadata({
    required this.id,
    required this.name,
    this.model,
    this.attribution,
    this.homepageUrl,
  });

  final String id;
  final String name;
  final String? model;
  final String? attribution;
  final String? homepageUrl;

  void validate() {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw WeatherException(
        type: WeatherErrorType.invalidResponse,
        message: 'Weather provider ID and name must not be empty.',
        providerId: id,
      );
    }
  }
}

/// One valid hour, expressed in standardized units.
///
/// - Cloud coverage, precipitation probability and humidity: 0..100 percent
/// - Precipitation amount: millimeters per forecast hour (mm/h)
/// - Wind and gust speeds: meters per second (m/s)
/// - Wind direction: degrees clockwise from true north, 0 inclusive to 360
///   exclusive (direction the wind comes FROM)
/// - Visibility: meters
///
/// Missing and unsupported values are explicit; never interpret null as 0.
final class HourlyWeatherForecast {
  const HourlyWeatherForecast({
    required this.timeUtc,
    this.totalCloudCoverPercent = const WeatherValue<double>.missing(),
    this.lowCloudCoverPercent = const WeatherValue<double>.missing(),
    this.midCloudCoverPercent = const WeatherValue<double>.missing(),
    this.highCloudCoverPercent = const WeatherValue<double>.missing(),
    this.precipitationMillimeters = const WeatherValue<double>.missing(),
    this.precipitationProbabilityPercent = const WeatherValue<double>.missing(),
    this.windSpeedMetersPerSecond = const WeatherValue<double>.missing(),
    this.windGustMetersPerSecond = const WeatherValue<double>.missing(),
    this.windDirectionDegrees = const WeatherValue<double>.missing(),
    this.relativeHumidityPercent = const WeatherValue<double>.missing(),
    this.visibilityMeters = const WeatherValue<double>.missing(),
  });

  final DateTime timeUtc;
  final WeatherValue<double> totalCloudCoverPercent;
  final WeatherValue<double> lowCloudCoverPercent;
  final WeatherValue<double> midCloudCoverPercent;
  final WeatherValue<double> highCloudCoverPercent;
  final WeatherValue<double> precipitationMillimeters;
  final WeatherValue<double> precipitationProbabilityPercent;
  final WeatherValue<double> windSpeedMetersPerSecond;
  final WeatherValue<double> windGustMetersPerSecond;
  final WeatherValue<double> windDirectionDegrees;
  final WeatherValue<double> relativeHumidityPercent;
  final WeatherValue<double> visibilityMeters;

  /// Validates this normalized result, including all available measurements.
  void validate({String? providerId}) {
    if (!timeUtc.isUtc ||
        timeUtc.minute != 0 ||
        timeUtc.second != 0 ||
        timeUtc.millisecond != 0 ||
        timeUtc.microsecond != 0) {
      throw WeatherException(
        type: WeatherErrorType.invalidResponse,
        message: 'Forecast timestamps must be whole UTC hours.',
        providerId: providerId,
      );
    }

    for (final (name, reading) in <(String, WeatherValue<double>)>[
      ('totalCloudCoverPercent', totalCloudCoverPercent),
      ('lowCloudCoverPercent', lowCloudCoverPercent),
      ('midCloudCoverPercent', midCloudCoverPercent),
      ('highCloudCoverPercent', highCloudCoverPercent),
      ('precipitationProbabilityPercent', precipitationProbabilityPercent),
      ('relativeHumidityPercent', relativeHumidityPercent),
    ]) {
      _validateReading(name, reading, 0, 100, providerId);
    }
    for (final (name, reading) in <(String, WeatherValue<double>)>[
      ('precipitationMillimeters', precipitationMillimeters),
      ('windSpeedMetersPerSecond', windSpeedMetersPerSecond),
      ('windGustMetersPerSecond', windGustMetersPerSecond),
      ('visibilityMeters', visibilityMeters),
    ]) {
      _validateReading(name, reading, 0, double.infinity, providerId);
    }
    _validateReading(
      'windDirectionDegrees',
      windDirectionDegrees,
      0,
      360,
      providerId,
      exclusiveMaximum: true,
    );
  }

  static void _validateReading(
    String name,
    WeatherValue<double> reading,
    double minimum,
    double maximum,
    String? providerId, {
    bool exclusiveMaximum = false,
  }) {
    final value = reading.value;
    if (reading.isAvailable) {
      if (value == null ||
          !value.isFinite ||
          value < minimum ||
          (exclusiveMaximum ? value >= maximum : value > maximum)) {
        throw WeatherException(
          type: WeatherErrorType.invalidResponse,
          message: 'Invalid normalized $name: $value.',
          providerId: providerId,
        );
      }
    } else if (value != null) {
      throw WeatherException(
        type: WeatherErrorType.invalidResponse,
        message: '$name is not available but contains a value.',
        providerId: providerId,
      );
    }
  }
}

/// Derived cache freshness; this does not infer forecast weather quality.
final class WeatherForecastFreshness {
  const WeatherForecastFreshness({
    required this.age,
    required this.maximumAge,
    required this.isStale,
  });

  final Duration age;
  final Duration maximumAge;
  final bool isStale;
}

/// Complete provider response for one geographic point.
///
/// A forecast is an immutable, ordered set of distinct UTC hours.
/// Sparse hours are allowed: missing hours must not be invented or interpolated.
final class WeatherForecast {
  WeatherForecast({
    required this.provider,
    required this.latitudeDegrees,
    required this.longitudeDegrees,
    required this.issuedAtUtc,
    required this.fetchedAtUtc,
    required List<HourlyWeatherForecast> hours,
  }) : hours = List<HourlyWeatherForecast>.unmodifiable(hours) {
    validate();
  }

  final WeatherProviderMetadata provider;
  final double latitudeDegrees;
  final double longitudeDegrees;
  final DateTime issuedAtUtc;
  final DateTime fetchedAtUtc;
  final List<HourlyWeatherForecast> hours;

  WeatherForecastFreshness freshnessAt(
    DateTime now, {
    required Duration maximumAge,
  }) {
    if (maximumAge.isNegative) {
      throw ArgumentError.value(maximumAge, 'maximumAge');
    }
    final elapsed = now.toUtc().difference(fetchedAtUtc);
    // A negative age can occur if the device's clock moves backwards.
    final age = elapsed.isNegative ? Duration.zero : elapsed;
    return WeatherForecastFreshness(
      age: age,
      maximumAge: maximumAge,
      isStale: elapsed > maximumAge,
    );
  }

  void validate() {
    provider.validate();
    if (!latitudeDegrees.isFinite ||
        latitudeDegrees < -90 ||
        latitudeDegrees > 90 ||
        !longitudeDegrees.isFinite ||
        longitudeDegrees < -180 ||
        longitudeDegrees > 180) {
      throw WeatherException(
        type: WeatherErrorType.invalidResponse,
        message: 'Forecast coordinates are invalid.',
        providerId: provider.id,
      );
    }
    if (!issuedAtUtc.isUtc || !fetchedAtUtc.isUtc) {
      throw WeatherException(
        type: WeatherErrorType.invalidResponse,
        message: 'Forecast issue and fetch times must be UTC.',
        providerId: provider.id,
      );
    }
    if (hours.isEmpty) {
      throw WeatherException(
        type: WeatherErrorType.noForecastData,
        message: 'Provider returned no forecast hours.',
        providerId: provider.id,
      );
    }
    DateTime? previous;
    for (final hour in hours) {
      hour.validate(providerId: provider.id);
      if (previous != null && !hour.timeUtc.isAfter(previous)) {
        throw WeatherException(
          type: WeatherErrorType.invalidResponse,
          message:
              'Forecast hours must be strictly increasing without duplicates.',
          providerId: provider.id,
        );
      }
      previous = hour.timeUtc;
    }
  }
}
