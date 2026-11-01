# Solar events and astronomical darkness (Issue #12)

AstroManager calculates the geometric altitude of the Sun at arbitrary UTC
instants and finds threshold crossings on an **observing location's local civil
date**. The implementation is offline and reuses the existing `timezone`
package and saved observing locations.

## Solar thresholds

| Event | Solar center altitude | Convention |
|---|---:|---|
| Sunrise / sunset | -0.8333° | Conventional disk radius and refraction |
| Civil twilight | -6° | Geometric |
| Nautical twilight | -12° | Geometric |
| Astronomical twilight | -18° | Geometric |

Solar coordinates use a Meeus/NOAA-style approximate apparent solar longitude,
obliquity and equatorial coordinates. The hour angle is calculated with mean
sidereal time from Issue #11. A two-minute UTC scan followed by bisection finds
the crossings to approximately one-second numerical resolution; this does
**not** imply one-second physical accuracy.

## Time zones and night boundaries

`calculateForLocalDate` interprets the supplied year, month and day in the
selected observing location's IANA zone. Calendar boundaries are constructed
with `TZDateTime(zone, year, month, day)` and `TZDateTime(zone, year, month,
day + 1)`; **never** add 24 hours to obtain the next local date.

The `SolarDayEvents` sunrise/sunset and twilight events are restricted to the
selected local civil date (00:00 to the next local 00:00). The astronomical
darkness intervals instead cover **local noon on the selected date through local
noon on the next date**, keeping a complete observing night together across
midnight. UTC instants determine durations and ordering; formatted times include
the date and UTC offset to disambiguate DST transitions.

At high latitudes, thresholds may have no crossings. A threshold can remain
`alwaysAbove` or `alwaysBelow`; the API returns `null` for missing dawn/dusk
and zero or more darkness intervals, including continuous darkness clipped to
the noon-to-noon night.

## Limitations

- Sunrise assumes a flat, unobstructed sea-level horizon and average
  refraction. Elevation and local terrain are not used to correct the horizon.
- Atmospheric extinction, clouds, artificial light and Moon brightness are
  not modeled. The Moon is handled separately in Issue #13.
- UTC approximates UT1; high-precision nutation and apparent sidereal
  corrections are omitted.
- Near the polar circles small changes in atmospheric conditions can cause
  significantly different observed rise/set times.
- This is an observation-planning tool, not a precision ephemeris.

## Validation references

- USNO Rise/Set/Twilight definitions:
  https://aa.usno.navy.mil/faq/RST_defs
- NOAA Solar Calculation Details (Meeus-based equations and uncertainty):
  https://gmd-prod.cmdl.noaa.gov/grad/solcalc/calcdetails.html
- Zürich, 1 November 2026, published rounded local events:
  https://www.timeanddate.com/sun/switzerland/zurich?month=11&year=2026

The tests compare all eight Zurich crossings against those published values
with a ±3 minute tolerance and check the -18° threshold numerically. Separate
tests cover polar day/night, partial polar twilight, local dates with 23 and 25
hours, repeated wall-clock times, and observing nights across a DST shift.
