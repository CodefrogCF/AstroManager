import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:astromanager/features/weather/domain/providers/weather_provider.dart';
import 'package:astromanager/features/weather/domain/repositories/weather_cache_repository.dart';

final class MemoryWeatherCache implements WeatherCacheRepository {
  final Map<WeatherCacheKey, WeatherForecast> values = {};

  @override
  Future<WeatherForecast?> read(WeatherCacheKey key) async => values[key];

  @override
  Future<void> write(WeatherCacheKey key, WeatherForecast forecast) async {
    values[key] = forecast;
  }

  @override
  Future<void> remove(WeatherCacheKey key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

final class ControlledWeatherProvider implements WeatherProvider {
  ControlledWeatherProvider(this.respond);

  Future<WeatherForecast> Function(WeatherForecastRequest) respond;
  final requests = <WeatherForecastRequest>[];

  int get calls => requests.length;

  @override
  WeatherProviderMetadata get metadata =>
      const WeatherProviderMetadata(id: 'mock', name: 'Mock');

  @override
  Future<WeatherForecast> fetchForecast(WeatherForecastRequest request) {
    requests.add(request);
    return respond(request);
  }
}

WeatherForecast hourlyTestForecast(
  WeatherForecastRequest request, {
  required DateTime fetchedAt,
  double cloudCover = 10,
  DateTime? missingHour,
}) {
  final start = request.startUtc;
  final hourStart = DateTime.utc(
    start.year,
    start.month,
    start.day,
    start.hour,
  );
  const hour = Duration(hours: 1);
  return WeatherForecast(
    provider: const WeatherProviderMetadata(id: 'mock', name: 'Mock'),
    latitudeDegrees: request.latitudeDegrees,
    longitudeDegrees: request.longitudeDegrees,
    issuedAtUtc: fetchedAt,
    fetchedAtUtc: fetchedAt,
    hours: [
      for (
        var time = start == hourStart ? hourStart : hourStart.add(hour);
        time.isBefore(request.endUtc);
        time = time.add(hour)
      )
        if (time != missingHour)
          HourlyWeatherForecast(
            timeUtc: time,
            totalCloudCoverPercent: WeatherValue.available(cloudCover),
          ),
    ],
  );
}
