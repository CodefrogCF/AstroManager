# Weather Provider Architecture (Issue #15)

## Scope

This issue defines the data boundary for future forecast integrations in
AstroManager. It intentionally adds no network integration, storage, API keys,
or weather-related UI controls. Those belong to subsequent v0.3.0 issues.

The feature follows the project's feature-first structure:

- `lib/features/weather/domain/models/weather_value.dart`: availability model
- `lib/features/weather/domain/models/weather_error.dart`: typed failures
- `lib/features/weather/domain/models/weather_forecast.dart`: normalized hourly forecast and metadata
- `lib/features/weather/domain/providers/weather_provider.dart`: source-independent request and provider contract
- `lib/features/weather/data/weather_forecast_normalizer.dart`: input-unit conversion and validation
- `lib/features/weather/data/mock_weather_provider.dart`: deterministic test source and unconfigured source
- `lib/features/weather/application/weather_providers.dart`: Riverpod dependency injection

## Provider contract

Every weather provider implements `WeatherProvider` and exposes:

- `metadata`: stable provider ID, display name, optional forecast model,
  attribution and homepage
- `fetchForecast(request)`: asynchronous normalized `WeatherForecast`

The request contains a geographic point and an absolute `[startUtc, endUtc)`
interval. Both endpoints must be UTC `DateTime`s, even when a local night
crosses a daylight-saving transition. Providers translate vendor-specific
failures to `WeatherException`.

`weatherProviderProvider` is the single provider-selection point.
`weatherForecastProvider(request)` exposes the common request/response to
Riverpod consumers. No UI widget needs to import a vendor client.

Starting in Issue #16, the default live source is `OpenMeteoWeatherProvider`.
The `UnconfiguredWeatherProvider` remains available for explicit overrides
and tests. Live fetching requires a network connection; the provider does not
fabricate an optimistic forecast when connectivity is unavailable. See
[`open-meteo-provider.md`](open-meteo-provider.md) for the adapter and terms.

## Normalized units

| Parameter | Unit | Allowed range |
| --- | --- | --- |
| Total, low, mid and high cloud coverage | % | 0–100 |
| Precipitation | mm per forecast hour | >= 0 |
| Precipitation probability | % | 0–100 |
| Wind speed and gust | m/s | >= 0 |
| Wind direction (wind coming from) | degrees clockwise from north | [0, 360) |
| Relative humidity | % | 0–100 |
| Visibility | meters | >= 0 |

`WeatherForecastNormalizer` supports input percentages as fractions or
percentages; precipitation as mm/h or in/h; wind in m/s, km/h, mph or knots;
and visibility in meters, kilometers or miles.

Normalized hourly timestamps must be aligned to whole UTC hours. Forecast
hours are sorted strictly ascending. Duplicate hours, impossible parameter
values, nonfinite values, ambiguous timestamps and empty results are errors.
Gaps in the forecast are preserved; no missing hour is interpolated.

## Missing versus unavailable

`WeatherValue<double>.available(0)` means a measured/predicted *zero* value.
`WeatherValue<double>.missing()` means the provider gave no value for that hour.
`WeatherValue<double>.unavailable('not supported')` means the parameter is
explicitly unavailable. Neither state is mapped to zero or clear skies.
Future suitability scores must account for uncertainty rather than treating
missing cloud and precipitation forecasts as favorable conditions.

## Forecast times and freshness

`WeatherForecast.issuedAtUtc` denotes the forecast issue time if known;
`issuedAtIsEstimated` flags an unverified fallback. Open-Meteo does not expose
a reliable model-run issuance timestamp, so its adapter uses the retrieval
time and sets `issuedAtIsEstimated` to `true`.
`WeatherForecast.fetchedAtUtc` denotes when AstroManager retrieved it. Both
timestamps are UTC. `forecast.freshnessAt(now, maximumAge: ...)` calculates how old the
cached response is and whether it is stale. The freshness calculation does not
implement caching, persistent storage, or stale-while-revalidate behavior.

A forecast represents a single geographic point and supplies its provider
metadata and individual UTC hours. It can be stored or scored later without
requiring any network connectivity for calculations over the returned model.

## Typed failures

Weather error types are `invalidRequest`, `notConfigured`, `authentication`,
`rateLimited`, `timeout`, `network`, `providerUnavailable`,
`unsupportedLocation`, `invalidResponse`, `noForecastData`, and `unknown`.

`isRetryable` distinguishes transient errors. `retryAfter` supports provider
rate-limit responses. HTTP adapters preserve the underlying
exception in the diagnostic `cause` field rather than exposing it directly to users.

## Mock example

```dart
final mock = MockWeatherProvider(
  metadata: const WeatherProviderMetadata(id: 'test', name: 'Test'),
  respond: (request) => WeatherForecastNormalizer.normalize(
    provider: const WeatherProviderMetadata(id: 'test', name: 'Test'),
    latitudeDegrees: request.latitudeDegrees,
    longitudeDegrees: request.longitudeDegrees,
    issuedAtUtc: DateTime.utc(2026, 11, 1, 18),
    fetchedAtUtc: DateTime.utc(2026, 11, 1, 19),
    hours: [
      RawHourlyWeather(
        timeUtc: DateTime.utc(2026, 11, 1, 22),
        totalCloudCover: const WeatherValue<double>.available(25),
        lowCloudCover: const WeatherValue<double>.unavailable(),
      ),
    ],
  ),
);

final container = ProviderContainer.test(
  overrides: [weatherProviderProvider.overrideWith((ref) => mock)],
);
final result = await container.read(weatherForecastProvider(request).future);
```

Imports are omitted in the example for brevity. For a real application,
compose the provider at the application layer instead of in widgets.

## Tests

- `test/features/weather/weather_forecast_normalizer_test.dart`
- `test/features/weather/weather_provider_test.dart`

They cover availability semantics, unit conversions, hourly ordering and gaps,
UTC timestamps, bounds checking, freshness, provider swapping and typed errors.

No database schema migration or additional package is required for Issue #15.
