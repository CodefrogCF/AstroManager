# Lunar Ephemeris and Target Separation (Issue #13)

## Scope

`lib/core/astronomy/lunar_ephemeris.dart` provides an offline Moon model for
planning astrophotography sessions. No new dependencies, schema changes or
network calls are needed. The Night Planner and target detail panel consume
this service without persisting calculated ephemerides.

## Coordinate and time conventions

- UTC `DateTime` denotes the observing instant. Date and time inputs are
  independent of the device time zone.
- Geocentric lunar ecliptic longitude and latitude use Meeus Chapter 47,
  Tables 47.A/B (60 periodic longitude/radius terms, 60 latitude terms),
  referred to the **mean equinox of date**, without nutation.
- Equatorial RA/Dec are also **of date**, not J2000.
- Topocentric RA/Dec and geometric altitude/azimuth include lunar horizontal
  parallax and the observing site's geodetic latitude and elevation.
- Azimuth: 0° north, 90° east; altitude: geometric center, no refraction.
- The target's **mean J2000** catalog RA/Dec is precessed to date using Issue
  #11 before computing the angular separation from the Moon's **topocentric**
  RA/Dec. The angular separation therefore varies with observing site.
- Lunar phase runs 0 (new) → 0.25 (first quarter) → 0.5 (full) → 0.75 (last
  quarter) → 1 (next new); phase labels are eight approximate sectors.
- Illuminated fraction uses the Sun–Earth–Moon phase angle, approximating the
  Earth–Sun distance as 1 AU, and is clamped to [0, 1]. It is not a calibrated
  measurement of surface brightness.

## Events

- `calculateForLocalDate` samples local midnight-to-midnight in the site's
  IANA time zone.
- `calculateForObservingNight` samples local noon through the following local
  noon, keeping one observing night intact across midnight and DST changes.
- Each root is bracketed on a **5-minute UTC grid** and bisected to approximately
  **1 second**. Local event times include the correct DST UTC offset.
- Rise/set is defined as apparent contact of the Moon's upper limb with a
  level, unobstructed horizon: topocentric geometric center altitude equals
  `-(0.5667° + asin(1737.4 km / geocentric distance))`.
- Weather, atmospheric pressure, refraction variations and mountain skyline
  are not modeled; the observer's elevation affects lunar parallax, not
  horizon dip.
- The result preserves **all** crossings; either a rise or set may be absent
  on a given local day. If no event occurs, `alwaysAbove` or `alwaysBelow`
  describes the starting horizon condition. A missing event is not fabricated.

## Validation and documented tolerances

- Meeus Chapter 47 example 47.a (1992-04-12 00:00 TT): ecliptic longitude
  **133.162655°**, latitude **−3.229126°**, distance **368409.7 km**.
  Unit-test tolerances: ±0.03° and ±100 km. UTC approximates TT; the reference
  epoch is TT, so a small angular offset is expected.
- Timeanddate Zürich 03 Nov 2026: moonrise **00:26 CET**, moonset **14:36 CET**.
  Unit-test event tolerance: **±20 minutes**. Measured differences depend on
  ephemeris, observer altitude, refraction and horizon definition.
- 09 Nov 2026 near new Moon: <1% illuminated. 24 Nov 2026 near full Moon:
  >99% illuminated. 01 Nov 2026 is approximately last quarter.
- Additional tests cover moon-target collinearity, opposites, topocentric
  parallax, days with one event, absence of both events in polar regions,
  observation nights spanning midnight, and 23/25-hour local days.

## Limitations

Meeus uses ephemeris time **TT**, but this app currently approximates TT with
UTC. ΔT/UT1 corrections, nutation, lunar libration, anomalous refraction,
local terrain obstructions, and precise apparent-place transformations are not
included. The implementation is suitable for **planning**, not high-precision
astrometry or observatory pointing. Target suitability scoring is intentionally
reserved for Issue #14; phase and separation alone do not determine skyglow.

## Source and attribution

Periodic tables and lunar ecliptic position algorithms were adapted from the
MIT-licensed Go implementation by Sonia Keys (copyright 2013):

- <https://github.com/soniakeys/meeus/blob/master/v3/moonposition/moonposition.go>
- `docs/licenses/meeus_mit_license.txt` (full original MIT permission notice)
- <https://github.com/soniakeys/meeus/blob/master/LICENSE>

Reference example and methodology:

- <https://pymeeus.readthedocs.io/en/latest/examples/ex-Moon.html>
- <https://www.timeanddate.de/mond/schweiz/zuerich?month=11&year=2026>
