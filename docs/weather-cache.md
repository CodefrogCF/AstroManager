# Weather forecast cache and offline fallback (Issue #17)

## Storage and keys

Weather forecasts are stored in `SharedPreferencesAsync` under the namespace
`astromanager.weather.v1.*`. Each cache record is keyed by exact latitude,
longitude, provider ID, and UTC start/end instants. A different provider or
window never reuses the entry. A serialized JSON record retains the forecast's
**original `issuedAtUtc`, `issuedAtIsEstimated`, and `fetchedAtUtc`** values,
source metadata and all weather-value availability statuses.

The repository defaults to 20 recent entries; it evicts the oldest retrievals.
`shared_preferences` is appropriate for these bounded, non-critical forecasts,
but is not transactional storage and should not be used as a source of truth.
The cache survives application restarts on supported Flutter platforms (when
platform storage is available). No Drift migration or new dependency is needed.

## Freshness and safety

Default reuse TTL: **one hour after retrieval**. When the actual model issue
time is known, it must also be less than **12 hours** old. If issue time was
estimated by Open-Meteo, the approximation is retained and displayed as such;
it is not silently treated as a confirmed publication time.

A device clock earlier than the recorded fetch/issue time results in stale,
not fresh, data. A stale record is revalidated when requested. If that refresh
fails, the cached forecast is returned with `origin=staleFallback`,
`isStale=true`, and `refreshError`. Cached timestamps are never rewritten on
fallback. If the data was still fresh, a failed forced refresh returns the
fresh cache with a visible `refreshError`.

By default, stale records remain accessible indefinitely **but always visibly
stale**; they must not be used as current facts or silently drive suitability
scores. Configure `maximumFallbackAge` to cap this age for a specific use case.

## Riverpod integration

- `weatherForecastProvider(request)` preserves the prior forecast-only API,
  now backed by caching.
- `weatherForecastSnapshotProvider(request)` exposes `forecast`, `origin`,
  `isStale`, `age`, `refreshError`, `refreshInProgress`, `checkedAtUtc`.
- `weatherForecastServiceProvider` owns the refresh logic.
- `weatherCachePolicyProvider` controls TTL and known publication age.
- `weatherCacheRepositoryProvider` may be overridden for tests or alternative
  persistence strategies.

For a forced refresh, call `ref.read(weatherForecastServiceProvider).load(
request, forceRefresh: true)` and update the UI state with the returned snapshot.
For immediate stale display while a refresh starts, set
`staleWhileRevalidate: true`; the refresh runs only while AstroManager's process
is alive. A subsequent load obtains the refreshed data. No OS background task
or guaranteed periodic refresh is claimed.

The service deduplicates concurrent refreshes for the same exact key and
preserves cached data on API failures. Cache I/O failures do not prevent a
live provider request; absent cached data, typed provider failures propagate.

## UI recommendations

Always display a clear label: **Live forecast**, **Cached**, or
**Outdated (offline)**, plus the retrieval time and provider attribution.
Display an API error next to stale fallback and do not use stale weather as
if it were current in recommendation scoring. For long-lived screens, use
`snapshot.isStaleAt(DateTime.now(), policy)` and invalidate the provider on
app resume or a user-initiated refresh; a loaded Riverpod snapshot is not
a continuously ticking clock. Issue-time estimation and
missing parameters should also remain visible where relevant.

## Tests

`test/features/weather/weather_cache_repository_test.dart` tests serialisation,
missing/unavailable values, key isolation, corruption recovery and eviction.
`test/features/weather/weather_forecast_service_test.dart` checks TTL,
publication timestamps, stale fallback, concurrent requests, Riverpod wiring,
and stale-while-revalidate, without network calls or platform storage.
