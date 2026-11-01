# Equipment Inventory and Optical Profiles

## Overview

AstroManager provides an offline-first equipment inventory
and optical setup calculator.

The feature supports:

- Cameras
- Lenses
- Telescopes
- Mounts
- Reusable optical profiles
- Field-of-view calculations
- Pixel-scale calculations
- Effective focal length and focal ratio

## Architecture

Domain models:
`lib/features/equipment/domain/models/`

Repository interface:
`lib/features/equipment/domain/repositories/`

Drift implementation:
`lib/features/equipment/data/repositories/`

Riverpod controller:
`lib/features/equipment/application/`

User interface:
`lib/features/equipment/presentation/`

## Equipment Models

### Camera

Required fields:

- ID
- Name
- Sensor width in millimeters
- Sensor height in millimeters
- Horizontal resolution in pixels
- Vertical resolution in pixels

Pixel pitch is calculated from sensor dimensions
and resolution.

### Lens / Telescope

Required fields:

- ID
- Name
- Focal length in millimeters
- Clear aperture in millimeters

Focal ratio is calculated as:

    focal_ratio = focal_length_mm / aperture_mm

For zoom lenses, the first implementation stores one
selected focal length and its corresponding aperture.

### Mount

Required fields:

- ID
- Name
- Manufacturer payload capacity in kilograms

Mount payload capacity does not establish suitability
for astrophotography on its own.

Tracking precision, periodic error and equipment weight
are not yet modeled.

## Optical Profiles

An optical profile contains:

- ID
- Name
- Camera ID
- Optic ID
- Optional mount ID
- Optical multiplier

The multiplier represents the effect of an optical
reducer or Barlow lens.

Examples:

- 1.0: Native focal length
- 0.8: 0.8x reducer
- 2.0: 2x Barlow

## Optical Calculations

### Effective Focal Length

    effective_focal_mm = focal_length_mm * multiplier

### Effective Focal Ratio

    effective_f_ratio = effective_focal_mm / aperture_mm

### Field of View

For each sensor dimension:

    fov_degrees =
      2 * atan(sensor_dimension_mm / (2 * effective_focal_mm))
      * 180 / pi

Horizontal and vertical FOV are calculated separately.

### Pixel Pitch

    pixel_pitch_microns =
      sensor_dimension_mm * 1000 / resolution_pixels

Horizontal and vertical pixel pitch are calculated
separately.

### Pixel Scale

    pixel_scale_arcsec_per_pixel =
      206.265 * pixel_pitch_microns / effective_focal_mm

This is an approximate geometric pixel scale.

The calculations assume:
- A flat rectangular sensor
- Direct imaging
- No sensor binning
- No distortion correction
- No vignetting correction
- No eyepiece projection

Actual image quality also depends on seeing,
optical quality, focus, tracking and sampling.

## Persistence

Database schema version: 3

New tables:

- `equipment_items`
- `optical_profiles`

Optical profiles reference equipment using foreign keys.

Deleting referenced equipment is prohibited until
the associated profiles are removed or updated.

## Migrations

The migration from schema v2 to v3 creates both
equipment tables.

Existing observing locations and application settings
remain unchanged.

Direct upgrades from schema v1 to v3 are also supported.

Schema snapshots are stored under `drift_schemas/`.

## Testing

Required tests include:

- Input validation
- CRUD operations
- Profile reference validation
- Foreign key integrity
- Deletion restrictions
- Pixel pitch
- Field of view
- Pixel scale
- Reducer and Barlow multipliers
- Migration from v2 to v3
- Existing data preservation
- Widget input behavior

## Future Extensions

Planned improvements include:

- Zoom lens focal length ranges
- Sensor binning
- Equipment weight
- Mount tracking characteristics
- Calibration and distortion models
- Camera rotation and framing
- Sky atlas overlays
- Setup suitability scoring

Optical profiles will later be used by target
recommendations, sky atlas framing and observation
session planning.