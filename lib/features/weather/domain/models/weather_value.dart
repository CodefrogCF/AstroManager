/// Availability is independent of the numeric value of a weather parameter.
///
/// In particular, zero cloud coverage must be represented by [available],
/// never by [missing] or [unavailable].
enum WeatherValueStatus { available, missing, unavailable }

/// A provider-independent weather parameter.
///
/// [missing] means the provider did not supply a value for this hour.
/// [unavailable] means it explicitly cannot supply the parameter (for example,
/// because its forecast model does not support cloud-layer breakdowns).
final class WeatherValue<T> {
  const WeatherValue.available(T value)
    : this._(WeatherValueStatus.available, value, null);

  const WeatherValue.missing() : this._(WeatherValueStatus.missing, null, null);

  const WeatherValue.unavailable([String? reason])
    : this._(WeatherValueStatus.unavailable, null, reason);

  const WeatherValue._(this.status, this.value, this.reason);

  final WeatherValueStatus status;
  final T? value;
  final String? reason;

  bool get isAvailable => status == WeatherValueStatus.available;
  bool get isMissing => status == WeatherValueStatus.missing;
  bool get isUnavailable => status == WeatherValueStatus.unavailable;

  /// Does not substitute any default for missing or unavailable data.
  T? get valueOrNull => isAvailable ? value : null;

  WeatherValue<R> map<R>(R Function(T value) convert) {
    return switch (status) {
      WeatherValueStatus.available => WeatherValue<R>.available(
        convert(value as T),
      ),
      WeatherValueStatus.missing => WeatherValue<R>.missing(),
      WeatherValueStatus.unavailable => WeatherValue<R>.unavailable(reason),
    };
  }

  @override
  String toString() => switch (status) {
    WeatherValueStatus.available => 'WeatherValue.available($value)',
    WeatherValueStatus.missing => 'WeatherValue.missing()',
    WeatherValueStatus.unavailable => 'WeatherValue.unavailable($reason)',
  };
}
