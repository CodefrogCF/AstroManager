# Data Sources, Attribution and Scientific Limitations

AstroManager separates *local astronomical calculations* from *third-party data*. Provider availability, source terms, update schedules and permitted uses may change. Credits below reflect the integrations in the supplied v0.6.0 source tree; review current service conditions before commercial use or redistribution.

## Source inventory

| Data | Current source and status | Representation and required context |
| --- | --- | --- |
| Celestial objects | [OpenNGC](https://github.com/mattiaverga/OpenNGC), bundled as `assets/catalog/openngc_20260501.json` | ICRS/J2000 RA/Dec, object identity and available photometric/dimensional fields. Offline. OpenNGC data license text: [`assets/catalog/LICENSE-OpenNGC.txt`](../assets/catalog/LICENSE-OpenNGC.txt) (CC BY-SA 4.0). |
| Sky imagery | **DSS2 Color**, HiPS survey served via ESA (`https://skies.esac.esa.int/DSSColor`); displayed using **Aladin Lite 3.8.1**, CDS/CNRS/Université de Strasbourg | External Aladin runtime and survey imagery require network/WebGL. Preserve the Aladin logo/link and survey credits. |
| Weather | [Open-Meteo Forecast API](https://open-meteo.com/en/docs) (`https://api.open-meteo.com/v1/forecast`) | Hourly forecast values, UTC Unix timestamps, source and cache/fetch time. Weather data credit: **Weather data by Open-Meteo.com**; attribution and provider terms apply. |
| Terrain heights | [OpenTopoData API](https://www.opentopodata.org/api/), configured for `eudem25m` (EU-DEM) | Digital elevation in metres sampled along site bearings. Cached terrain horizon is an approximation, not surveyed line of sight. |
| Night-light radiance | [Esri ArcGIS NighttimeLightsMDNB ImageServer](https://di-lawimagery1.img.arcgis.com/arcgis/rest/services/NighttimeLightsMDNB/ImageServer), EOG/NOAA-derived monthly VIIRS nighttime lights | Upward radiance in **nW/cm²/sr**; current fixed data month **December 2025**. Not SQM, measured sky brightness or an observed Bortle class. |
| Moon positions | Offline astronomical model with documented Meeus-derived code | Approximate ephemeris for planning, not a substitute for high-precision professional ephemerides. Bundled license: [`docs/licenses/meeus_mit_license.txt`](licenses/meeus_mit_license.txt). |

### Survey and catalog credits

For DSS2 Color, retain **Digitized Sky Survey (STScI/NASA)** and processing/HiPS credits from **CDS/CNRS/Université de Strasbourg** as specified by [survey metadata](https://skies.esac.esa.int/DSSColor/properties). ESA provides the survey mirror. Aladin Lite is provided by CDS/Université de Strasbourg/CNRS; keep its viewer attribution visible. Source catalog: OpenNGC by Mattia Verga and contributors, with the included CC BY-SA 4.0 notice.

Do not include unrelated surveys (e.g. Pan-STARRS or Gaia) in current-runtime image credits unless those layers are actually added.

### Weather conditions and licensing

The Open-Meteo free hosted endpoint has separate usage conditions from the underlying forecast data license. Its public free usage is intended for non-commercial use; review [pricing](https://open-meteo.com/en/pricing), [terms](https://open-meteo.com/en/terms) and any model-specific credit before shipping a commercial product. The data carries CC BY 4.0 attribution obligations. AstroManager normalizes units and filters by requested UTC hours; an API fetch time is **not proof** of the underlying forecast model issuance time. Missing or stale forecast values must not be treated as cloud-free conditions.

### Terrain horizons and their uncertainty

The provider samples radial elevation paths at configurable azimuth, radial step and radius, applies an approximate Earth-curvature correction and compares terrain with stored observer elevation. Sample resolution, 25 m nominal grid, finite range and missing data can miss peaks. **Buildings, trees, cables, towers, atmospheric refraction and local obstructions are not modeled.** Unknown bearings remain unknown.

The public OpenTopoData instance documents limits (at implementation: 100 locations/request, 1 request/s, 1000 requests/day). AstroManager batches/throttles requests and caches profiles; verify the current server limits before deployment. High-resolution Swiss **swissALTI3D** data may support a future provider, but is **not directly integrated**. Reference: [swisstopo swissALTI3D](https://www.swisstopo.admin.ch/en/height-model-swissalti3d).

### What satellite night-light values do—and do not—mean

The configured VIIRS provider uses a monthly composite from December 2025 via Esri, based on Earth Observation Group / NOAA data. Relevant [dataset catalog](https://www.arcgis.com/home/item.html?id=edabcbb5407547f5bc883018eb6e7986) and [EOG data information](https://eogdata.mines.edu/products/vnl/). Give credit to **Earth Observation Group (Payne Institute, Colorado School of Mines) / NOAA; distribution via Esri ArcGIS**. Pixel radiance is upward night emission, affected by spatial resolution and satellite sampling; it does not directly measure the darkness of the zenith, distant light domes or current transparency.

AstroManager uses a bounded **relative comparison indicator** from satellite radiance, not a physical sky-quality value. Compare values only when source and acquisition month match. A pixel with missing cloud-free observations must be *no data*, not zero light. The interface differentiates **measured SQM** (`mag/arcsec²`), **modeled sky brightness** (`mag/arcsec²`) and **satellite radiance** (`nW/cm²/sr`); the included provider supplies only the last of those. The optional scoring factor defaults to zero influence.

Do not scrape/repackage hosted imagery or claim unrestricted rights to Esri-hosted tiles without checking its terms. The implementation requests point values rather than republishing raster imagery.

### Bundled Bortle estimate

The observing-location screen looks up an offline estimate in a grid prepared from the **2024 EOG VIIRS Nighttime Lights annual average** distributed by [Tomislav Hengl and OpenLandMap](https://doi.org/10.5281/zenodo.17294744). It models typical clear, moonless sky brightness at the zenith, then applies the [published First Rig Bortle bins](https://firstrig.com/method/sky-brightness). The brightest bin covers classes 8–9. With the model's reference natural sky of 21.83 mag/arcsec², the darkest result is class 2.

The grid samples one cell per 0.05° (about 5.6 km north to south) between 60°S and 75°N. The result can vary from a local observation because of neighborhood lighting, terrain, aerosols, clouds and the natural sky. Modeled classes are displayed independently of the site's saved observer-reported class and of the optional online radiance reading.

#### Regenerate the grid

1. Download `nightlights.average_viirs.v21_m_500m_s_20240101_20241231_go_epsg4326_v20250904.tif` from the [OpenLandMap record](https://zenodo.org/records/17294744). The generator checks its SHA-256 before reading it.
2. In a Python 3.12 environment, run `python -m pip install numpy==2.5.5 scipy==1.18.1 rasterio==1.5.2`.
3. Run `python tool/build_bortle_grid.py <source.tif> assets/light_pollution/bortle_2024.zip`.

The generator averages the pinned 2024 raster's stored samples onto a 1 arcminute grid. Checks against raw monthly EOG radiance at public coordinates confirmed their order of magnitude. It applies the distance-dependent [Duriscoe et al. kernel](https://doi.org/10.1016/j.jqsrt.2018.04.028) with First Rig's zenith coefficients, 300 km cutoff, and a minimum source distance of 1 km. It approximates east-west cell size at the midpoint of each five-degree latitude band and includes neighboring bands and the wrapped longitude edge in the convolution. Unsupported cells use code zero. The archive holds one byte per output cell, format metadata and attribution.

## Limits of predictions and local data

- A predicted suitability score is a planning heuristic rather than a probability of a successful image or a promise of clear sky.
- The sky atlas may show tile gaps or fail on unsupported WebGL/WebView platforms; successful loading does not certify every detailed tile.
- Catalog magnitudes and apparent angular sizes may be incomplete or differ from a target's full photographic extent.
- Time zones, historical daylight-saving offsets and observer elevation must be correct for site-based visibility.
- Offline caches show previously fetched data; old weather or radiance cannot describe the current observing night without checking timestamps.
- The app does not autonomously refresh forecasts in the background while closed.

**Privacy:** Saved sites, equipment, projects, sessions and notes are local. When you request online weather, terrain, night-light or atlas data, the relevant coordinates, time or pointing can be transmitted to the selected third-party service. Exported `.ambackup` archives may contain exact locations and notes and are not encrypted.
