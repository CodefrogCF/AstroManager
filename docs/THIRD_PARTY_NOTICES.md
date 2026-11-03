# Third-party licenses, data sources, and attribution

AstroManager's original application code is distributed under the Apache License,
Version 2.0 (`Apache-2.0`), as set out in the repository-root `LICENSE`.
This file identifies third-party materials and remotely accessed services.
**The project-wide software license does not override third-party terms.**

## 1. Bundled OpenNGC catalogue — CC BY-SA 4.0

- **Material:** `assets/catalog/openngc_20260501.json`.
- **Source:** OpenNGC by Mattia Verga and contributors,
  <https://github.com/mattiaverga/OpenNGC> (source release `v20260501`).
- **License:** Creative Commons Attribution-ShareAlike 4.0 International
  (`CC BY-SA 4.0`), <https://creativecommons.org/licenses/by-sa/4.0/>.
- **Full license:** `assets/catalog/LICENSE-OpenNGC.txt`.
- **Modifications:** The original catalog's CSV data were converted into
  a compact application JSON dataset; fields were normalized, entries were
  filtered/deduplicated, and common identifiers were retained.
- **Redistribution:** The adapted catalog remains under `CC BY-SA 4.0`.
  Its license and attribution must accompany copies and adaptations.

See `docs/celestial-catalog.md` for the import and transformation description.
The AstroManager software's Apache-2.0 license does not apply to the catalog.

## 2. Meeus-related source attribution — MIT

The repository includes a third-party MIT license notice for astronomical
algorithms credited to **Sonia Keys (2018)**:
`docs/licenses/meeus_mit_license.txt`. Preserve that notice when redistributing
covered source material. Those authors' contributions are not relicensed by
AstroManager's Apache-2.0 notice.

## 3. Aladin Lite sky atlas — LGPL-3.0-or-later

- **Library:** Aladin Lite by CDS / Université de Strasbourg / CNRS.
- **Project:** <https://github.com/cds-astro/aladin-lite>.
- **License:** GNU Lesser General Public License, version 3 or later,
  <https://github.com/cds-astro/aladin-lite/blob/master/LICENSE>.
- **Current integration:** `assets/atlas/atlas.html` loads version `3.8.1`
  as an external ES module via jsDelivr. The library source is not included
  in AstroManager's repository by this integration.
- **Attribution:** Retain the Aladin logo/link and any notices in the viewer.

If a future release bundles, modifies, or redistributes Aladin Lite itself,
check and fulfil the LGPL's requirements for that form of distribution.

## 4. Sky-survey imagery — provider-specific rights

The current atlas displays **DSS2 Color** via the ESA HiPS mirror:
<https://skies.esac.esa.int/DSSColor>.

- Credit the Digitized Sky Survey / STScI / NASA, and CDS / CNRS /
  Université de Strasbourg for the color HiPS processing, as appropriate.
- Respect the particular survey's `obs_copyright`, `hips_creator`,
  `obs_ack`, and other terms in its HiPS `properties` metadata.
- The images are remotely accessed. They are **not** licensed under
  AstroManager's Apache-2.0 license; do not redistribute tiles or copies
  without verifying the corresponding permissions.

See `docs/atlas-sources-and-resilience.md` for the exact source and credits.

## 5. Open-Meteo forecasts — CC BY 4.0 data, API usage terms

- **Provider:** Open-Meteo, <https://open-meteo.com/>.
- **Data license:** Creative Commons Attribution 4.0 International,
  <https://creativecommons.org/licenses/by/4.0/>.
- **Attribution:** “Weather data by Open-Meteo.com”, including a link to
  <https://open-meteo.com/> where weather data are shown; indicate changes
  to the data where applicable.
- **Service conditions:** The free hosted API is for permitted non-commercial
  usage, with usage restrictions. Commercial uses may require a paid plan.
  The open-source nature of AstroManager does not itself authorize every use
  of the hosted service.
- **Redistribution:** The AstroManager repository does not include Open-Meteo
  server code. That server's AGPL license is distinct from the CC BY data
  license and does not automatically govern the API-consuming application.

See `docs/open-meteo-provider.md` and the provider's current terms.

## 6. Terrain elevation — Open Topo Data / Copernicus EU-DEM

- **Service:** Open Topo Data, <https://www.opentopodata.org/>.
- **Dataset:** EU-DEM (Copernicus), where available.
- **Attribution:** Acknowledge Copernicus / European Union as the underlying
  data provider and Open Topo Data as the serving service. Indicate if
  data are adapted or processed into a modeled horizon profile; do not
  imply EU endorsement.
- **Terms:** See <https://www.opentopodata.org/datasets/eudem/> and the
  current public API usage limits. The service software's MIT license
  is not a license for all elevation datasets.

The generated horizon profile is a model, not verified line-of-sight data.

## 7. Satellite nighttime-light values — EOG / NOAA / Esri

- **Data:** Monthly VIIRS DNB nighttime-light radiance derived from Earth
  Observation Group (EOG) / NOAA sources.
- **Current service:** Esri's `NighttimeLightsMDNB` ArcGIS ImageServer.
- **Credit:** Earth Observation Group, Payne Institute for Public Policy,
  Colorado School of Mines / NOAA; served via Esri ArcGIS Online.
- **Restrictions:** Keep the dataset month and the satellite-radiance unit
  (`nW/cm²/sr`) with displayed values. Provider terms may differ for
  raw data versus Esri-hosted imagery. The application accesses site-level
  values; do not bulk-copy or republish hosted tiles without verifying terms.

See `docs/implementation/issue-33-light-pollution.md` for the data product,
service, limitations, and detailed source references.

## 8. Flutter / Dart / package dependencies

Dart and Flutter dependencies listed in `pubspec.yaml` retain their own
copyright and license notices; they are not relicensed by this file.
When distributing compiled applications, preserve all notices required by
those packages. Flutter's built-in license registry can be presented in an
in-app About / Licenses screen, but should be verified for all bundled assets
and JavaScript components.

## Maintenance checklist

When adding or changing a third-party library, dataset, map tile layer, or
API, confirm the specific version's license, attribution, redistribution
rights, commercial-service conditions, and in-app notice requirements.
Keep this file and the relevant feature documentation updated.
