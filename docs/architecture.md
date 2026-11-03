# Architecture and Development

AstroManager is a Flutter/Dart application with feature-first modules and offline-first persistence. This document covers the current v0.6.0 structure; the user-facing workflow is in the [User guide](user-guide.md).

## Structure and main dependencies

| Path | Responsibility |
| --- | --- |
| `lib/app/` | App bootstrap, themes, shell navigation and `go_router` routes. |
| `lib/core/` | Astronomical utilities, Drift/SQLite database, shared providers, error handling. |
| `lib/features/` | Features organized into `presentation`, `application`, `domain` and `data` where appropriate. |
| `lib/shared/` | Reusable widgets. |
| `assets/catalog/` | Bundled OpenNGC-derived catalog plus licensing. |
| `assets/atlas/` | Locally bundled atlas HTML/JavaScript bridge; Aladin assets and imagery are fetched externally. |
| `test/` | Unit, repository, provider, widget and JavaScript atlas tests. |

Application state and dependency injection use `flutter_riverpod`; navigation uses an indexed-stack `go_router` shell with Dashboard, Targets, Night Planner, Equipment, Projects and Settings branches. Flutter Material 3 offers system, light, dark and astronomy-night themes.

## Data ownership and persistence

- **Drift/SQLite (`AppDatabase`, schema v6):** saved observing locations, equipment and optical profiles, imaging projects and target links, observation sessions and image metadata. Migration tests protect earlier schema versions. Several versioned settings records also live in `app_settings`, including night plans, mosaic plans and opportunity alert configurations.
- **Attachment binaries:** stored outside SQLite (native application support directory or separate browser IndexedDB). Rows carry opaque storage references and metadata; backup/restore copies content separately when selected.
- **SharedPreferences:** selected theme and several derived-data caches (for example terrain and VIIRS location readings). Cache contents are not authoritative personal data and need not survive backup restoration.
- **Bundled target catalog:** OpenNGC snapshot distributed with the app, loaded without a live service.
- **Portable backups:** `.ambackup` is a versioned ZIP with JSON and optional detached images, validated before transactional restoration. See [Backup format](backup-format.md).

No AstroManager account or remote personal-data sync is part of this architecture. Requests for live weather, terrain, imagery and satellite radiance require network calls to third parties; do not assume that using an offline-first app means no network traffic.

## Astronomical and planning conventions

- Catalog source coordinates are **ICRS/J2000 RA/Dec**. Coordinate utilities support Julian dates, sidereal time, precession, horizon altitude/azimuth, angular separation and relative airmass.
- Sunrise/sunset and civil, nautical and astronomical twilight are calculated from solar altitude thresholds; astronomical darkness requires the Sun below approximately **−18°**.
- Solar and lunar calculations use UTC instants and site coordinates. UI planning nights run from the site's **local noon to the following local noon**, including 23-/25-hour daylight-saving transitions when applicable.
- Session start times store a UTC instant, IANA zone and recorded offset; nonexistent local times are rejected. Exposure integration is `accepted_frames × exposure_seconds` and totals are derived from sessions rather than stored redundantly.
- Target visibility is a geometric approximation. Optional DEM obstruction requires altitude above both the minimum chosen elevation and the calculated horizon for the target's **azimuth**. Missing DEM bearings remain unknown, not visible.
- Mosaic panels use a **shared gnomonic tangent plane** and inverse projection to celestial coordinates; angular layout supports rotation, overlap, RA=0 wrap and high declinations. Exported panel positions are ICRS/J2000 degrees and do not command a mount.
- Weather-aware suitability scores are **heuristics**, not probability guarantees. Available and stale/missing values remain distinct. VIIRS upward radiance is optional for relative comparisons and must never be equated with measured SQM or Bortle.

Consult the domain implementations in `lib/core/astronomy/`, `lib/features/intelligence/`, `lib/features/terrain/`, `lib/features/mosaic/` and `lib/features/site_comparison/` for exact formulas and defaults.

## External providers and caching

`lib/features/weather/` wraps Open-Meteo; `lib/features/terrain/` wraps OpenTopoData; `lib/features/light_pollution/` accesses a monthly VIIRS image service; and the atlas uses Aladin Lite / DSS Color imagery. Providers must be replaceable, timeout/error-aware, respectful of source limits and explicit about missing/freshness metadata. Use local results when valid; show stale data clearly when the offline fallback allows it. Full source details are in [Data sources and limitations](data-sources.md).

## Opportunity notification lifecycle

Rules select a catalog target and site, minimum score and minimum continuous observation duration. They are evaluated using existing `ObservationWindowRecommendation` results (not a second scoring model) when the app launches, resumes or the user checks manually. Android/iOS local notifications require explicit opt-in and permissions. A persisted fingerprint prevents repeat notifications for the same rule/night. There is **no guaranteed autonomous background weather polling**.

## Testing and development

The repository pins Flutter in `.fvmrc`. Install platform build tools and run:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test --concurrency=2
node --test test/js/atlas_bridge.test.cjs
```

The JavaScript command needs Node.js. For changes to Drift table definitions or schemas, regenerate source and update migration tests:

```bash
dart run build_runner build
```

Prefer deterministically fixed astronomical reference dates and explicit UTC/zone handling; mock provider HTTP calls rather than calling live services in tests. Test full backup round trips (including binary attachments), legacy migrations, denied permissions, no-data cases, DST ambiguity, RA wrap/poles and temporary/failed network responses. Close Drift executors and widget test containers cleanly; avoid two live `AppDatabase` wrappers sharing the same connection.

CI is defined at [`.github/workflows/ci.yml`](../.github/workflows/ci.yml); changes to native features additionally need real-platform smoke tests.

## UI localization

Flutter uses `flutter_localizations` with `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, generated by `flutter gen-l10n`. `AppPreferences.language` is the existing saved locale choice. The shared `AppText` widget also localizes existing English presentation labels through `ui_strings.dart`, generated from the same ARB files with `python tool/generate_ui_strings.py`. When changing UI text, update both ARBs and regenerate the map. Dynamic catalog names, proper nouns, data-provider messages and arbitrary user input remain unchanged. Use `localizeDecoration(context, ...)` for field labels and `appTranslate(context, ...)` for tooltips or other string properties.

First-run onboarding uses the existing preferences store (`onboardingCompleted`, backward-compatible with previously saved version-1 preferences), plus existing location/equipment flows. It is optional and prompts no permissions automatically. The Aladin embedded controls are an optional visualization preference carried through the version-1 atlas bridge packet (`showAladinControls`), with responsive defaults in JavaScript and CSS; source attribution remains visible.

## Dashboard widget framework

`lib/features/dashboard/domain/dashboard_layout.dart` defines a versioned
layout (format version 1) with stable widget instance IDs, widget type IDs,
visibility, dimensions and typed scalar settings. The UI-independent model
preserves unknown widget types so updates can restore them without losing user
configuration. The implementation rejects malformed dimensions, duplicate IDs
and unsupported JSON values.

`dashboard_widget_registry.dart` associates metadata (title, description,
supported sizes and settings schema) with an independent widget builder.
`dashboard_screen.dart` renders a responsive, wrapping grid; each visible card
owns a separate Riverpod `Consumer` subtree. Hidden widget builders are never
instantiated, and independent loading/empty/error/unavailable states use
`DashboardWidgetStateView`. The shared observing-location selector follows the
saved default location unless the user explicitly selects another site.

`DashboardLayoutController` serializes local layout edits and persists JSON via
`SettingsDashboardLayoutRepository` using the `dashboard.layout.v1` key in
`app_settings`. This uses the existing schema v6, is included in `.ambackup`,
and is validated during restore. The first-run preset includes placeholders for
forecast, target ranking and night conditions until their dedicated data
widgets are implemented. Quick Actions is immediately operational.

The current framework supports accessible menu-based ordering, visibility,
creation, removal and metadata-driven configuration. Touch drag-and-drop and
fully independent breakpoint layouts belong to the subsequent layout editor.

### Responsive dashboard grid (format v2)

The Dashboard persists widget identities, settings, and visibility in the
existing `dashboard.layout.v1` settings key. Its **JSON `formatVersion: 2`** adds
independent `grids` for `phone` (one column), `tablet` (two columns), and
`desktop` (four columns). Every grid tile stores its widget ID, zero-based
column/row, and cell spans. Format v1 layouts are accepted and lazily reflowed
without destructive migration.

`DashboardGridEngine` deterministically places the moved or resized tile first,
then shifts intersecting tiles into free cells. All saved grid rectangles are
validated for bounds, unique IDs, and non-overlap. Dashboard layouts remain
part of the existing `.ambackup` export and import checks. No database schema
migration or new runtime package is needed.
