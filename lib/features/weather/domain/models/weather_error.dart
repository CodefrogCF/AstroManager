/// Stable classifications for weather errors, independent of a vendor's API.
enum WeatherErrorType {
  invalidRequest,
  notConfigured,
  authentication,
  rateLimited,
  timeout,
  network,
  providerUnavailable,
  unsupportedLocation,
  invalidResponse,
  noForecastData,
  unknown,
}

/// Typed error contract for all weather providers and normalization adapters.
///
/// Adapters should translate HTTP and parsing exceptions to this type before
/// they reach the application layer. [cause] is for diagnostics, not UI display.
final class WeatherException implements Exception {
  const WeatherException({
    required this.type,
    required this.message,
    this.providerId,
    this.retryAfter,
    this.cause,
  });

  final WeatherErrorType type;
  final String message;
  final String? providerId;
  final Duration? retryAfter;
  final Object? cause;

  bool get isRetryable => switch (type) {
    WeatherErrorType.rateLimited ||
    WeatherErrorType.timeout ||
    WeatherErrorType.network ||
    WeatherErrorType.providerUnavailable => true,
    _ => false,
  };

  @override
  String toString() =>
      'WeatherException(${type.name}, provider: ${providerId ?? 'none'}): '
      '$message';
}
