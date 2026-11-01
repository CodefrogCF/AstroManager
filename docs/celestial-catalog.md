# Local Celestial Object Catalog

## Overview

AstroManager includes an offline celestial object catalog
based on OpenNGC.

The catalog provides:
- NGC objects
- IC objects
- Messier cross-references
- Additional OpenNGC objects
- Common names and identifiers
- Object classifications
- J2000 equatorial coordinates
- V-band magnitudes where available
- Angular dimensions where available

## Source and Attribution

Source: OpenNGC

Author: Mattia Verga and OpenNGC contributors

Repository:
https://github.com/mattiaverga/OpenNGC

Data release:
v20260501

License:
Creative Commons Attribution-ShareAlike 4.0 International

License URL:
https://creativecommons.org/licenses/by-sa/4.0/

The original CSV files were transformed into a compact JSON
dataset for use in AstroManager.

Transformation steps:
- Read NGC.csv and addendum.csv
- Remove duplicate and nonexistent entries
- Convert sexagesimal RA and Dec to degrees
- Normalize primary display designations
- Preserve Messier cross-references
- Preserve common names and identifiers
- Retain V magnitudes and angular dimensions
- Group OpenNGC object types into application categories
- Serialize results into a compact JSON asset

The resulting adapted catalog is distributed under
CC BY-SA 4.0.

The OpenNGC license text is included at:
assets/catalog/LICENSE-OpenNGC.txt

This catalog is not endorsed by the OpenNGC project.

## Source Files

The pinned source release is downloaded from:

https://github.com/mattiaverga/OpenNGC/releases/tag/v20260501

Data files:
- database_files/NGC.csv
- database_files/addendum.csv

## Rebuilding the Catalog

Run:

    python tool/build_openngc_catalog.py

The script requires internet access during development.

The generated JSON is committed to the repository and
bundled into the application.

Runtime catalog access does not require internet access.

## Data Model

Table:
celestial_catalog_entries

Database schema version:
4

Fields:
- id
- designation
- category
- sourceType
- raDegrees
- decDegrees
- constellation
- visualMagnitude
- majorAxisArcmin
- minorAxisArcmin
- messierNumber
- commonNames
- aliases

## Coordinates

Right ascension:
- J2000 equatorial coordinates
- Stored in decimal degrees
- Range: 0 <= RA < 360

Declination:
- J2000 equatorial coordinates
- Stored in decimal degrees
- Range: -90 <= Dec <= 90

RA and Dec originate from the OpenNGC dataset.

No precession, nutation, atmospheric refraction or
topocentric correction is performed in the catalog.

These calculations belong to the astronomy engine.

## Magnitudes

Only the OpenNGC V-Mag field is stored as
visualMagnitude.

Missing values are stored as NULL.

B-Mag is not substituted for V-Mag.

## Angular Dimensions

Angular dimensions are stored in arcminutes.

The stored sizes are catalog values and may use
different measurement conventions depending on
the object type and source.

They should not automatically be interpreted as
a complete photographic footprint.

## Categories

The initial categories are:

- Galaxy
- Nebula
- Star cluster
- Star
- Other

The original OpenNGC object type is also preserved
for more precise classification in future releases.

## Import Strategy

The bundled asset is read when the Targets feature
is first opened.

The application compares the bundled catalog version
with the locally stored catalog version.

A new version triggers transactional upserts.

The version marker is updated only after all writes
complete successfully.

The importer does not delete personal application data.

## Search

The initial implementation supports:
- Primary catalog designation
- Original catalog identifier
- Messier cross-reference
- Common name
- Additional aliases
- Category filtering

Searches run against SQLite.

Results are limited to 80 items by default.

Future improvements may include FTS5 indexing.

## Database Migrations

The following upgrades are supported:

- v1 to v2: Observing locations
- v2 to v3: Equipment and optical profiles
- v3 to v4: Celestial catalog

Direct upgrades from older versions to v4 are
also supported.

Historical schema snapshots must be preserved.

## Limitations

This catalog is focused on deep-sky objects and
selected additional objects.

It is not a complete stellar astrometry catalog.

It does not replace dedicated solar-system ephemerides.

The catalog does not yet include:
- Apparent coordinates for a specific date
- Altitude and azimuth
- Rise and set times
- Weather conditions
- Target visibility windows
- Local horizon obstructions
- Proper-motion propagation
- Photographic framing overlays

## Future Integration

The catalog will be used by:
- Astronomical coordinate calculations
- Solar and lunar planning
- Target visibility estimation
- Weather-aware target recommendations
- Optical profile framing
- Sky atlas and session planning

## Testing

Required tests:
- JSON parsing and validation
- Catalog import
- Idempotent import
- Versioned update
- Search by identifiers
- Search by Messier reference
- Search by common name
- Category filtering
- Database migration to v4
- Persistence across restart
- Flutter widget integration