# Target Visibility Calculations — Issue #14

## Scope

`lib/core/astronomy/target_visibility.dart` provides deterministic, offline
visibility for fixed OpenNGC targets with mean J2000 right ascension and
declination. No additional packages or database migration are needed.

The engine builds on the IAU-1976 precession, mean sidereal time, and geometric
horizontal transformation from `astronomical_coordinates.dart`. The nighttime
helper uses astronomical darkness from `solar_events.dart`.

## Public API

### Arbitrary UTC observation period

```dart
final result = TargetVisibility.calculate(
  targetJ2000: const EquatorialPosition(
    raDegrees: 10.6848,
    decDegrees: 41.2691,
  ),
  observer: const ObserverPosition(
    latitudeDegrees: 47.3769,
    longitudeDegrees: 8.5417,
  ),
  startUtc: DateTime.utc(2026, 11, 1, 17),
  endUtc: DateTime.utc(2026, 11, 2, 5),
  minimumAltitudeDegrees: 30,
);
```

`allowedIntervals` can optionally provide disjoint UTC spans to limit the
calculation (for example to a weather forecast's clear-sky periods). Overlaps
are merged and out-of-period portions are clipped. A null list allows the whole
period; an empty list allows no time.

### Night at a saved observing location

```dart
final result = TargetVisibility.forObservingNight(
  targetJ2000: EquatorialPosition(
    raDegrees: target.raDegrees,
    decDegrees: target.decDegrees,
  ),
  location: selectedLocation,
  localDate: DateTime.utc(2026, 11, 1),
  minimumAltitudeDegrees: 30,
);
```

The helper calculates the window from **local noon until next local noon**.
The Targets panel identifies the observation night containing the selected
UTC instant using the observing site’s local time (before noon = previous
local calendar date).
By default it intersects altitude visibility with times when the geometric Sun
is **below -18°**. The time-zone-aware period duration can be 23, 24 or 25
hours on daylight-saving transitions.

Set `requireAstronomicalDarkness: false` to obtain altitude-only visibility
for the full noon-to-noon window.

### Result fields

- `samples`: UTC timestamp, altitude and azimuth throughout the requested
  period, including both endpoints.
- `culminations`: upper meridian transits (hour angle zero), which may be empty
  in short windows or contain multiple entries in longer windows.
- `maximumPeriodSample`: highest position in the *full* requested period,
  even if it occurs in daylight.
- `bestVisiblePosition`, `bestTimeUtc`, `bestAltitudeDegrees`,
  `bestAzimuthDegrees`: highest qualifying position in an allowed visibility
  interval, or null if none qualifies.
- `allowedIntervals`: allowed observation times after normalization.
- `visibleIntervals`: contiguous UTC intervals meeting the altitude cutoff
  within the allowed spans.
- `totalVisibleDuration`, `totalAllowedDuration`, `visibleFraction`.
- `state`: `continuouslyVisible`, `partiallyVisible` or `notVisible`.

The *continuous* classification is relative to the **allowed** intervals, not
necessarily to the complete 24-hour day. A physically circumpolar star can be
continuously visible for the whole night while filtered daylight is excluded.
If there is no astronomical darkness, the state is `notVisible` even if the
object is geometrically above the horizon throughout the period.

## Algorithm and precision

1. Compute geometric altitude and azimuth at a configurable sampling cadence
   (default 5 minutes).
2. Find threshold crossings and refine them with bisection to roughly one
   second.
3. Calculate upper culmination by identifying signed hour-angle zero
   crossings, excluding the ±180° wrap; refine by bisection.
4. Locate the highest altitude in the observation period and within qualified
   visible spans by a local golden-section refinement around the best sample.
5. Intersect with the specified allowed intervals (astronomical darkness by
   default in the night helper).

The input period is limited to 31 days and the sampling step to 1–60 minutes.
The engine does **not** guarantee discovery of an extremely short crossing
entirely between sample points. Reduce `sampleStep` to 1 minute for targets
near the chosen altitude threshold or very short windows.

## Conventions and caveats

- Altitude is *geometric*, not refraction-corrected; terrain and artificial
  obstructions are ignored.
- J2000 coordinates are precessed to the observation date (IAU 1976).
- UTC approximates UT1. No nutation, proper motion or aberration correction.
- Azimuth follows north=0°, east=90°, south=180°, west=270°.
- Minimum altitude is inclusive; output visibility intervals are represented
  as half-open ranges [startUtc, endUtc).
- At the zenith or nadir, azimuth may be undefined.
- No weather, skyglow, or Moon-interference weighting is applied; Issue #13
  provides lunar data for later suitability scoring.

## Reference validation

The mathematical tests independently apply the classical spherical formula

`sin(h) = sin(latitude) sin(declination) + cos(latitude) cos(declination) cos(H)`

with the published sidereal rate of 360.98564736629°/UTC day and the J2000
GMST reference 280.46061837° at 2000-01-01 12:00 UTC.

At Greenwich on the equator, a declination-zero target on the meridian is at
90° altitude. With a 30° limit, `|H| <= 60°` and the expected time above the
cutoff is about 7 h 58 m 42 s. A 45° northern latitude and dec=0 yield a
45° upper-culmination altitude. Tests also cover high-declination
circumpolar/never-rising objects, disjoint intervals, no darkness, midnight,
DST changes and determinism.

Sources:
- US Naval Observatory: https://aa.usno.navy.mil/faq/alt_az
- University of Nebraska–Lincoln: https://astro.unl.edu/naap/motion2/starpaths.html

## Validation commands

```powershell
dart format lib test
flutter analyze
flutter test test/core/astronomy/target_visibility_test.dart
flutter test test/features/targets/target_visibility_panel_test.dart
flutter test
```
