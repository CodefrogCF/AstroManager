# Issue #32 – Terrain-based horizon modeling

## Overview

AstroManager can optionally replace the mathematical/unobstructed visibility
assumption in the **Night Planner** with a cached DEM-derived horizon profile.
This is an approximation of **terrain only**: it does not certify line of sight.
Existing calculations remain unchanged until a user enables **Use terrain horizon**.

### Data source and provider

`TerrainElevationProvider` abstracts batch elevation lookup. The initial
implementation calls the [OpenTopoData API](https://www.opentopodata.org/api/)
using the `eudem25m` European elevation dataset (25 m nominal grid); it can be
swapped for a self-hosted endpoint or a different provider. The public endpoint
has usage limits of **100 locations/request, 1 request/second and 1000
requests/day**. The adapter limits batches to 90 and waits 1.1 seconds
between requests. Failure/limits/no-data produce explicit messages; no
estimated horizon is silently substituted for missing data.

For higher-resolution Swiss terrain, **swissALTI3D** is an appropriate future
provider. swisstopo distributes 0.5 m / 2 m gridded terrain tiles and offers
height/profile APIs in Swiss coordinate systems (LV95/LV03). Those APIs have
different batching/licensing/usage semantics; the initial implementation does
**not** claim to retrieve swissALTI3D directly. See:

- https://www.swisstopo.admin.ch/en/height-model-swissalti3d
- https://docs.geo.admin.ch/access-data/get-point-height.html
- https://docs.geo.admin.ch/access-data/get-elevation-profile.html

### Geometry

For each bearing θ from 0° to 360° (exclusive), sample a radial line from the
observer using spherical great-circle destination coordinates. For each
sample at distance d and DEM terrain elevation h:

```
curvature_drop ≈ d² / (2 × 6,371,008.8 m)
angle = atan2(h − observer_elevation − curvature_drop, d) × 180/π
horizon(θ) = max(angle over all sampled distances)
```

Observer elevation comes from the saved observing location (not automatically
replaced with a DEM elevation). Profile bearings use **true north**; compass
angles increase clockwise. Between adjacent valid bearings, linear interpolation
provides a continuous horizon, including the 360°/0° wrap. If any radial sample
for a bearing lacks a DEM height, that bearing is marked **unknown** rather
than presenting a potentially underestimated peak. The line chart omits
unknown segments.

When enabled, a target qualifies only when:

```
target altitude >= configured minimum altitude
AND target altitude >= terrain_horizon(target azimuth)
AND astronomical darkness requirement is satisfied
```

Target-visibility intervals are re-evaluated using the changing target azimuth,
including interpolation and bisection of sampled transitions. The target altitude
**curves** remain geometric; the shaded *qualifying intervals* account for the
terrain. No configuration or older observation records are modified.

### Performance and offline behavior

Controls include angular step (5/10/15/30°), maximum search range
(5/15/25 km), radial step (1/2/5 km), and target minimum altitude (0–60°).
Request samples are capped at 3000 for the public provider.

Profiles are stored as schema-versioned JSON in `SharedPreferencesAsync`, with
SHA-256 cache keys derived from coordinates, observer height, provider and
resolution/radius parameters. The 30-day cache uses max 16 entries. Changing
any relevant geometry/provider input yields a new key. Cached data works
offline. A first-time calculation requires an internet connection; offline
failure falls back to normal geometric visibility with an explicit message.
Derived terrain cache entries are not included in personal-data backups.

### Accuracy and limitations

- **Buildings, trees, towers, cables, local vegetation**, and temporary
  obstructions are **not included** in a terrain-only DEM.
- DEM grid spacing, angular spacing and radial spacing can **miss narrow
  ridges or nearby obstructions**; a 25 m grid is not a 25 m final line-of-sight
  guarantee. Increase resolution/range when needed, subject to API limits.
- **Atmospheric refraction is not modeled**; Earth curvature is modeled with
  a spherical Earth approximation, not a detailed ellipsoid or geoid.
- Elevations can be stale or missing and the saved observer elevation can be
  inaccurate. Differences in terrain elevation datum matter for precision.
- Time intervals are sampled at the core visibility service's configured time
  step (5 minutes by default); exceptionally brief occlusions can be missed.
- Partial coverage is shown explicitly. Unknown bearings **do not prove
  visibility**; the preliminary time windows are flagged as uncertain.

### Validation

Offline reference tests cover known cardinal-direction great-circle distances,
independently calculated elevation angles (+100 m at 1 km ≈ 5.71° and
curvature-only horizon at 10 km ≈ −0.045°), a synthetic mountain ridge,
missing-data propagation, round-trip serialization, cache reuse, HTTP batch
parsing, and whether an extreme terrain horizon suppresses target visibility.

**Field verification against real mountain silhouettes and site-specific
swisstopo reference data remains necessary** before relying on results for
professional visibility studies; the tests alone do not establish field
accuracy.
