# Issue #18 — Interval-based astrophotography suitability scoring

## Scope

`AstrophotographySuitabilityScoring.score` is a pure Dart calculation and
requires no HTTP client, storage, platform service, Flutter widget or clock.
All input instants must be UTC and `evaluatedAtUtc` must be explicitly supplied.
Each call evaluates **one interval** (up to 48 hours). The caller can evaluate
multiple candidate intervals to rank and select imaging windows in later issues.

Integration:

- OpenNGC `CelestialObject` (J2000 equatorial position and angular dimensions)
- `ObserverPosition` (geographic site)
- `TargetVisibility.calculate` for visibility duration
- `SolarEvents.sunAltitudeDegrees` for astronomical darkness (< −18°)
- `LunarEphemeris.conditionsForTarget` for topocentric Moon altitude,
  illuminated fraction and Moon–target separation
- `WeatherForecastSnapshot` plus `WeatherCachePolicy` for provider-independent
  forecast values, cache state and freshness
- `OpticalMetrics` from the existing equipment inventory for field of view

The scoring engine does **not** fetch forecasts or read the cached data.
The caller supplies the weather snapshot returned by the weather service.

## Scoring equation

Each factor has a documented score `s_i` from 0 to 100 and a nonnegative
configurable weight `w_i`. The aggregate is:

`raw = sum(w_i * effective(s_i)) / sum(w_i)`

`effective(s_i) = 0` if the factor is missing. Missing values are **not**
renormalized away or replaced with ideal weather. Each factor reports its
raw score (nullable), normalized weight, weighted contribution, explanation,
and data coverage (0..1). The final result includes weighted data coverage,
a provisional flag and blocking constraints.

Default weights (heuristics, not scientifically universal):

| Factor | Weight | Method |
| --- | ---: | --- |
| Altitude | 0.18 | Best altitude while simultaneously dark and above minimum; linearly scales from configurable min (default 30°) to good (default 65°) |
| Visible duration | 0.12 | Continuous target-above-minimum duration divided by the full interval |
| Astronomical darkness | 0.20 | Fraction of interval with solar center below −18° |
| Weather | 0.28 | Normalized, weighted measurements over UTC hours |
| Moonlight | 0.14 | Average lunar quality over usable dark/visible time |
| Optical field of view | 0.08 | Catalog angular axes relative to framing field of view |

The default profile can be replaced or weights configured using
`SuitabilityScoringProfile(weights: SuitabilityWeights(...))`.
For example, wide-field targets may benefit from higher framing weight,
while narrowband targets may use a lower moonlight weight. No profile is
claimed to be objectively optimal for all targets.

## Hard constraints and incomplete data

- If there is no astronomical darkness, no target altitude visibility, or
  no overlap of the two, the score is **0**, regardless of other factors.
- If no fresh usable weather is supplied, the weather factor contributes **0**
  and the final score is capped at **50/100** by default. This cap is
  configurable via `maximumScoreWithoutWeather`.
- A stale forecast, even from an offline fallback, is treated as *missing
  for suitability ranking* by default. The weather cache may still display
  the original measurements with appropriate stale labels elsewhere.
- A forecast for coordinates more than 0.02 degrees from the site is rejected
  as unsuitable context.
- An unsupported or absent forecast parameter contributes no positive points.
  A partially available forecast yields partial coverage and a provisional
  score, not an inferred ideal reading. Missing UTC forecast hours are
  likewise treated as missing.
- Missing catalog size or optical profile is reported as missing framing
  information, with zero weighted contribution.
- A catalog missing one angular dimension is scored provisionally using the
  known size for both axes and a 50% discount. No target orientation or
  advanced mosaic calculations are modeled.

## Weather subweights and units

An available hourly reading is scored using these heuristic contributions:

| Weather variable | Share of weather factor | Good to poor |
| --- | ---: | --- |
| Total cloud cover | 38% | 0% → 100% |
| Low / mid / high clouds | 8% / 8% / 6% | 0% → 100% |
| Precipitation amount | 12% | 0 → ≥1.5 mm/h |
| Precipitation probability | 12% | 0% → 100% |
| Wind speed | 6% | ≤3 → ≥12 m/s |
| Wind gust | 4% | ≤5 → ≥16 m/s |
| Humidity | 3% | ≤60% → ≥95% |
| Visibility | 3% | ≤1 km → ≥20 km |

Unknown measurements do not inherit another variable's score. Measurements
are selected by their UTC forecast-hour start. Hour and interval samples are
weighted by the actual elapsed number of microseconds.

## Lunar model

Moon below the geometric horizon: lunar factor = 100.
Moon above horizon: quality = 100 × [1 − illumination × proximity], where
`proximity = clamp((90° − separation) / 80°, 0, 1)`.
Thus a full Moon within 10° of the target scores 0 for lunar interference;
a Moon 90° or more away scores 100 for this **heuristic** factor. It does
not simulate aerosol scattering, local light pollution or narrowband filters.

## Accuracy and limitations

- Altitude and solar/lunar factors use **midpoint samples** every 10 minutes by
  default (configurable from 1 minute to 1 hour). A transition shorter than
  the sample step can be missed; darkness/usable durations are approximate
  to within roughly one sample at each boundary.
- `TargetVisibility.calculate` separately refines the target altitude
  threshold-crossing intervals to approximately one second. Its duration
  is measured over the full requested interval, not just darkness.
- No terrain obstruction, atmospheric refraction in target altitude,
  seeing, guiding, tracking error, surface brightness, exposure length,
  ambient light pollution, sensor noise or optical aberrations are scored.
- The framing factor compares rectangular field sizes allowing a 90° rotation;
  it does not calculate exact target footprints or automatically plan mosaics.
- Recommendations should show factor explanations and data coverage rather
  than presenting 0..100 scores as scientifically calibrated percentages.

## Example

```dart
final result = AstrophotographySuitabilityScoring.score(
  target: catalogObject,
  observer: observerPosition,
  startUtc: DateTime.utc(2026, 11, 1, 20),
  endUtc: DateTime.utc(2026, 11, 2, 0),
  evaluatedAtUtc: DateTime.utc(2026, 11, 1, 19),
  weather: weatherSnapshot,
  optics: opticalMetrics,
  profile: const SuitabilityScoringProfile(),
);

print(result.score); // 0..100
print(result.isProvisional);
print(result.factor(SuitabilityFactor.weather).explanation);
```

## Tests

`flutter test test/features/intelligence/astrophotography_suitability_scoring_test.dart`

Tests exercise determinism, inspectable factor contributions, invalid
weights, darkness and altitude gating, midnight intervals, clouds,
incomplete/stale/mismatched forecast data, field-of-view mismatch and
lunar brightness/target separation reference geometry.
