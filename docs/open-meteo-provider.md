# Open-Meteo Forecast Provider (Issue #16)

## Scope

AstroManager's default live `WeatherProvider` is `OpenMeteoWeatherProvider`.
It uses the Open-Meteo Forecast API at `https://api.open-meteo.com/v1/forecast`.
The provider adapter is in `lib/features/weather/data/`, and the UI and
astronomical calculation engine do not depend on Open-Meteo APIs.

The free endpoint does not require an API key for **non-commercial** use. It
requires a network connection to fetch live forecasts. No caching or offline
fallback is implemented in Issue #16; those belong to a subsequent issue.
Tests use an injected `http.Client` and never call the live API.

## Parameters

The adapter requests:

| Open-Meteo parameter | AstroManager normalized value | Unit |
| --- | --- | --- |
| `cloud_cover` | total cloud coverage | percent |
| `cloud_cover_low` | low cloud coverage | percent |
| `cloud_cover_mid` | middle cloud coverage | percent |
| `cloud_cover_high` | high cloud coverage | percent |
| `precipitation` | precipitation per hourly interval | mm/h |
| `precipitation_probability` | precipitation probability | percent |
| `wind_speed_10m` | surface wind speed | m/s |
| `wind_gusts_10m` | surface wind gusts | m/s |
| `wind_direction_10m` | wind direction (from) | degrees |
| `relative_humidity_2m` | relative humidity | percent |
| `visibility` | horizontal visibility | meters |

The HTTP request uses `timezone=UTC`, `timeformat=unixtime`,
`wind_speed_unit=ms`, `precipitation_unit=mm`, and the selected model
(default: `best_match`). UTC Unix-second timestamps preserve distinct
observation hours during daylight-saving changes. A requested window is
`[startUtc, endUtc)`; the adapter requests the encompassing UTC calendar days
and filters hourly samples locally. Values outside the window are excluded.
No missing hours are interpolated.

## Missing / unavailable / invalid data

- A supplied `0` is a real zero and remains `WeatherValue.available(0)`.
- A JSON `null` reading within a returned hourly array becomes `missing`.
- An omitted hourly parameter becomes `unavailable`.
- A model explicitly rejecting a named hourly parameter with an HTTP 400
  response triggers one bounded retry omitting that parameter; it becomes
  `unavailable` in the result. No generic error is silently converted to
  unavailable weather.
- Unexpected units, incorrect array lengths, invalid numbers and ambiguous
  timestamps produce typed `invalidResponse` errors.
- HTTP rate limits, authentication failures, invalid requests, timeouts and
  network failures map to the common `WeatherException` contract.

Different forecast models can support different variables. A parameter
missing from a response must **never** be interpreted as ideal conditions.

## Forecast issuance and freshness

Open-Meteo's Forecast API response does not reliably provide the issuance time
of the underlying selected numerical weather model. AstroManager's existing
`WeatherForecast` model requires `issuedAtUtc`. This adapter uses
`fetchedAtUtc` for that field as an explicitly documented **proxy**, not a
verified model-run timestamp, and marks `issuedAtIsEstimated = true`. Do not label it as an actual model issue time.
Cache freshness must use `fetchedAtUtc` as implemented in Issue #15.
When Open-Meteo eventually exposes a verifiable model issue time, this adapter
can supply it without changing UI components.

## Attribution and usage conditions

Display this credit with any Open-Meteo forecast data:

**Weather data by [Open-Meteo.com](https://open-meteo.com/)**

The underlying data is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Appropriate
attribution and indication of alterations (for example unit conversions and
filtering) are required. The normalized forecast is derived from Open-Meteo
data; AstroManager converts units and selects requested hours. Individual
weather-model/source attribution may also be required in specific cases.

The free hosted Forecast API is offered for non-commercial use (at the time of
implementation, up to 10,000 calls/day under its published conditions).
Commercial use requires an appropriate Open-Meteo subscription, a licensed
endpoint or another permitted provider. The data CC BY 4.0 license must not be
confused with a license for unrestricted commercial use of the free hosted
API. Model availability and usage conditions can change; check current terms.

Sources:
- https://open-meteo.com/en/docs
- https://open-meteo.com/en/pricing
- https://open-meteo.com/en/terms
- https://github.com/open-meteo/open-meteo

## Replaceability

`weatherProviderProvider` now defaults to `OpenMeteoWeatherProvider`. Other
providers can still be supplied using Riverpod overrides:

```dart
weatherProviderProvider.overrideWith((ref) => myWeatherProvider),
```

Production users should not render a successful HTTP request as a trustworthy
weather forecast automatically. The caller is responsible for checking
`WeatherForecast.hours`, freshness and parameter availability before scoring
or making recommendations.

## Testing

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test test/features/weather
flutter test
```

The `open_meteo_*_test.dart` tests use `http/testing.dart` (`MockClient`) and
in-memory JSON fixtures; they do not consume any hosted API quota.
