# AstroManager

AstroManager is an offline-first astrophotography planning application built with Flutter. It combines a local celestial-object catalog, observing-site and equipment management, nighttime planning, imaging projects, observation logs, and an interactive sky atlas. Optional online data can refine recommendations with weather forecasts, terrain and satellite night-light information.

**Current application version:** `0.6.0+6`.

## What you can do

| Area | Features |
| --- | --- |
| **Targets** | Browse and search the bundled OpenNGC catalog; inspect object coordinates, visibility and observational details; open objects in the sky atlas. |
| **Sky atlas** | Explore DSS2 Color imagery in Aladin Lite; overlay local horizon, camera framing and saved multi-panel mosaic footprints. |
| **Night Planner** | Inspect sunset, sunrise, twilight, astronomical darkness, Moon conditions, target altitude and visibility; organize multiple project targets on an interactive timeline. |
| **Equipment** | Manage cameras, lenses, telescopes and mounts; build reusable optical setups and calculate field of view and image scale. |
| **Projects** | Organize targets, imaging goals, project status and integration-time targets; log sessions, exposure parameters, notes and optional images. Only accepted frames count toward usable integration time. |
| **Advanced planning** | Estimate terrain obstruction, inspect available VIIRS satellite night-light radiance, compare observing locations and design/export mosaic panels. |
| **Settings and data** | Save observing sites and preferences, configure optional observation-opportunity alerts, and export/restore portable `.ambackup` files. |

The Dashboard currently provides a welcome view, not an analytics dashboard.

## First observing night

1. Open **Settings → Observing Locations** and add a site with accurate coordinates, elevation and **IANA time zone** (for example `Europe/Zurich`). Make it the default site if appropriate.
2. In **Equipment**, add your camera, lens or telescope, mount and optical profile. Accurate sensor size and focal length are needed for framing and mosaics.
3. Find an object in **Targets**. Open its details or select **Sky Atlas** to inspect its framing against the selected setup.
4. Open **Night Planner**, select a site and observing date, and inspect the darkness and target-altitude timeline. Add project-linked observation blocks as needed.
5. Create an imaging goal in **Projects**; record each observing session, including exposure time and accepted/rejected frame counts. Watch accumulated integration time update.
6. Under **Settings → Backup & restore**, save an `.ambackup` copy of your data. Enable **Include session images** if you want attachments in that backup.

For screen-by-screen instructions, see the [User guide](docs/user-guide.md).

## Language, first-run setup and accessibility

AstroManager supports English and German. Use **Settings → Application preferences → Language** to follow the device language or select English/Deutsch. The selection is saved offline. On the dashboard, the optional first-run guide introduces language selection, observing sites and equipment. You can skip it at any point and reopen it in Settings. No account is required, and location access is only requested if you explicitly select **Use current location**.

On phones, the sky atlas prioritizes the map. Expand the mobile control panel and open **Info → Use Aladin controls** to show or hide the embedded Aladin Lite buttons. On larger displays, the switch is also available above the atlas. AstroManager's own framing controls and source credits remain available independently. Embedded Aladin controls are hidden by default on narrow screens to prevent overlapping controls.

Native Flutter labels respect system text scaling and screen readers. Some dense plotting and third-party atlas content may still require zooming or direct interaction; verify your device's accessibility settings before observing.

## Offline and online features

- **Available locally:** bundled target catalog, saved sites/equipment/projects/sessions, astronomical calculations, mosaic geometry, observation plans and cached information.
- **Requires network access when fetching new data:** Open-Meteo forecasts, terrain heights via OpenTopoData, VIIRS night-light values and Aladin Lite's external viewer/survey imagery.
- **Not a guaranteed forecast or line-of-sight tool:** weather can be outdated; DEM horizons omit buildings and trees; satellite radiance is **not** a measured Bortle class.
- **Notifications:** optional on Android/iOS, evaluated on app launch, foreground resume or manual check. AstroManager does **not** guarantee continuous background weather monitoring.

See [Data sources and limitations](docs/data-sources.md) for credits, source conditions and scientific limitations.

## Platforms

The repository contains runners for **Android, iOS, Web and Windows**. Platform availability and plugin support must be verified for each build. The embedded Aladin sky viewer works on supported Web/WebGL and mobile WebView environments; on native Windows, use the Web build for the atlas. Native iOS builds require macOS/Xcode and appropriate signing. Web and Windows do not currently send the mobile opportunity system notifications.

## Build from source

Install the Flutter SDK version specified in [`.fvmrc`](.fvmrc) and the platform's required build tools.

```bash
git clone https://github.com/CodefrogCF/AstroManager.git
cd AstroManager
flutter pub get
flutter gen-l10n
flutter run -d chrome
```

For other configured platforms, select a connected device with `flutter devices` and use `flutter run -d <device-id>`. Generated Drift files are already included in the repository; regenerate them after schema changes with `dart run build_runner build --delete-conflicting-outputs`.

Developer checks and contribution guidelines are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

- [User guide](docs/user-guide.md) — setup, workflows, backup and alerts.
- [Architecture and development](docs/architecture.md) — storage, algorithms, extension points and testing.
- [Data sources and limitations](docs/data-sources.md) — catalog, survey, weather, terrain, light pollution and attribution.
- [Backup format](docs/backup-format.md) — portable `.ambackup` structure and restore guarantees.

## Data and credits

AstroManager stores personal planning records locally; optional provider requests use the location/time required to retrieve data. The built-in catalog is based on **OpenNGC** (license text at [`assets/catalog/LICENSE-OpenNGC.txt`](assets/catalog/LICENSE-OpenNGC.txt)). The bundled Meeus-derived component's license text is at [`docs/licenses/meeus_mit_license.txt`](docs/licenses/meeus_mit_license.txt). External imagery and data retain their own credits and conditions.