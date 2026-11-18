# Changelog

## 1.0.0

### Added

- Optional observer-reported Bortle classes in site profiles, backups, target
  ratings and site comparisons.
- Selected object labels, sky-aligned outlines and catalog details in the Sky
  Atlas, plus camera framing in Sky Dome mode.

### Changed

- Live field-of-view readout follows zoom, presets and atlas mode changes.
- Dashboard forecast refresh shares updated coverage with other planning
  screens. Forecast age and cached fallback follow the data displayed.
- Weather carries more weight in suitability scoring. Fresh forecasts of full
  cloud cover break otherwise eligible observation windows.
- Sky-darkness scoring uses the saved Bortle class. The automatic grid and
  previous satellite night-light integration have been retired. Stored
  results from the retired cache are cleaned up on startup.
- System Back restores the previous screen from Settings and returns main
  sections to the Dashboard.

### Fixed

- The terrain horizon loads and retains site-matched cached profiles, with
  distinct coverage and request-failure statuses.
- Existing `.ambackup` files can be selected for restoration on platforms
  that lack a registered file association.

### Release preparation

- Added English and German user documentation, platform requirements,
  reproducible build instructions, screenshots and a release QA checklist.
- Audited privacy and data-source credits. External service errors use
  bounded status messages, and the Web atlas runs in an isolated frame.

## 0.7.1

- Refined Dashboard widget sizing and drag-and-drop ordering.
- Added manual forecast refresh and the Night only / Full day clear-sky views.
- Streamlined scheduling project targets and editing blocks in Night Planner.

[Changes since v0.7.1](https://github.com/CodefrogCF/AstroManager/compare/v0.7.1...v1.0.0) ·
[Previous releases](https://github.com/CodefrogCF/AstroManager/releases)
