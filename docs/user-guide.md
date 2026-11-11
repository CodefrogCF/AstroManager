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

From a target in an existing project, select **Open Night Planner** to open the planner with that project and target selected. If the project has an observing location and date, the planner uses them as defaults. Choose the location and night you want, then select **Schedule target** to set a start time and duration and save the block.

The **Night overview** shows the site's astronomical darkness, how much of it is unscheduled, and the local time slot for each planned target. Use the edit or delete button beside a block to update the schedule. Overlapping blocks are flagged in the list and on the timeline.

The **Interactive night timeline** spans local noon through the following local noon. Start times before noon belong to the next calendar day. Repeated clock times during a daylight-saving transition show their UTC offsets. Sunrise, sunset, twilight and Moon details are below the timeline.

You can:

- Inspect altitude/visibility tracks for available project-linked targets and optional weather data.
- Open **Timeline options** to adjust zoom or the minimum target altitude. If weather is available on request, select **Show weather** there.
- Enable **Use terrain horizon** to estimate terrain obstruction from a digital elevation model. Tune azimuth resolution, range and radial sampling. The calculated profile is cached for later offline use.

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
a night summary, and quick actions. Forecasts and recommendations use the existing
weather and astronomy services. Quick actions open their respective AstroManager
screens. An optional **Observing Site** widget shows your selected location,
cached terrain-horizon coverage, and cached night-light information.

Select **Refresh forecast** in the **7-Night Forecast** widget to request a new
forecast for the selected observing location. The widget shows when the request
is in progress and keeps the previous forecast and its age visible if the
request fails.

The clear-sky view defaults to **Night only**, which counts qualifying forecast
hours during the remaining astronomical darkness. Choose **Full day** to count
hours from local midnight to the following midnight at the observing site,
including daylight. The choice applies to both the total clear hours and the
longest clear period. Tap a date tile for the breakdown and forecast coverage.

Layout, visible widgets, sizes, per-widget settings and observing location are
all stored locally as versioned JSON in `app_settings` and included in
`.ambackup` exports. Hidden widgets are not built and do not request data.

The dashboard remains usable offline. Weather and environmental widgets identify
missing or stale data rather than infer favorable observing conditions.

## Customizing the Dashboard

Select **Edit layout** on the Dashboard to rearrange your widgets. Drag a widget
by its grip and use the highlighted outline to see where it will land. On
larger screens you can also move widgets between columns. The move arrows
provide a keyboard- and screen-reader-friendly way to move widgets.

Select **Resize** above a widget to adjust its width in half-column steps and
its height in quarter-row steps. A phone layout has one full-width column.
Widgets below shift to make room or close gaps when you save the new size.
Widget sizes and positions are saved separately for phones, tablets, and
desktop-sized windows. Select **Done editing** to return to normal interaction.

On compact phones, the edit controls wrap to a second row when needed.
At increased system font sizes the dashboard reserves more vertical space,
while the content inside each card can still scroll independently. On a
keyboard, use **Tab** / **Shift+Tab** to select buttons, **Enter** or **Space**
to activate **Move up/down/left/right** and **Resize** to change dimensions.
The move controls also work with switches. Changing orientation can select a
different saved device-size layout; it does not overwrite the other layouts.

**Manage widgets** adds or removes widget types and lets you hide unused
widgets. Hidden widgets are not built and do not fetch their own data.
**Reset layout** resets only the current screen class after confirmation;
**Restore default widgets** resets the complete widget list. The shared
observing location is not changed by a layout reset.

If the saved dashboard layout cannot be read, an explicit **Restore default
widgets** action is offered. This replaces the invalid dashboard configuration
only when selected; other local data is unaffected. Create a `.ambackup`
before resetting settings if you want to retain a copy of the stored data.

Your layout is stored locally, included in `.ambackup` exports and restored
along with other application preferences. Backups with linear or whole-cell
Dashboard layouts are still supported.

## Observing Site conditions

The optional **Observing Site** dashboard widget shows cached environmental
information for the dashboard's selected observing location. It never fetches
terrain or night-light data automatically. To obtain or update those datasets,
open **Manage site data** and use the existing location panels, then tap
**Refresh cached site data** on the dashboard to reread the local caches.

The terrain summary shows how many azimuth bearings are covered by the cached
EU-DEM/OpenTopoData profile. Missing bearings are **unknown**, not clear; terrain
modeling does not account for nearby buildings or trees and is not a guaranteed
line-of-sight assessment. The details display the profile creation date and
source.

For night lights, the widget preserves the source's measurement type and units.
The default VIIRS monthly product represents **satellite upward radiance in
nW/cm²/sr** (EOG/NOAA via Esri), **not** measured zenith sky brightness, an
SQM value, or a Bortle rating. The original dataset month, retrieval date,
provider, attribution, and license notes are shown when available. Stale data
are marked explicitly. Use **Compare observing sites** to open the existing
site-comparison panel when multiple saved locations are available.

## Dashboard performance, offline use and accessibility (v0.7)

The visible project widgets share the same session aggregation provider. When
multiple instances use the same forecast request, the Riverpod provider shares
its in-flight result; independently configured date ranges or sites may still
require different requests. Environmental site cards read **only local caches**,
with terrain and night-light cache reads running concurrently. Hiding a widget
prevents its content from being mounted and requesting data.

Missing weather or satellite data is not evidence of clear conditions. Stale
forecasts and environmental readings are marked; the dashboard does not imply
live monitoring. On a narrow display, scroll the card itself to reach long
content and use **Manage widgets** to hide less frequently needed panels.

Codefrog Light/Dark and Astronomy Night Mode use separate palettes. The night
palette now has stronger card boundaries so controls remain distinguishable
without replacing its red-light-oriented appearance. For detailed release
checks on phone, tablet, desktop, iOS/Android and offline operation, see
[`dashboard-v0.7.0-qa.md`](dashboard-v0.7.0-qa.md).
