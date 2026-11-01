import '../models/weather_error.dart';
import '../models/weather_forecast.dart';

/// Geographic, time-bounded forecast request with UTC-exclusive end.
///
/// No IANA conversion happens at the provider boundary. Callers specify
/// absolute instants so DST changes cannot introduce ambiguous forecast hours.
final class WeatherForecastRequest {
  const WeatherForecastRequest({
    required this.latitudeDegrees,
    required this.longitudeDegrees,
    required this.startUtc,
    required this.endUtc,
  });

  final double latitudeDegrees;
  final double longitudeDegrees;
  final DateTime startUtc;
  final DateTime endUtc;

  void validate() {
    if (!latitudeDegrees.isFinite ||
        latitudeDegrees < -90 ||
        latitudeDegrees > 90 ||
        !longitudeDegrees.isFinite ||
        longitudeDegrees < -180 ||
        longitudeDegrees > 180) {
      throw const WeatherException(
        type: WeatherErrorType.invalidRequest,
        message: 'Weather request coordinates are invalid.',
      );
    }
    if (!startUtc.isUtc || !endUtc.isUtc || !endUtc.isAfter(startUtc)) {
      throw const WeatherException(
        type: WeatherErrorType.invalidRequest,
        message: 'Weather request must contain an increasing UTC time window.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WeatherForecastRequest &&
      latitudeDegrees == other.latitudeDegrees &&
      longitudeDegrees == other.longitudeDegrees &&
      startUtc == other.startUtc &&
      endUtc == other.endUtc;

  @override
  int get hashCode =>
      Object.hash(latitudeDegrees, longitudeDegrees, startUtc, endUtc);
}

/// Replaceable forecast source. No Flutter, HTTP, database or UI dependency.
///
/// Implementations return normalized [WeatherForecast] values and translate
/// provider-specific failures to [WeatherException].
abstract interface class WeatherProvider {
  WeatherProviderMetadata get metadata;

  Future<WeatherForecast> fetchForecast(WeatherForecastRequest request);
}
