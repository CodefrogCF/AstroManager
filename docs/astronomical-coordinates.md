# Astronomical Coordinate Calculations

## Overview

AstroManager includes a pure Dart astronomical coordinate
calculation module.

File:
`lib/core/astronomy/astronomical_coordinates.dart`

No database, platform service or network connection is
required to perform these calculations.

## Supported calculations

- Julian Date from a DateTime instant
- Greenwich Mean Sidereal Time (GMST)
- Local Mean Sidereal Time (LMST)
- Hour angle
- IAU 1976 precession from J2000 to mean coordinates of date
- Geometric horizontal coordinates (altitude and azimuth)
- Zenith distance
- Relative optical airmass (Kasten-Young 1989)
- Angular separation between equatorial positions

## Units

- Right ascension: decimal degrees
- Declination: decimal degrees
- Geographic latitude: decimal degrees
- Geographic longitude: decimal degrees
- Altitude and azimuth: decimal degrees
- Julian Date: Julian days
- Airmass: dimensionless
- Elevation: meters

Positive geographic longitude means east of Greenwich.

Azimuth convention:
- 0 degrees: north
- 90 degrees: east
- 180 degrees: south
- 270 degrees: west

Azimuth is undefined at the exact zenith and nadir.

## Coordinate epochs

OpenNGC provides catalog positions in the J2000
equatorial reference frame.

The calculation pipeline first applies IAU 1976
precession to obtain mean coordinates for the
observation date.

Horizontal coordinates are then calculated using
local mean sidereal time.

Nutation is not included.

## Time

All astronomical computations use an absolute
DateTime instant.

The user interface presents selectable date and
time values in UTC.

The local observing site time zone is not used
to alter the astronomical instant.

GMT/UT1 is approximated using UTC.

TT is also approximated using the same date
for the precession calculation.

This approximation is appropriate for the
initial planning implementation.

## Atmospheric model

Altitude is geometric and does not include
atmospheric refraction.

Relative airmass uses the Kasten-Young 1989 formula.

Airmass is null at and below the geometric horizon.

Local temperature, humidity, pressure and
observatory elevation do not modify the model yet.

## Limitations

The current engine does not apply:

- Nutation
- Annual or diurnal aberration
- Stellar proper motion
- Parallax
- Atmospheric refraction
- Polar motion
- Measured UT1-UTC corrections
- Local horizon obstructions
- Solar-system ephemerides
- High-precision IAU 2006/2000A transformations

These limitations must be considered before using
the coordinates for precision telescope pointing,
astrometry or scientific measurements.

## Integration

The Targets detail dialog contains a coordinate panel.

It combines:
- OpenNGC J2000 celestial coordinates
- A saved observing location
- A selected UTC date and time

The calculated results are not persisted.

## Tests

The test suite includes deterministic checks for:
- Julian Date
- Sidereal time
- Precession
- Hour angle
- Altitude and azimuth
- Direction conventions
- RA wraparound
- Angular separation
- Airmass
- Invalid coordinates

Widget tests verify the observing location
integration and empty-state behavior.

## References

US Naval Observatory:
https://aa.usno.navy.mil/faq/GAST

US Naval Observatory:
https://aa.usno.navy.mil/faq/alt_az

IAU 1976 precession:
https://github.com/liberfa/erfa/blob/master/src/prec76.c

Kasten and Young (1989):
https://doi.org/10.1364/AO.28.004735