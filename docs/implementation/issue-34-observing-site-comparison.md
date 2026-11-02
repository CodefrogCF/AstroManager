# Issue #34 — Observing Site Comparison

## Entry point and behavior

**Settings → Observing Locations → Compare observing sites** (requires at least two saved locations).
Select two or more locations, a catalog target linked to an imaging project, and a common
**local calendar date**. Each site's observing night spans **local noon to the following local noon**;
UTC start/end differ across time zones and through daylight-saving transitions.
No remote data is fetched when opening the list of observing locations. Click **Compare selected
sites** to request available forecasts, optional terrain profiles, and optional VIIRS imagery.

## Data and computation

- Target position and astronomical darkness: existing offline SolarEvents and TargetVisibility.
- Weather: cached Open-Meteo WeatherForecastService, keyed to each site's coordinates and UTC night.
  Only eligible current/future dates receive requests. Stale, out-of-location, absent, and incomplete
  forecast values are not assumed to mean clear skies.
- Terrain: the existing DEM elevation provider and cached horizon calculator, sampled using 15°
  azimuth resolution, 15 km range and 1.5 km radial spacing. Terrain-adjusted target visibility
  is recomputed for each site, and the heuristic baseline score is reduced proportionally to the
  loss of dark target visibility. A missing or incomplete DEM is explicitly reported; the latter
  yields **an upper estimate**. Small hills, vegetation, buildings, and atmospheric refraction are
  not modeled. Terrain requests may be slow on public rate-limited endpoints.
- Light pollution: optional locally cached monthly satellite VIIRS *upward radiance*, with unit
  `nW/cm²/sr`, source and acquisition month retained. Measurements from different source/month
  combinations are excluded from cross-site scoring. Upward radiance is **not** measured sky
  brightness, an SQM reading, or a Bortle class. Unavailable/stale data is missing, not dark.
- Scoring: the existing `AstrophotographySuitabilityScoring` service, with one comparison-specific
  common weight profile. No optical setup is selected, so the field-of-view factor has zero weight.
  Weather weight is 0.29 without the optional VIIRS factor and 0.27 with it. If VIIRS is enabled,
  it has 0.06 weight. Scores are 0–100 heuristics with explicit source explanations; the existing
  no-weather ceiling of 50 is retained. The terrain availability reduction is applied after base
  scoring. **Scores are not probabilities or objective measures of image quality.**

A missing source can result in a lower score and a provisional comparison, not an optimistic
neutral value. It is possible for a result with incomplete data to rank first: the UI labels it
as a *leading estimate*, shows every missing factor, and provides expandable explanations.
Site labels are stable on ties using location IDs, with data completeness as a tiebreaker.

## Testing

- Common target/date, different IANA time zones and DST-crossing nights.
- Site-specific forecasts, including a deliberately mismatched location.
- Empty/missing data and conservative weather cap.
- Full terrain obstruction compared with unobstructed DEM.
- Relative VIIRS radiance values and provenance.
- Multiple-site selection and opt-in toggles in widget tests.

No database migration, API keys, new packages, or background tasks are required.
