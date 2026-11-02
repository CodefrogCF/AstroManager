# Issue #33 — Light-pollution data integration

## Purpose and scientific distinctions

AstroManager distinguishes three physically different concepts:

* **Measured zenith sky brightness**: an instrumental SQM value in **mag/arcsec²**, observed on a specific night. Higher values mean darker sky. These readings are not supplied by the current provider.
* **Modeled sky brightness**: predicted zenith sky brightness in **mag/arcsec²**, contingent on atmosphere, ground lighting and model assumptions. These readings are not supplied by the current provider.
* **Satellite upward night-light radiance**: VIIRS radiance in **nW/cm²/sr**. This measures light leaving the ground in the sensor band; **it does not measure what a human observer sees at the zenith**. It must never be directly displayed as Bortle or SQM.

The source-backed label and unit are part of each record. A `0` is only used when the source confirms at least one cloud-free observation; no-data is `null`, not a dark sky.

## Provider and data year

Default provider: Esri's ArcGIS ImageServer **NighttimeLightsMDNB**, a monthly cloud-free VIIRS DNB composite generated from Earth Observation Group / NOAA data.

* Service: https://di-lawimagery1.img.arcgis.com/arcgis/rest/services/NighttimeLightsMDNB/ImageServer
* Dataset catalogue: https://www.arcgis.com/home/item.html?id=edabcbb5407547f5bc883018eb6e7986
* Underlying data: https://eogdata.mines.edu/products/vnl/
* Queries: ArcGIS `identify` at WGS84 point with a mosaic rule fixed to **December 2025**. The raw-radiance raster function is requested explicitly rather than the contrast-stretched display function. A second query fetches cloud-free observations for the same pixel/month.
* Data period: December 2025, not a current-night observation. Catalogue metadata last updated 2026-05-28. This is **not** the measurement publication date.
* Provider reference data unit: nW/cm²/sr. Cloud-free count is in observations. ArcGIS service spatial resolution ~464 m (EPSG:3857). Pixel footprints, weather filters and time coverage limit precision.
* Coverage advertised by the catalogue: approximately 75°N to 65°S; coverage may be absent, including at northern latitudes during extended daylight.

Service availability, free-query quota, CORS support and third-party terms can change. The provider is replaceable. Queries have a 20-second timeout and return a clear error instead of fabricated results. This feature does not incorporate third-party map tiles.

## Licensing and attribution

Data credit: **Earth Observation Group (EOG), Payne Institute for Public Policy, Colorado School of Mines / NOAA, served through Esri ArcGIS Online**. Cite the dataset and month in screenshots and exported analyses. NOAA/EOG annual VIIRS datasets are distributed as public data, but terms for Esri's hosted imagery service and tile redistribution may differ; **do not bundle or republish their tiles without verifying those permissions**. The current implementation queries pixel values and caches single-location results only. No bulk scraping.

References:
- https://developers.google.com/earth-engine/datasets/catalog/NOAA_VIIRS_DNB_ANNUAL_V22
- https://www.arcgis.com/home/item.html?id=edabcbb5407547f5bc883018eb6e7986
- https://developers.arcgis.com/rest/services-reference/enterprise/identify-image-service/
- https://knowledge-hub-gda.esa.int/eo_capability/nighttime-lights/

Alternatives considered: NASA Black Marble (research-grade remote sensing, requires additional access/processing), Falchi et al. World Atlas (modeled sky brightness and separate licensing), Globe at Night citizen readings (measured or visual, but sparse, spatially/temporally heterogeneous; should not be interpolated as measured values), and Light Pollution Map commercial map layers (not automatically authorized for in-app tiles or scraping).

## Local caching and missing data

The cache uses `SharedPreferencesAsync` with a SHA-256 key containing the provider version and exact coordinates. Cache refresh is due after 30 days; an old value can be shown offline with a prominent **stale** flag and the original dataset date. Returning genuine no-data removes any cached value. Changing site coordinates forces a new key. The cache is derived data and is deliberately not included in user backups. No network calls occur for every saved site when opening the locations page: press **Check satellite data**.

## Suitability use

The app displays a **relative VIIRS indicator** `100 * 5/(5 + upward_radiance)` (0–100). This is a bounded *heuristic* for comparing points in the **same satellite dataset**, not an SQM estimate, Bortle class or actual sky-visibility probability. It does not account for distant light domes, blue LED emissions, horizon shielding, snow or aerosol scattering. It is not suitable for absolute comparisons with measured sky darkness.

The existing astrophotography scorer supports the optional `lightPollution` reading and an independently configurable `SuitabilityWeights.lightPollution` weight. Its default is **zero** to preserve existing recommendation behaviour and avoid suggesting that satellite data are an absolute image-quality measurement. A reading with mismatched coordinates or wrong quantity contributes no score. Application-level recommendation inputs may pass this reading when enabled explicitly.

## Testing / known limits

Unit and mocked HTTP tests cover metadata and unit preservation, cloud-free validation, missing-data behaviour, zero pixels, invalid values, coordinate-aware caches, stale offline fallback, and opt-in scoring. **Actual live ArcGIS interoperability, quota/CORS behaviour and comparisons against SQM measurements must still be manually verified.** No guarantees of actual darkness, ability to image a particular target, or seeing the Milky Way.
