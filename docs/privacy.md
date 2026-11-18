# Privacy and network requests

AstroManager uses local storage for observing sites and their coordinates,
equipment, favorites, plans, sessions, notes, photos and app preferences.
The app has no account, analytics SDK, advertising SDK, or remote crash
reporting integration. It does not collect device location in the background.
**Use current location** asks the operating system or browser for a position.
You can also enter coordinates manually.

## When the app connects

| Service | When contacted | Data sent |
| --- | --- | --- |
| [Open-Meteo](https://open-meteo.com/en/terms) | When a forecast is needed for the selected site and a current cached forecast does not cover the request. The Dashboard refresh explicitly requests a download. Enabled local observing alerts can request weather when the app starts or resumes. | Site latitude and longitude rounded to five decimal places, UTC dates, forecast variables and model. |
| [OpenTopoData](https://www.opentopodata.org/#public-api) | When you request a terrain horizon in the site settings, or run a site comparison with terrain enabled and a matching saved profile is unavailable or stale. | Coordinates of points sampled around the site and the elevation dataset name. The point pattern can reveal the observing area. |
| [jsDelivr](https://www.jsdelivr.com/terms/privacy-policy) and [ESA HiPS](https://skies.esac.esa.int/DSSColor/properties) | When you open the interactive Sky Atlas. | Viewer files and survey tiles requested for the current sky view. Depending on the viewer action, Aladin can contact its upstream astronomy services. The browser atlas runs in a sandbox without access to app storage and keeps its internal viewer preferences in memory. |
| [Google Fonts](https://developers.google.com/fonts/faq/privacy) | Flutter Web can download font files during startup or when a glyph requires a fallback font. | The font file URL and ordinary network metadata. |

These services can see the network address and ordinary request headers, such
as the browser or client identification. The site name, local record ID,
equipment, personal notes, and photos are outside the required request
payloads. When AstroManager runs in a browser, its hosting service also
receives ordinary requests for the app and its files. Opening a source credit
loads the provider's website using the default browser.

## Saved data, caches, and backups

- Weather and terrain use local caches. Cached coordinates
  or samples may remain after a saved site is changed or removed. Clearing the
  app data or the browser's site data removes local records and cached data.
- Portable `.ambackup` exports can contain precise site coordinates, notes and
  selected photos. The ZIP-based format is unencrypted. The file remains where
  you save or share it. A copy in a cloud folder follows that service's rules.
  See the [backup format](backup-format.md).
- The bundled OpenNGC catalog, astronomical calculations and saved Bortle
  classes can be used offline.
- Local observing notifications can show the target and observing window if
  enabled. The platform's notification settings control where they are shown.

Licensed data, service terms and scientific limitations are described in
[Data sources and limitations](data-sources.md).
