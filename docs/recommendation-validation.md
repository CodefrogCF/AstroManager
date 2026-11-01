# Recommendation and suitability regression validation (Issue #21)

## Scope

`test/features/intelligence/recommendation_validation_test.dart` is a
cross-engine regression suite. It verifies the integration between:

- The astronomical coordinate and solar/lunar computations
- `AstrophotographySuitabilityScoring` (interval score 0–100)
- `ObservationWindowRecommendation` (candidate filtering and ranking)
- Normalized weather snapshots, including missing and stale values

This suite complements, rather than replaces, the more detailed unit tests
already colocated with the respective engines. No real HTTP requests, live
weather APIs, system clocks, databases, or platform settings are involved.

## Fixed fixtures and their interpretation

File: `test/features/intelligence/fixtures/recommendation_scenarios.dart`

- Observer: 47.48° N, 8.21° E, elevation 400 m, `Europe/Zurich`
- Primary synthetic target: RA 80°, Dec +89.5° (J2000); continuously high
  enough at the fixed site to keep weather comparisons independent of horizon
  transitions
- Unobservable target: Dec −80°, which cannot reach +30° altitude from
  47.48° N
- Baseline: 2026-11-01 20:00–22:00 UTC, within astronomical darkness
- Forecast issue: 2026-11-01 19:20 UTC; retrieval: 19:30 UTC; evaluation:
  19:40 UTC, so the baseline forecast is demonstrably fresh
- All hourly data is supplied at UTC hour boundaries. Missing hours and
  measurements remain missing rather than being interpolated or set to zero

These synthetic objects are **geometric test fixtures**, not claims about
actual catalog photography targets. The scoring weights are planning
heuristics, not a physical model of image quality.

## Acceptance/regression matrix

| Requirement | Regression test intent |
| --- | --- |
| Stable, bounded scores | Identical inputs, deterministic contributions, all six factors, 0–100 limits |
| Scientific geometric plausibility | J2000 meridian/zenith, polar visibility, independently evaluated night/day |
| Favorable vs unfavorable | Clear vs 100% cloud, dry vs rain, real bright-Moon proximity |
| Honest missing data | Fully missing, stale, missing cloud layers/hours, wrong-site forecasts |
| Explainability | Each factor reports status, coverage, contribution, and explanation |
| Hard exclusions | Daylight and target below the minimum elevation cannot score positively |
| Configurable weighting | Normalized 1:3 altitude/weather weights and targeted contribution tests |
| Valid observation sessions | Minimum duration, complete darkness inclusion, unobservable target exclusion |
| Disjoint windows | Separate dark nights do not connect over daytime |
| Midnight and DST | UTC midnight crossing, Zurich spring 23-hour and autumn 25-hour local nights |
| Stable ranking | Scores descending and identical order regardless of input target order |
| Defensive validation | Reversed/non-UTC intervals, duplicate targets and invalid weights/options |

The full test suite uses `flutter test` in the existing GitHub Actions `quality`
job. No duplicate CI workflow or database migration is needed.

## Numeric references and tolerances

- J2000 epoch: 2000-01-01 12:00 UT; GMST = 280.46061837° by the classical
  sidereal-time polynomial. An equatorial target with RA = GMST and Dec = 0°
  is at the zenith for a Greenwich equatorial observer. Test tolerance 0.001°.
- A Dec +89.5° target at 47.48° N has altitude within approximately 1° of
  site latitude independent of hour angle. The bounded fixture asserts 45–50°.
- Night/day assertions use physical solar-altitude thresholds rather than
  asserting fixed published rounded sunrise and twilight times.
- Moon phase / elevation and separation are computed from the existing local
  Meeus-based lunar model. The test selects a **deterministic** dark instant
  near the November 2026 full Moon and verifies that the synthetic target
  colocated with the Moon has low lunar suitability. This checks integration,
  not sub-arcsecond positional accuracy.
- Weather score monotonicity is tested by changing **only one** input factor
  while all other coordinates, times, equipment, and weights stay fixed.

## Running validation

```powershell
flutter pub get --enforce-lockfile
dart format lib test
flutter analyze
flutter test test/features/intelligence/recommendation_validation_test.dart
flutter test
```

The repository already runs `dart format --output=none --set-exit-if-changed
lib test`, `flutter analyze --no-pub`, and `flutter test --no-pub` as part of
its GitHub Actions quality job.

### Limitations

Results certify *deterministic implementation behavior* against documented
requirements, not meteorological forecast skill or scientifically calibrated
astrophotography success probabilities. Empirical calibration would require
actual observing-session outcomes over a range of sites, equipment, weather,
and targets.
