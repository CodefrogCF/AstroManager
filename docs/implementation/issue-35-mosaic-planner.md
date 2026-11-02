# Issue #35 – Astrophotography Mosaic Planner

## UI

Open **Projects → Project details → Mosaic composition → Create mosaic**.
Select one of the project's catalog targets, an existing camera+optic profile,
rows (1–10), columns (1–10), overlap (0–80% in the editor), clockwise rotation
(0–359°), and optionally change center ICRS coordinates. Preview and per-panel
centers update as you edit. Save the mosaic to the project, then choose
**View in atlas** for the Aladin Lite panel footprints and labels. From there
rotation, framing-center and optical-setup controls update the overlay as a
**preview**; saved changes must be made in the project editor.

## Geometry

The optical FOV is computed from current physical camera sensor and optic
parameters using the application's existing `EquipmentInventory.metricsFor`.
Each panel is a rectangle on the **common gnomonic tangent plane**, using
`tan(FOV / 2)` for sensor half-width/height. Adjacent centers are separated by
`2 * halfExtent * (1 − overlapPercent / 100)`, and the complete grid is rotated
clockwise around the chosen center. Every panel center, corner and the overall
outer rectangle are projected inversely from this shared plane to ICRS/J2000
RA/Dec. This handles RA=0 wrapping and high declinations; it also avoids
linearly adding RA degree offsets. Projected rectangles are approximations to
camera footprints and do not include distortion, field rotation, flat-field
quality, mount/pier limits, dithering, atmospheric refraction or plate solving.

The displayed total angular width and height are measured along the rotated
mosaic axes, rather than the bounding box in unrotated RA/Dec. Overlap is
specified in the common tangent-plane coordinates, not as a percentage of
spherical great-circle arc lengths. Very large field extents are rejected.
Panel order is **row-major, top to bottom, left to right** (R1C1 first).

## Storage and backups

One saved plan per imaging project, under the versioned `app_settings` key
`projects.mosaic.v1.<urlencoded-project-id>`. Existing schema v6 and the
version-1 `.ambackup` format already export/import `app_settings`; backup
validation checks the format and ensures that referenced projects are included.
Deleting a project also deletes its saved mosaic in the database transaction.
No additional packages or online services are required to plan a mosaic.

## Coordinate export

`Export coordinates` writes a UTF-8 `.json` document:

- `format: "astromanager-mosaic-panels"`, `version: 1`
- `referenceFrame: "ICRS/J2000"`, `coordinateUnit: "degrees"`
- `plan`: saved project/target/optical-profile ID, rows, columns, overlap,
  rotation and target-center coordinates
- `panelFovDegrees`, `mosaicFovDegrees`: dimensions in angular degrees
- `panels`: ordered records with label, 1-based row/column, decimal `ra` and
  `dec` of each panel center, and the closed five-point panel outline

It is a planning/export format, **not** a mount-specific sequence or ASCOM
command set. Telescope controllers typically require a conversion to their
own pointing/time coordinate conventions.

## Tests

`flutter test test/features/mosaic/`

`node --test test/js/atlas_bridge.test.cjs`

`flutter analyze`
