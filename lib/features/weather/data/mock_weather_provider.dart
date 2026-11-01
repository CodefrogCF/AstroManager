import '../domain/models/weather_error.dart';
import '../domain/models/weather_forecast.dart';
import '../domain/providers/weather_provider.dart';

/// In-memory provider for automated tests and development fixtures.
///
/// The callback can return any normalized forecast for the request. This mock
/// never calls a network service. Configure [failure] to test error states.
final class MockWeatherProvider implements WeatherProvider {
  MockWeatherProvider({
    required this.metadata,
    required this.respond,
    this.failure,
  });

  @override
  final WeatherProviderMetadata metadata;
  final WeatherForecast Function(WeatherForecastRequest request) respond;
  final WeatherException? failure;
  final List<WeatherForecastRequest> requests = [];

  @override
  Future<WeatherForecast> fetchForecast(WeatherForecastRequest request) async {
    request.validate();
    requests.add(request);
    if (failure != null) {
      throw failure!;
    }
    final forecast = respond(request);
    forecast.validate();
    if (forecast.provider.id != metadata.id) {
      throw WeatherException(
        type: WeatherErrorType.invalidResponse,
        message: 'Mock response provider ID differs from configured provider.',
        providerId: metadata.id,
      );
    }
    return forecast;
  }
}

/// Safe default until a real provider is configured in a later issue.
final class UnconfiguredWeatherProvider implements WeatherProvider {
  const UnconfiguredWeatherProvider();

  @override
  WeatherProviderMetadata get metadata => const WeatherProviderMetadata(
    id: 'unconfigured',
    name: 'No weather provider configured',
  );

  @override
  Future<WeatherForecast> fetchForecast(WeatherForecastRequest request) async {
    request.validate();
    throw const WeatherException(
      type: WeatherErrorType.notConfigured,
      message: 'No weather forecast provider has been configured.',
    );
  }
}
