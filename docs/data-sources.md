# Data Sources, Attribution and Scientific Limitations

AstroManager uses locally computed astronomy and third-party data. Provider availability, source terms, update schedules and permitted uses may change. Review the hosted service conditions before commercial use or redistribution.

## Source inventory

| Data | Current source and status | Representation and required context |
| --- | --- | --- |
| Celestial objects | [OpenNGC](https://github.com/mattiaverga/OpenNGC), bundled as `assets/catalog/openngc_20260501.json` | ICRS/J2000 RA/Dec, object identity and available photometric/dimensional fields. Offline. OpenNGC data license text: [`assets/catalog/LICENSE-OpenNGC.txt`](../assets/catalog/LICENSE-OpenNGC.txt) (CC BY-SA 4.0). |
| Sky imagery | **DSS2 Color**, HiPS survey served via ESA (`https://skies.esac.esa.int/DSSColor`); displayed using **Aladin Lite 3.8.1**, CDS/CNRS/Université de Strasbourg | External Aladin runtime and survey imagery require network/WebGL. Preserve the Aladin logo/link and survey credits. |
| Weather | [Open-Meteo Forecast API](https://open-meteo.com/en/docs) (`https://api.open-meteo.com/v1/forecast`) | Hourly forecast values, UTC Unix timestamps, source and cache/fetch time. Weather data credit: **Weather data by Open-Meteo.com**; attribution and provider terms apply. |
| Terrain heights | [OpenTopoData API](https://www.opentopodata.org/api/), configured for `eudem25m` (EU-DEM) | Digital elevation in metres sampled along site bearings. Cached terrain horizon is an approximation, not surveyed line of sight. |
| Moon positions | Offline astronomical model with documented Meeus-derived code | Approximate ephemeris for planning, not a substitute for high-precision professional ephemerides. Bundled license: [`docs/licenses/meeus_mit_license.txt`](licenses/meeus_mit_license.txt). |

### Survey and catalog credits

For DSS2 Color, retain **Digitized Sky Survey (STScI/NASA)** and processing/HiPS credits from **CDS/CNRS/Université de Strasbourg** as specified by [survey metadata](https://skies.esac.esa.int/DSSColor/properties). ESA provides the survey mirror. Aladin Lite is provided by CDS/Université de Strasbourg/CNRS; keep its viewer attribution visible. Source catalog: OpenNGC by Mattia Verga and contributors, with the included CC BY-SA 4.0 notice.

Do not include unrelated surveys (e.g. Pan-STARRS or Gaia) in current-runtime image credits unless those layers are actually added.

### Weather conditions and licensing

The Open-Meteo free hosted endpoint is subject to [non-commercial use and request quotas](https://open-meteo.com/en/terms). The [forecast data license](https://open-meteo.com/en/license) requires attribution and a link with the displayed data. AstroManager normalizes units and selects the UTC hours covering the requested window. Forecast age uses the retrieval time, which may differ from the model publication time. Missing or stale forecasts yield provisional planning results.

### Terrain horizons and their uncertainty

The provider samples radial elevation paths at configurable azimuth, radial step and radius, applies an approximate Earth-curvature correction and compares terrain with stored observer elevation. Sample resolution, 25 m nominal grid, finite range and missing data can miss peaks. **Buildings, trees, cables, towers, atmospheric refraction and local obstructions are not modeled.** Unknown bearings remain unknown.

[OpenTopoData's public instance](https://www.opentopodata.org/#public-api) documents 100 locations per request, one request per second, and 1,000 requests per day. AstroManager sends up to 90 points per batch, with at least 1.1 seconds between request starts from the same provider instance. It caches the resulting profiles. The profiles contain modified Copernicus/European Union EU-DEM data. [EU-DEM coverage and terms](https://www.opentopodata.org/datasets/eudem/).

### Observer-reported sky darkness

Enter a Bortle class from 1 to 9 for each observing location. The class describes typical site darkness and is saved locally with the site. The suitability score uses it with a default weight of 5% when provided. Conditions for a specific date come from the selected night’s weather forecast and astronomical calculations.

## Limits of predictions and local data

- A predicted suitability score is a planning heuristic rather than a probability of a successful image or a promise of clear sky.
- The sky atlas may show tile gaps or fail on unsupported WebGL/WebView platforms; successful loading does not certify every detailed tile.
- Catalog magnitudes and apparent angular sizes may be incomplete or differ from a target's full photographic extent.
- Time zones, historical daylight-saving offsets and observer elevation must be correct for site-based visibility.
- Offline caches show previously fetched data; check forecast timestamps before drawing conclusions about the current observing night.
- The app does not autonomously refresh forecasts in the background while closed.

[Privacy and network requests](privacy.md) documents what leaves the device and when.
