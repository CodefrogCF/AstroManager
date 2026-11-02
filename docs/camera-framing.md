# Camera Framing Overlay (Issue #24)

## Operation

1. Open **Targets → Sky Atlas**, optionally with a selected catalog object.
2. Create a **camera**, **lens or telescope**, and an **optical profile** under Equipment.
3. Select an optical profile from **Imaging setup**.
4. The orange dashed outline represents the camera sensor area in ICRS sky coordinates. Its geometry is tied to the selected profile's sensor dimensions and effective focal length.
5. Pan the sky atlas and choose **Frame at atlas center** to move the outline to that position; alternatively use the N/S/E/W frame nudges.
6. Move the **Rotation** slider. Positive angles rotate the right edge of the camera image toward celestial south (clockwise when north is up and east is right).
7. Use **Save frame** to persist the optical profile ID, framing RA/Dec and rotation for this target; **Restore** reloads the saved configuration. Targets have separate framing records; an untargeted atlas uses its own record.

### Field-of-view geometry

`OpticalMetrics.calculate` and `OpticalFieldOfViewService.calculate` use the active physical sensor size (mm) and effective focal length (mm). The outline's edges are sampled on a tangent plane and transformed to ICRS using an **inverse gnomonic projection**. This keeps the footprint aligned with the sky when zooming or panning. Rotation is applied on the tangent plane before converting to coordinates. The outline is re-created when the camera/optical profile or rotation changes.

Image dimensions are expressed in **degrees**. The saved frame is a reference to the selected optical profile, not a snapshot of physical equipment values. If sensor dimensions, focal length or multiplier are later edited in Equipment, a restored frame is recalculated with the new profile settings.

### Limitations

- No distortion, optical vignetting, diffraction, camera roll calibration, sensor tilt or equatorial mount pier-flip modeling.
- Object-size warnings are based on the OpenNGC major axis; a galaxy or nebula's full photographed extent can differ from the catalog entry.
- The orange frame does not represent local alt/az or a guaranteed camera orientation; RA/Dec are ICRS/J2000.
- Frame nudge uses an approximate angular delta and is intended for interactive composition, not astrometric pointing.
- Survey tiles from CDS require a network connection, while frame calculations and saved settings remain local.
- The native Aladin WebView remains limited to Android, iOS and macOS. Windows/Linux should use AstroManager Web.
- Settings are stored as versioned JSON via `SharedPreferencesAsync` rather than a new Drift schema version. Broken saved records are ignored.

## Validation

- `node --test test/js/atlas_bridge.test.cjs` checks the JavaScript polygon layer and packet rejection.
- `flutter test test/features/atlas` checks the footprint geometry, rotation, RA wrap, equipment changes, load/save, and existing Atlas interactions.
- `flutter analyze` and `flutter test` ensure the project remains consistent.
- Manually verify overlay alignment while panning, zooming, rotating, switching equipment profiles, and reopening a saved target framing in Chrome and a supported native WebView.

## API reference

Aladin Lite v3 graphic overlays: https://cds-astro.github.io/aladin-lite/GraphicOverlay.html

Aladin Lite polyline example: https://aladin.cds.unistra.fr/AladinLite/doc/API/examples/polyline/
