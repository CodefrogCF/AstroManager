# AstroManager User Guide

This guide describes the user-facing functionality in AstroManager `0.6.0`. Menu labels follow the current English application interface.

## 1. Set up your observing locations

Open **Settings → Observing Locations → Add location**. Enter a name, latitude and longitude (WGS84 decimal degrees), elevation in metres and an IANA time zone such as `Europe/Zurich`. You can request the device's location, but location access is optional and the correct time zone must be checked manually. Choose a **default** site for your usual observing location. Saved sites can be edited or deleted.

From the same screen, you can request **Check satellite data** for a site's light-pollution indicator and use **Compare observing sites** to compare at least two saved places for one catalog target and observing date. The comparison reports astronomical darkness, visibility, available weather and optional terrain/night-light indicators, with clear notices for missing data. Scores are estimates, not guarantees.

## 2. Set up cameras and optics

Open **Equipment** to create cameras, lenses, telescopes and mounts. Enter the sensor size and optical parameters carefully. Create an **optical profile** from your equipment to reuse in framing calculations and projects. The app calculates field of view, effective focal length and image scale from these values. Editing an optical profile can change a previously saved framing calculation, because framing refers to the profile.

## 3. Find and frame a target

In **Targets**, search the offline OpenNGC-based catalog using names or designations and inspect target details. The catalog contains object types, ICRS/J2000 coordinates, aliases and available catalog properties; some objects lack magnitude or dimensions.

Open **Sky Atlas** to explore the DSS2 Color survey. Select an optical profile and use the camera outline to inspect framing. You can center the framing on the atlas view, nudge it, rotate it, save it and restore it for a target. The **Sky dome** option presents a local horizon/sky view using the selected site and time. External Aladin code and sky imagery require an internet connection, even though catalog searches and framing calculations work offline.

## 4. Plan a night

Open **Night Planner** and select your observing location and date. The app shows sunrise/sunset, twilight phases, astronomical darkness and Moon information. The **Interactive night timeline** spans local noon through the following local noon, so after-midnight observing stays on the same planning night. Time-zone and daylight-saving changes are handled using the site's IANA zone and UTC instants.

You can:

- Inspect altitude/visibility tracks for available project-linked targets and optional weather data.
- Choose **Show weather** to request a forecast or display a cached forecast; stale/absent data is identified.
- Add, edit or delete project-linked target blocks using **Schedule target**; overlapping blocks are flagged.
- Enable **Use terrain horizon** to estimate obstruction from DEM terrain rather than assuming only a mathematical horizon. Tune azimuth resolution, range and radial sampling; the calculated profile is cached for later offline use.

Terrain modeling excludes buildings, vegetation, small structures, local cables and refraction. A missing terrain sample means **unknown**, not clear visibility. Respect the terrain source's usage limits and allow time for a first profile download.

## 5. Track imaging projects and sessions

In **Projects**, create a project with a title, selected catalog targets, an optional optical setup, notes, status and integration-time goal. You can edit, archive or delete a project. The detail screen shows the planned/achieved integration time.

Add **Observation sessions** for each imaging run. Record local start date/time and site, camera/optic/mount, exposure length in seconds, total frames, accepted/rejected frames, ISO or gain, aperture and other available parameters, notes and optional images. Equipment and site names are stored as historical snapshots so the log remains understandable if inventory records change.

Only accepted frames contribute to usable integration:

`usable integration (seconds) = exposure duration (seconds) × accepted frames`

The project total sums these durations over its sessions. Rejected or unclassified frames do not count. You may leave the project's integration-time goal unset, in which case the app shows the total without a percentage target.

Images are held outside the SQLite database. If an app installation or browser site data is cleared, unsaved local data and attachments may be lost; create a backup regularly.

## 6. Create a multi-panel mosaic

In **Projects → Project details → Mosaic composition**, create a mosaic for a project target. Select an existing optical profile, set **rows**, **columns**, **overlap percentage**, **rotation** and optionally adjust the center coordinates. The preview calculates individual panel centers and overall angular coverage.

After saving, choose **View in atlas** to see panel footprints over sky imagery. You can export **JSON panel coordinates** in ICRS/J2000 degrees for further processing. This is a planning format, not a mount-specific pointing script. Plate solving, optical distortion, meridian flips and actual field rotation are not modeled.

## 7. Configure opportunity alerts

Open **Settings → Observation opportunity alerts**. Enable notifications only if you want them; Android/iOS notification permission is requested when enabling. Select a catalog target and a saved location, then configure minimum suitability score and continuous observation duration. Edit, disable or delete individual alert rules, and use **Check now** to evaluate them.

An alert is based on the same recommendation engine used for observing opportunities and requires suitable, sufficiently fresh weather data. The app remembers already notified opportunities to avoid repeated alerts for one rule and night.

**Important:** Checks run when the app starts, returns to the foreground or when you request one. Closing the app stops new forecast checks; this is not persistent background monitoring. Web/desktop versions do not issue native mobile notification alerts.

## 8. Back up and restore

Open **Settings → Backup & restore**. Use **Export backup** to create a portable `.ambackup` file (internally ZIP). Enable **Include session images** to include image files; otherwise attachment records without the image bytes are omitted. Keep the file somewhere safe, preferably outside the device.

To restore, choose **Restore backup**. A preview and validation run before any write. **Merge (no overwrites)** rejects identifier conflicts; **Replace all data** requires a separate destructive-action confirmation. Restored projects, sessions, locations, equipment, preferences, observation plans and image links retain their relationships. Old supported `.zip` backups can also be selected. The backup is **not encrypted**; do not publish files containing personal sites or notes.

Technical details: [Backup format](backup-format.md).

## 9. Preferences, offline use and troubleshooting

In **Settings**, choose Codefrog Light, Codefrog Dark, Astronomy Night or system theme, plus measurement units and time display. The current interface is in English; comprehensive localization is not yet included.

| Symptom | What to check |
| --- | --- |
| Atlas tiles do not load | Network/WebGL or WebView support, third-party imagery service availability, and the atlas Retry option. |
| Forecast is missing | Network, selected site and date, request limits, model coverage or cache staleness. Missing weather is not treated as clear. |
| Terrain is missing | DEM coverage, online elevation request limits, distance/resolution and saved observer elevation. |
| Light-pollution value is missing | Selected dataset month, satellite coverage and availability of cloud-free observations. |
| Notification does not appear | Rule enabled, app has run an evaluation, OS permission and notification settings, fresh weather and score/duration thresholds. |
| Old data is not visible after reinstall | Restore a recent `.ambackup` file; local app/browser storage is not automatically synchronized. |

For physical limitations, source conditions and credits see [Data sources and limitations](data-sources.md).

## First-run guide and language

When the app is first opened, its dashboard offers a short optional setup guide. Choose a language (system default, English or German), add an observing location, and optionally configure your imaging equipment. You may skip any step; no account or registration is needed. Location permissions are only requested if you select **Use current location** in the location editor. An observing site can also be entered entirely manually. Restart the guide from **Settings → Open the setup guide**.

Change the interface language later under **Settings → Application preferences → Language**. The language setting persists offline and is included in application preferences backups. Some scientific identifiers, catalog names, third-party dataset credits and numerical units intentionally remain unchanged in translation.

## Atlas control visibility on phones

The mobile Sky Atlas shows the sky first and puts AstroManager's View, Setup, Frame, and Info controls into a collapsible sheet. The Aladin Lite widget toolbar is hidden on narrow viewports to avoid controls overlapping the sky or AstroManager's sheet. Open **Info → Use Aladin controls** to show it again. On wider screens this option is next to the atlas mode selector. The compact attribution label and full data-source credits always remain accessible.

## Accessibility

Flutter screen labels and tooltips use the selected language. Standard UI text follows platform text scaling; dialogs and the onboarding guide are scrollable. Theme text colors were checked for readable light, dark and red astronomy-night contrast. Sky-map imagery, some dense altitude charts and third-party embedded elements have accessibility limitations; a screen reader cannot describe every graphical pixel.


## Personal dashboard

The Dashboard is a local, configurable start page. Choose the observing location
from the selector at the top; **Default observing location** follows the default
saved in Settings. The selection is shared by all dashboard widgets.

Open **Manage widgets** to add and remove widget types or hide them without
deleting their configuration. Each widget's options menu offers configuration,
size selection (where supported), hiding, removal, and keyboard-friendly
ordering. These controls are a foundation for a later drag-and-drop editor.

The initial preset contains a seven-night weather panel, tonight's top targets,
a night summary, and quick actions. The three data-driven panels are explicitly
marked unavailable until their dedicated integrations are implemented; no
forecast or recommendation is synthesized. Quick actions already open their
respective AstroManager screens. An optional **Observing Site** widget shows
your selected location and coordinates.

Layout, visible widgets, sizes, per-widget settings and observing location are
all stored locally as versioned JSON in `app_settings` and included in
`.ambackup` exports. Hidden widgets are not built and do not request data.

The dashboard works offline; future forecast widgets will identify missing and
stale data rather than assume favorable observing conditions.
