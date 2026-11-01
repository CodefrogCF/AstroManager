# AstroManager – Development Roadmap

> **AstroManager** is an open-source, offline-first astrophotography planning application
> built with Flutter and Dart. It helps astrophotographers discover suitable celestial
> targets, evaluate observing conditions, select appropriate equipment, plan imaging
> sessions, and track astrophotography projects.

## Project Overview

**Primary goals:**

- Discover suitable astrophotography targets based on location, date, weather, and equipment.
- Calculate astronomical visibility, darkness, and lunar conditions.
- Recommend optimal imaging windows using an explainable suitability scoring system.
- Preview celestial targets and camera framing using an interactive sky atlas.
- Manage cameras, lenses, telescopes, mounts, and observing locations.
- Plan and document astrophotography projects and observation sessions.
- Provide offline-first functionality without mandatory accounts or cloud services.
- Support Android, iOS, Web, Windows, and macOS.

### Technology Stack

| Component | Technology |
|---|---|
| Framework | Flutter / Dart |
| Architecture | Feature-first, Repository Pattern |
| State Management | Riverpod |
| Navigation | go_router |
| Local Database | Drift / SQLite |
| Astronomy Calculations | Dart / astronomia |
| Weather Data | Open-Meteo, extensible provider architecture |
| Celestial Catalog | Local Messier / selected NGC / IC catalog |
| Sky Atlas | Aladin Lite |
| Testing | flutter_test, unit and integration tests |
| CI/CD | GitHub Actions |
| Optional Backend | Docker / REST API |

---

## Development Milestones

| Version | Milestone | Issues | Status |
|---|---|---:|---|
| v0.1.0 | Project Foundation | 7 | Done |
| v0.2.0 | Astronomy Core | 7 | Done |
| v0.3.0 | Weather & Target Intelligence | 7 | in Progress |
| v0.4.0 | Sky Atlas & Equipment Framing | 5 | Planned |
| v0.5.0 | Projects & Observation Sessions | 5 | Planned |
| v0.6.0 | Advanced Planning | 5 | Planned |
| v1.0.0 | Production Release | 4 | Planned |

**Total: 7 milestones, 40 planned issues.**

The initial MVP is targeted for **v0.4.0**.

Issue identifiers (`AM-001`–`AM-040`) are planning references, not automatically assigned
GitHub issue numbers.

---

## v0.1.0 – Project Foundation

**Goal:** Establish a maintainable, testable, cross-platform Flutter application with offline
persistence and a consistent UI foundation.

### Planned Issues

- [x] **AM-001 – Initialize Flutter project and Git repository**
  - Create Flutter project with organization `com.codefrog`.
  - Configure Android, Web, and Windows targets.
  - Prepare Git repository, README, license, and `.gitignore`.
  - Verify initial builds, static analysis, and tests.

- [x] **AM-002 – Establish feature-first architecture**
  - Define `core`, `features`, and `shared` modules.
  - Implement repository abstractions.
  - Configure Riverpod dependency injection.
  - Document architecture conventions.

- [x] **AM-003 – Implement application shell and navigation**
  - Configure go_router.
  - Create Dashboard, Targets, Planner, Equipment, Projects, and Settings screens.
  - Implement responsive navigation.

- [x] **AM-004 – Implement application theming and astronomy night mode**
  - Create light and dark themes.
  - Implement red astronomy night mode.
  - Persist theme preferences.

- [x] **AM-005 – Configure Drift and SQLite persistence**
  - Initialize local database.
  - Configure migrations and schema versioning.
  - Implement platform-specific SQLite support.
  - Add database tests.

- [x] **AM-006 – Implement application settings and error handling**
  - Implement persistent settings.
  - Add measurement units and time display preferences.
  - Implement structured logging and error handling.

- [x] **AM-007 – Configure CI, testing standards and documentation**
  - Set up GitHub Actions.
  - Automate formatting, analysis, and tests.
  - Document local development setup.
  - Establish development conventions.

### Completion Criteria

- Application launches on initial target platforms.
- Navigation and settings are functional.
- Local persistence works.
- Astronomy night mode is available.
- Automated tests and CI checks pass.

---

## v0.2.0 – Astronomy Core

**Goal:** Implement the astronomical calculation engine and local data models needed to
determine celestial object visibility.

### Planned Issues

- [x] **AM-008 – Implement observing location management**
  - Create, edit, and delete observing locations.
  - Store coordinates, altitude, and time zone.
  - Support optional GPS-based location detection.
  - Select a default observing location.

- [x] **AM-009 – Implement equipment inventory and optical profiles**
  - Manage cameras and sensor specifications.
  - Manage lenses and telescopes.
  - Manage tracking mounts.
  - Create reusable imaging setups.

- [x] **AM-010 – Integrate a local celestial object catalog**
  - Include the complete Messier catalog.
  - Include selected NGC/IC objects.
  - Store coordinates, object types, angular dimensions, and available magnitude data.
  - Implement offline catalog search.

- [x] **AM-011 – Implement astronomical coordinate calculations**
  - Calculate Julian dates and sidereal time.
  - Convert equatorial coordinates to altitude and azimuth.
  - Handle coordinate epochs and precession.
  - Validate against astronomical reference values.

- [x] **AM-012 – Implement solar events and astronomical darkness**
  - Calculate sunrise and sunset.
  - Calculate civil, nautical, and astronomical twilight.
  - Identify astronomical darkness intervals.
  - Handle special geographic conditions.

- [x] **AM-013 – Implement lunar ephemeris and target separation**
  - Calculate Moon phase and illumination.
  - Determine Moon position and rise/set times.
  - Calculate angular separation between the Moon and selected targets.

- [x] **AM-014 – Implement target visibility calculations**
  - Calculate target altitude and azimuth over time.
  - Determine culmination.
  - Identify visibility intervals.
  - Support configurable minimum target altitude.

### Completion Criteria

- Astronomical calculations work offline.
- Celestial targets can be searched.
- Object visibility is calculated for selected locations and dates.
- Solar and lunar conditions are available.
- Core calculations are validated against reference data.

---

## v0.3.0 – Weather & Target Intelligence

**Goal:** Combine weather forecasts, astronomical visibility, lunar conditions, and equipment
suitability to recommend astrophotography targets.

### Planned Issues

- [x] **AM-015 – Define extensible weather provider architecture**
  - Establish common weather provider interfaces.
  - Define normalized hourly forecast models.
  - Support multiple weather data sources.
  - Implement provider error handling.

- [x] **AM-016 – Integrate Open-Meteo forecast provider**
  - Retrieve total and available cloud-layer coverage.
  - Retrieve precipitation forecasts.
  - Retrieve wind and humidity data.
  - Include available visibility information.
  - Handle forecast time zones and timestamps.

- [x] **AM-017 – Implement weather caching and offline fallback**
  - Cache weather forecasts locally.
  - Implement cache expiration and refresh.
  - Display forecast freshness.
  - Support offline fallback without presenting stale data as current.

- [x] **AM-018 – Implement astrophotography suitability scoring**
  - Evaluate target altitude and visibility.
  - Evaluate weather conditions.
  - Consider Moon illumination and target separation.
  - Consider available imaging equipment.
  - Implement weighted, configurable scoring.
  - Provide explainable scoring results.

- [x] **AM-019 – Implement observation window recommendation engine**
  - Identify suitable observing intervals.
  - Calculate recommended start and end times.
  - Support minimum imaging duration.
  - Rank available observation windows.

- [x] **AM-020 – Build target discovery and recommendation interface**
  - Display recommended targets sorted by suitability.
  - Implement category and equipment filters.
  - Display target scores and explanations.
  - Show recommended observation windows.
  - Support target favorites.

- [ ] **AM-021 – Validate recommendations and scoring behavior**
  - Implement deterministic scoring tests.
  - Validate clear-sky and cloudy-weather scenarios.
  - Validate Moon interference scenarios.
  - Verify consistent ranking behavior.
  - Handle missing forecast information conservatively.

### Completion Criteria

- Weather forecasts are integrated.
- Recommendations account for location and equipment.
- Targets receive explainable suitability scores.
- Optimal imaging windows are calculated.
- Forecast caching and offline fallback work.

---

## v0.4.0 – Sky Atlas & Equipment Framing

**Goal:** Provide an interactive sky atlas and visual camera framing tools.

**This milestone marks the initial MVP.**

### Planned Issues

- [ ] **AM-022 – Integrate Aladin Lite sky atlas**
  - Embed Aladin Lite into Flutter.
  - Implement Dart-to-JavaScript communication.
  - Navigate to selected celestial targets.
  - Support sky survey imagery.
  - Handle platform-specific integration requirements.

- [ ] **AM-023 – Implement optical field-of-view calculations**
  - Calculate horizontal and vertical field of view.
  - Calculate image scale in arcseconds per pixel.
  - Support focal length modifiers.
  - Validate optical calculations.

- [ ] **AM-024 – Implement interactive camera framing overlay**
  - Display camera sensor footprint on the sky atlas.
  - Allow framing rotation and adjustment.
  - Update framing when equipment changes.
  - Save and restore framing configurations.

- [ ] **AM-025 – Implement detailed celestial target screen**
  - Display target coordinates and properties.
  - Show visibility and observation windows.
  - Show weather and lunar conditions.
  - Display suggested imaging setups.
  - Link to sky atlas and projects.

- [ ] **AM-026 – Implement atlas resilience and attribution**
  - Display required data source attribution.
  - Handle unavailable imagery.
  - Provide offline-safe fallbacks.
  - Verify atlas rendering on supported platforms.

### Completion Criteria

- Interactive sky atlas is functional.
- Targets can be located in sky survey imagery.
- Camera framing is calculated and visualized.
- Equipment can be used to evaluate target composition.
- Target details combine astronomical and weather information.

### MVP Definition

At this stage, AstroManager should answer:

> "Which celestial objects are suitable for astrophotography tonight, when should I
> photograph them, and which of my available camera and telescope setups should I use?"

---

## v0.5.0 – Projects & Observation Sessions

**Goal:** Provide project management, observation logs, and imaging progress tracking.

### Planned Issues

- [ ] **AM-027 – Implement astrophotography project management**
  - Create imaging projects.
  - Assign targets and equipment.
  - Define imaging goals.
  - Manage project status and notes.

- [ ] **AM-028 – Implement observation session logging**
  - Record observation locations and dates.
  - Record equipment and exposure settings.
  - Track captured frames.
  - Attach notes and optional images.
  - Associate sessions with projects.

- [ ] **AM-029 – Implement integration time and project progress tracking**
  - Calculate accumulated integration time.
  - Distinguish accepted and rejected frames.
  - Display imaging progress.
  - Aggregate results across sessions.

- [ ] **AM-030 – Implement interactive night planning timeline**
  - Visualize astronomical darkness.
  - Display target visibility intervals.
  - Integrate weather conditions.
  - Schedule multiple imaging targets.
  - Identify overlapping observation blocks.

- [ ] **AM-031 – Implement project data export and backup**
  - Export application data.
  - Implement versioned backup format.
  - Restore projects, sessions, equipment, and locations.
  - Validate imports.
  - Test backup and restore reliability.

### Completion Criteria

- Imaging projects can be managed offline.
- Observation sessions can be recorded.
- Integration times and progress are calculated.
- Multi-target nights can be planned.
- User data can be exported and restored.

---

## v0.6.0 – Advanced Planning

**Goal:** Improve observing recommendations using terrain, light pollution, site comparison,
and advanced composition planning.

### Planned Issues

- [ ] **AM-032 – Implement terrain-based horizon modeling**
  - Integrate digital elevation data.
  - Calculate terrain-dependent horizon profiles.
  - Incorporate terrain obstruction into target visibility.
  - Cache terrain information.
  - Document limitations of terrain-only modeling.

- [ ] **AM-033 – Implement light pollution data integration**
  - Integrate suitable night-light or sky-brightness datasets.
  - Display estimated light pollution conditions.
  - Incorporate relevant indicators into recommendations.
  - Document dataset limitations and attribution.

- [ ] **AM-034 – Implement observing site comparison**
  - Compare multiple saved observing locations.
  - Compare target visibility.
  - Compare weather and darkness conditions.
  - Incorporate available light pollution indicators.
  - Recommend suitable sites with explainable results.

- [ ] **AM-035 – Implement astrophotography mosaic planner**
  - Define mosaic rows and columns.
  - Configure panel overlap.
  - Calculate individual panel positions.
  - Visualize mosaic footprint.
  - Save mosaic plans to projects.

- [ ] **AM-036 – Implement observation opportunity notifications**
  - Configure target-specific alerts.
  - Define minimum suitability thresholds.
  - Notify users about promising observation windows.
  - Prevent duplicate notifications.
  - Respect platform-specific background execution limitations.

### Completion Criteria

- Terrain obstruction can be considered.
- Available light pollution data can be displayed.
- Observing locations can be compared.
- Multi-panel mosaics can be planned.
- Suitable observing opportunities can trigger notifications on supported platforms.

---

## v1.0.0 – Production Release

**Goal:** Deliver a stable, documented, cross-platform astrophotography planning application
suitable for public use.

### Planned Issues

- [ ] **AM-037 – Implement localization, onboarding and accessibility**
  - Complete German and English localization.
  - Implement guided first-run setup.
  - Provide responsive and accessible interfaces.
  - Maintain account-free operation.

- [ ] **AM-038 – Complete cross-platform quality assurance**
  - Verify Android and iOS functionality.
  - Verify Web, Windows, and macOS functionality.
  - Test critical application workflows.
  - Verify persistence and database migrations.
  - Resolve release-blocking defects.

- [ ] **AM-039 – Perform performance, privacy and reliability review**
  - Benchmark target scoring and catalog queries.
  - Verify offline reliability.
  - Audit external data-source licenses and attribution.
  - Review privacy and data handling.
  - Complete performance and security checks.

- [ ] **AM-040 – Prepare v1.0.0 release and documentation**
  - Complete user documentation.
  - Prepare screenshots and release notes.
  - Finalize changelog.
  - Generate release builds.
  - Publish the stable GitHub release.

### Completion Criteria

- All release-blocking issues are resolved.
- Required platform tests pass.
- Documentation is complete.
- Privacy and attribution requirements are satisfied.
- Stable release artifacts are available.

---

## Future Roadmap – v1.1.0 and Beyond

The following features are candidates for future releases and are not included in the initial
v1.0.0 scope.

### Plate Solving

- Integrate Astrometry.net or a compatible self-hosted solver.
- Identify celestial coordinates from uploaded images.
- Compare actual framing with planned framing.
- Support FITS and selected photographic formats.

### Telescope and Mount Control

- Investigate INDI-based device integration.
- Support compatible tracking mounts.
- Implement telescope position and tracking status.
- Enable optional GoTo commands.
- Provide safe device connection management.

### Camera Control

- Investigate supported camera control interfaces.
- Implement remote exposure triggering where possible.
- Manage exposure sequences.
- Integrate camera settings and status.

### Exposure Advisor

- Recommend exposure strategies based on equipment.
- Evaluate image scale and sampling.
- Account for tracking capabilities.
- Provide estimates and explain limitations.

### Satellite and ISS Predictions

- Calculate satellite visibility.
- Predict ISS passes.
- Integrate satellite tracking data.
- Support photography planning for selected passes.

### Advanced Image Analysis

- Read FITS metadata.
- Calculate basic star quality metrics.
- Analyze image sharpness and tracking errors.
- Associate image quality results with sessions.

### Optional Remote Processing Server

- Provide a self-hosted Docker service.
- Support computationally expensive operations.
- Introduce optional plate-solving services.
- Keep core application functionality independent of the server.

---

## Development Principles

### Offline-First

Core features must remain usable without an active internet connection.

- Local celestial object catalog.
- Local equipment and observing location management.
- Local project and session management.
- Offline astronomical calculations.
- Cached external data with visible freshness indicators.

### Privacy

AstroManager is designed to operate without mandatory user accounts.

- No mandatory cloud synchronization.
- No advertising or unnecessary tracking.
- User data stored locally by default.
- External requests limited to required data services.
- Explicit handling of optional location permissions.

### Modular Architecture

Each major feature should be independently maintainable.

- Clear separation between domain logic and UI.
- Provider abstractions for external services.
- Testable astronomical calculations.
- Versioned data persistence.
- Platform-specific implementations isolated behind interfaces.

### Open Source

- Publicly documented architecture.
- Clear licensing and contribution guidelines.
- Documented third-party data sources.
- Transparent development and release process.

---

## Definition of Done

An issue is considered complete when:

- [ ] Implementation satisfies all acceptance criteria.
- [ ] Relevant tests are included or updated.
- [ ] Code is formatted using `dart format`.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes.
- [ ] Relevant supported platforms are manually verified.
- [ ] Documentation is updated where necessary.
- [ ] CI checks pass.
- [ ] Changes are reviewed and merged.

---

## Release Strategy

| Release | Target |
|---|---|
| v0.1.0 | Functional application foundation |
| v0.2.0 | Offline astronomy and visibility calculations |
| v0.3.0 | Intelligent target recommendations |
| v0.4.0 | Initial MVP with sky atlas and camera framing |
| v0.5.0 | Project and observation session management |
| v0.6.0 | Advanced observing and imaging planning |
| v1.0.0 | Stable public release |

Development will follow an iterative milestone-based approach.

Each milestone should deliver a functional, testable improvement rather than an isolated
collection of unfinished features.

**Current project phase:** Initial planning and project foundation.

---

*AstroManager – Open-source astrophotography planning with Flutter and Dart.*

*Copyright © Codefrog. License to be determined.*