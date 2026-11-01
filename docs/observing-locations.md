
# Observing Location Management

## Overview

AstroManager supports multiple persistent observing locations.

Observing locations are used for astronomical calculations,
weather forecasts, target visibility and imaging recommendations.

## Features

- Create observing locations
- Edit existing locations
- Delete observing locations
- Select a default observing location
- Retrieve device coordinates on request
- Work offline without location permissions
- Validate coordinates and IANA time zones

## Location Model

Each location contains:

| Field | Description |
|---|---|
| ID | Unique UUID |
| Name | User-defined location name |
| Latitude | WGS84 decimal degrees |
| Longitude | WGS84 decimal degrees |
| Elevation | Meters above mean sea level |
| Time Zone | IANA identifier |
| Is Default | Default observing location flag |

## Coordinate Conventions

Latitude:
- Range: -90 to +90 degrees
- Positive: North
- Negative: South

Longitude:
- Range: -180 to +180 degrees
- Positive: East
- Negative: West

Elevation:
- Stored in meters
- Valid input range: -500 to 10000 meters

## Time Zones

Time zones are stored using IANA identifiers.

Examples:

- Europe/Zurich
- Europe/Berlin
- Europe/London
- America/New_York
- Etc/UTC

Time zone validation uses the bundled IANA database.

GPS coordinates do not automatically determine the correct
time zone. Users must verify this value.

## Default Location

Exactly one location is selected as default when the
database contains at least one valid location.

Rules:

1. The first saved location becomes the default.
2. Users can select a different default.
3. Editing the default location preserves its status.
4. Deleting the default selects another saved location.
5. Deleting the final location leaves no default.

## Persistence

Observing locations are stored using Drift and SQLite.

Database schema version: 2

Table: `observing_locations`

The migration from version 1 to version 2 adds the new
table without deleting existing application settings.

## GPS

Device location access is optional.

The application:
- Requests permission only after user interaction
- Does not continuously track device location
- Does not require background location access
- Supports manual coordinate entry
- Does not upload saved locations to a server

GPS elevation may be inaccurate and can be corrected manually.

## Architecture

Domain:
`features/locations/domain/`

Data:
`features/locations/data/`

Application:
`features/locations/application/`

Presentation:
`features/locations/presentation/`

The repository interface is independent of the persistence engine.

## Testing

Required tests:

- Valid coordinate acceptance
- Invalid coordinate rejection
- Invalid IANA time zone rejection
- Location creation and editing
- Default location selection
- Default reassignment after deletion
- Offline persistence
- Database migration from v1 to v2
- Manual location entry UI