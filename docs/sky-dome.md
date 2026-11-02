# Sky dome and detail atlas

The Sky Atlas now has two independent projection modes:

- **Detail atlas**: Aladin Lite `TAN` projection, user-controlled FoV and
  camera framing from the selected optical profile. Switching away and back
  restores the current detailed sky position and zoom.
- **Sky dome**: Aladin Lite `ZEA` projection with the zenith of the selected
  observing location at the center and a 180° horizontal field of view.
  The square viewport is intended to accommodate the celestial hemisphere.

The dome overlays are *sky-coordinate* polylines, not screen-space images:

- Geometric horizon, 0° geometric altitude (green)
- Altitude rings at 30° and 60°
- User-selected minimum-altitude ring (yellow)
- Labeled north/east/south/west positions (at altitude 2°)

All of these positions are recomputed when observing site, selected UTC
instant, or minimum altitude changes. The conversion uses mean sidereal time,
spherical horizontal-to-equatorial geometry and inverse IAU-1976 J2000
precession so overlays align approximately with the ICRS/J2000 survey. The
projection is 2D; it does not render a navigable 3D sphere.

Limitations: no terrain, buildings, vegetation, atmospheric refraction,
UT1-UTC corrections or nutation. The synthetic horizon is not the physical
horizon. Aladin HiPS imagery still requires connectivity to survey servers.

Tests:

```bash
flutter test test/features/atlas
node --test test/js/atlas_bridge.test.cjs
```
