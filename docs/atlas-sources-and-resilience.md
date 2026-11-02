# Atlas survey sources, credits, and resilience — Issue #26

## Supported image survey

AstroManager v0.4.0 displays **one** configured survey: **DSS2 Color**
(`ivo://CDS/P/DSS2/color`). The viewer is **Aladin Lite 3.8.1**,
loaded as an ES module from the pinned npm package via jsDelivr.

| Resource | Source | Attribution |
| --- | --- | --- |
| HiPS image tiles | `https://skies.esac.esa.int/DSSColor` | Digitized Sky Survey (STScI/NASA); color composition and HiPS processing by CDS/CNRS/Unistra; ESA is the host/mirror |
| HiPS properties | `https://skies.esac.esa.int/DSSColor/properties` | See its `obs_copyright`, `hips_creator`, and `obs_ack` metadata |
| Aladin viewer | `https://cdn.jsdelivr.net/npm/aladin-lite@3.8.1/dist/aladin.min.js` | Aladin Lite, CDS/Université de Strasbourg/CNRS; **do not remove the Aladin logo/link** |
| Local object catalog | `assets/catalog/openngc_20260501.json` | OpenNGC; supplied license `assets/catalog/LICENSE-OpenNGC.txt` (CC BY-SA 4.0) |

No Pan-STARRS, Gaia, 2MASS, or other imagery provider is configured by this version.
Do **not** display credits for surveys that are not used. When additional image
surveys are added, provide attribution that follows the actual chosen base layer.

The permanent attribution line in `sky_atlas_screen.dart` must remain visible
both during normal rendering and on loading/error screens. The Aladin Lite
logo and link inside the embedded viewer must also remain intact.

Reference pages:
- https://skies.esac.esa.int/DSSColor/properties
- https://aladin.cds.unistra.fr/AladinLite/doc/API/
- https://www.npmjs.com/package/aladin-lite
- https://github.com/mattiaverga/OpenNGC

## Failure handling

1. The HTML shell is bundled locally with Flutter; the external JavaScript
   module, its WASM/runtime dependencies and image tiles require network access.
2. The Flutter host applies a **25 s initialization timeout**. Module-load,
   WebGL and initialization failures are sent to the controller through
   `error` packets. Unsupported embedded desktop platforms produce a distinct
   `unsupported` state, with no pointless retry button.
3. When Aladin initializes, the JavaScript bridge reports `ready` and the host
   sends the *current* coordinates, FoV, projection, target markers, camera
   outline and (where selected) horizon. The viewer then reports
   `imageryLoading` until a representative HiPS **image** tile near the current
   pointing has loaded or failed. The tile probe has a **14 s timeout**.
4. `imageryError` shows a visible explanation and Retry action. Retry recreates
   the embedded viewer but **does not recreate the SkyAtlasController** or
   change the selected camera profile, framing center, rotation or saved
   project data. Existing optical framing is restored to the new viewer when
   the bridge next reports `ready`.
5. A new tile probe is scheduled **1.5 s after navigation settles**, so that
   survey failures after changing the field can also be detected.
6. All probe callbacks are guarded by a generation number, preventing late
   success/failure callbacks from a stale probe from changing the current state.
7. Other AstroManager views, local OpenNGC data, target detail screens,
   astronomical calculations and saved projects do **not** depend on the atlas
   image service.

### Scope of tile-failure detection

The representative check loads a standard HEALPix order-0 tile on the same
survey host using an HTML `Image` element. This avoids false-negative CORS
errors from plain `fetch` requests and catches network outages, unavailable
survey servers and root-tile HTTP failures.

**Limit:** Aladin Lite 3.8.1 does not expose a supported public callback for
*every* high-resolution tile. Some isolated missing higher-order tiles can
therefore leave gaps in the viewer without producing a global error banner.
One successful probe does **not** guarantee complete sky coverage or tile
availability at every zoom. An explicit, per-tile signal would require a
supported viewer API or a future revision to the survey loader.

## Supported platforms and smoke testing

| Platform | Expected behavior |
| --- | --- |
| Flutter Web (Chrome and supported WebGL2 browser) | Same-origin iframe and JS `postMessage` transport |
| Android | `webview_flutter` JavaScript channel; online imagery and WebGL2 are required |
| iOS / macOS | WKWebView JavaScript channel; platform runners/signing must be configured separately |
| Windows / Linux native | Embedded viewer unsupported; explicit fallback; use Flutter Web build instead |

Regression tests:

```sh
node --test test/js/atlas_bridge.test.cjs
flutter analyze
flutter test test/features/atlas
flutter test
flutter build web
```

Manual smoke test on **each actual supported platform**:

1. Open Targets → M31 → Sky Atlas and confirm loading indication, DSS2 tiles,
   Aladin logo/link and the permanent credits.
2. Create an imaging profile, change rotation, move the frame and save it.
   Switch between Detail Atlas and Sky Dome and back.
3. Disable the network **before opening** the atlas. Confirm a meaningful
   error within the bounded loading period, with no app crash and with target
   details still accessible via navigation.
4. Re-enable the network and press Retry. Verify the same target, camera
   outline, center and rotation are restored (saved configurations remain saved).
5. Turn off access to `skies.esac.esa.int` while keeping jsDelivr reachable.
   Confirm survey-specific error text after the tile probe times out.
6. Verify a Windows/Linux native run displays an unsupported message without
   trying to instantiate a WebView.

Automated tests use mocked transport and mocked image loads. **They cannot
certify real browser/WebGL2 or platform-specific hardware behavior.** Record
those manual results before closing the milestone.
