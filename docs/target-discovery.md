# Target discovery and recommendations (Issue #20)

The Targets screen offers **Discover recommended targets** alongside the
existing OpenNGC catalog browser.

## Inputs

- Selected observing location and its IANA time zone
- Observation date (local calendar date; the night spans local noon to noon)
- Optical profile, or no equipment (field-of-view score then unavailable)
- Object category, text search and persistent favorites
- Minimum target altitude and minimum continuous session duration
- Fresh or cached weather forecasts, including freshness metadata

## Ranking

A bounded local bright-first shortlist (up to 24 objects) is evaluated with
`ObservationWindowRecommendation.forObservingNight`. Explicit favorite IDs
are considered before the shortlist; text searches use the complete local
catalog search. Every target gets at most one recommended window in the list,
with explainable `TargetSuitabilityScore` factors. Equal scores use stable
tie-breakers. This is a *shortlist*, not an exhaustive ranking of all OpenNGC
objects. A later milestone can add scalable indexing / progressive full-catalog
ranking.

Each target is processed asynchronously with a yield between evaluations to
avoid prolonged synchronous event-loop blocking on Flutter Web. Changing a
filter invalidates the previous computation. No astronomical or scoring
computation calls the network directly.

## Missing weather

The UI distinguishes network, fresh cache, stale cache and unavailable weather.
Scores continue in provisional mode without weather, respecting the
conservative ceiling from Issue #18. Stale forecasts are **not** treated as
fresh. Refreshing the view may reuse a fresh forecast under the cache policy;
no forced cache bypass is implied by the UI button.

## Local time

Window instants remain UTC internally and are formatted via the selected
observing location's IANA time zone for display, including DST changes.

## Storage

Favorite IDs are stored in the existing `app_settings` key-value table under
`discovery.favoriteTargetIds.v1`; no database migration is required.

## Limitations

This first UI intentionally evaluates at most 24 candidate objects in one pass.
Heuristic suitability scores are not calibrated predictions of image quality.
There is no guarantee that the highest-ranked object in the shortlist is the
best object in the complete catalog.
