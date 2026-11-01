# Optical Field-of-View Calculations (Issue #23)

AstroManager computes physical image geometry without Flutter, external APIs,
network access or a database. Existing `OpticalMetrics.calculate` and
`EquipmentInventory.metricsFor` use the shared
`OpticalFieldOfViewService.calculate` implementation.

## API

`lib/features/equipment/domain/services/optical_field_of_view.dart`

```dart
final result = OpticalFieldOfViewService.calculate(
  focalLengthMm: 600,
  apertureMm: 100,
  sensorWidthMm: 36,
  sensorHeightMm: 24,
  resolutionX: 6000,
  resolutionY: 4000,
  reducerFactor: 0.8,
);

// result.horizontalFovDegrees, result.verticalFovDegrees,
// result.diagonalFovDegrees, result.pixelScaleXArcsecPerPixel, etc.
```

## Units and equations

- Effective focal length (mm): `f_eff = f_native × focalMultiplier × reducerFactor × barlowFactor`
- Horizontal FOV (degrees): `2 × atan(activeWidthMm / (2 × f_eff)) × 180 / π`
- Vertical FOV (degrees): `2 × atan(activeHeightMm / (2 × f_eff)) × 180 / π`
- Diagonal FOV (degrees): `2 × atan(hypot(activeWidthMm, activeHeightMm) / (2 × f_eff)) × 180 / π`
- Image scale X (arcsec/native pixel): `206.265 × (sensorWidthMm × 1000 / resolutionX) / f_eff`
- Image scale Y (arcsec/native pixel): `206.265 × (sensorHeightMm × 1000 / resolutionY) / f_eff`
- Effective focal ratio: `f_eff / apertureMm`

The pixel scale uses the standard small-angle approximation; FOV uses the
exact rectilinear angular geometry. No 35 mm-equivalent focal length is used.

## Optical modifiers

- `focalMultiplier = 1` by default, retained for existing optical profiles.
- `reducerFactor` is greater than 0 and at most 1 (e.g. 0.8).
- `barlowFactor` is between 1 and 10 (e.g. 2).
- Multiple optical multipliers compose multiplicatively, and must not be
  entered twice for the same physical accessory.

## Digital sensor crops and regions of interest

- `cropFactor >= 1` means a centered digital crop. Each native pixel dimension
  is divided by the factor and rounded to a whole physical pixel; active sensor
  dimensions are then derived from the actual resulting pixel count. Therefore
  the effective crop factor may differ slightly on one axis.
- `regionOfInterest` defines an exact rectangle in native sensor pixels,
  including offsets from the upper-left corner. The ROI must fit entirely
  within the sensor. ROI offsets do not change angular FOV dimensions, but a
  later atlas/framing feature may use the offsets to position the ROI center.
- Cropping reduces the sky area captured, *not* physical focal length or
  arcseconds per sensor pixel.
- Crop factor and ROI are mutually exclusive to prevent accidental double crop.

Crop and ROI options are **transient** on the domain APIs. Existing profiles
and the Drift schema have not changed; persistent ROI preferences and rotated
camera overlays belong to subsequent issues.

## Reference case

A 36 × 24 mm sensor, 6000 × 4000 pixels, 600 mm lens and 100 mm aperture:

| Quantity | Expected |
| --- | ---: |
| Effective focal length | 600 mm |
| Focal ratio | f/6 |
| Horizontal FOV | 3.436716° |
| Vertical FOV | 2.291526° |
| Diagonal FOV | 4.129868° |
| Pixel scale | 2.06265 arcsec/pixel |

A reducer of 0.8 produces 480 mm focal length; a 2× Barlow produces 1200 mm.
The corresponding image scales follow the inverse focal-length ratio.

## Validation and limitations

Sensor width and height, resolution, focal length, aperture and modifiers
must be finite and physically valid. Invalid inputs throw `ValidationFailure`.
The calculation assumes a flat rectangular detector at prime focus without
pixel binning, optical distortion, tilted sensors or vignetting. Crop/ROI is
modelled as a native-pixel window without resampling.

## Sources

- AAVSO, *CCD Photometry Guide*: https://www.aavso.org/sites/default/files/publications_files/ccd_photometry_guide/CCDPhotometryGuide.pdf
- International Centre for Radio Astronomy Research, *Resolving the Night Sky*: https://www.icrar.org/wp-content/uploads/2021/11/Resolving-the-night-sky-updated-2021.pdf
