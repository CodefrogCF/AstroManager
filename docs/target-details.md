# Target details (Issue #25)

## Entry points

- Catalog row opens `/targets/details/:id` with its local catalog object.
- The recommendation list links to the same route.
- Deep links without `extra` resolve the identifier from the locally seeded
  OpenNGC repository. Network access is never required to fetch catalog data.
- `View in sky atlas` navigates to `/targets/atlas` with the object, allowing
  camera framing in the existing atlas without resetting saved framing profiles.

## Observing context

- Location: a stored observing site (latitude/longitude, IANA time zone).
- Date: a local civil date; the observing night is local noon to next noon.
- Imaging setup: one saved camera + optic profile or no setup.
- Weather: the existing `weatherForecastSnapshotProvider`, including freshness,
  retrieval and provider metadata. An absent or stale forecast is never shown
  as clear weather.

The graph plots geometric target altitude versus absolute UTC time; shaded
portions are astronomical darkness (Sun below -18 degrees). It is intended for
planning and does not model terrain, atmospheric refraction, light pollution or
precise pointing corrections. Moon conditions use topocentric coordinates for
an instant at the midpoint of the best recommended window, or the midpoint of
local noon-to-noon if there is no suitable window. They are *not* an aggregate
moonlight score for the entire night.

The six factor score explanations are copied directly from the existing
observation-window recommendation engine. No additional UI scoring heuristics
alter those scores. Optical profile suggestions are a conservative unrotated
major/minor field-of-view fit, not a guarantee of composition or auto-mosaic
suitability; final composition should be verified in Aladin Lite.

## Planned projects

`Save as project` creates a simple project (target, name, local observing date,
site, optical profile and recommended start/end when available), or associates
this target with an existing project. The list is persisted as a versioned JSON
value in the existing `app_settings` table under `projects.planned.v1`.
Projects are displayed in the Projects tab and can be removed there. Capture
progress tracking and advanced project editing remain future functionality.

## Tests

- Pure target-detail analysis (determinism, missing weather, missing optional
  catalog data, equipment FoV fit).
- Widget tests for local-only details, the visibility chart, absent forecasts
  and project creation.
- Project storage round-trip/association/invalid data tests.

Commands:

```
dart format lib test
flutter analyze
flutter test test/features/targets
flutter test test/features/projects
flutter test
```
