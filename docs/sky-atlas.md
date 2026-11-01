# Aladin Lite Sky Atlas – AstroManager #22

## Architecture

The atlas is a JavaScript-based, **online** astronomical HiPS survey viewer.
The OpenNGC catalogue and astronomical calculations remain offline-capable;
CDS imagery is not included with the app and requires a network connection.

- `SkyAtlasController`: state and validated, versioned JSON transport protocol.
- `SkyAtlasHost`: conditional imports isolate Flutter Web and native WebView.
- `assets/atlas/atlas.html`: local HTML shell using Aladin Lite **v3.8.1**.
- `assets/atlas/atlas_bridge.js`: common browser/native JS bridge.
- `/targets/atlas`: nested target route; target details and ranked discovery
  recommendations can navigate with a `CelestialObject` as route `extra`.

Supported embedded platforms: **Flutter Web, Android, iOS, macOS**.
The current repository contains Android, Web and Windows runner scaffolding,
**not** iOS or macOS: to build on Apple hardware, generate those platform
runners with `flutter create --platforms=ios,macos .`, configure signing and
then test WKWebView. Android release requires `INTERNET` in its **main** manifest,
which is included by this patch. HTTPS network access is used exclusively for
external survey resources.

Windows and Linux are explicitly unsupported for embedded display by the
endorsed `webview_flutter` plugin; users can use the AstroManager Web build
in a normal browser. Do not call `WebViewController()` on those platforms.

## Communications

Versioned JSON protocol: `{protocol:"astromanager.aladin", version:1, type:...}`.
Flutter sends a `state` packet with `ra`, `dec`, `fov`, up to 250 markers and circular overlays.
JS sends `ready`, `error` and `viewChanged` packets.

On Web: `HtmlElementView` hosts an iframe with the bundled HTML asset.
Messages are sent with `postMessage`; the parent accepts messages **only**
from the iframe window and matching origin. No global JS function is
exposed on the parent Flutter application.

On Android/iOS/macOS: `WebViewController.loadFlutterAsset` loads the same
HTML asset. A `AstroManagerBridge` JavaScript channel reports messages to Dart;
Dart passes state commands via `runJavaScript`. Errors on loading and JS
initialization result in a visible retry prompt. At startup a 25-second timeout
protects against hanging indefinitely. Interaction-originating `viewChanged`
events update the Flutter state without replaying themselves back into JS.

Coordinates are **ICRS/J2000** in decimal degrees; longitude/latitude are not
used to center the map. FoV is the **Aladin FoV in degrees**, not camera framing.
Actual camera framing overlays are reserved for later v0.4.0 issues.

## Assets and hosting

Both `assets/atlas/atlas.html` and `assets/atlas/atlas_bridge.js` are
registered Flutter assets. For Flutter Web, the page is served from the same
origin as Flutter at `assets/assets/atlas/atlas.html`, resolved against the
Flutter `<base href>` for deployments under a subpath. For native WebView,
`loadFlutterAsset('assets/atlas/atlas.html')` loads the local document. Aladin
JS is requested over HTTPS from CDS, and HiPS imagery is fetched independently.

Aladin Lite 3.8.1 is selected as a pinned stable release in the HTML tag.
Changing that version should be a deliberate update and accompanied by a
cross-platform visual smoke test.

## Network, security, licensing

The atlas must not claim survey imagery is available offline. Loading the
atlas JavaScript or HiPS tiles may fail during network outages; the Flutter
app and its offline catalog remain usable. Individual tile failures may
result in gaps even if the JS initialization succeeded.

Popup labels are escaped on the JavaScript side. Command packets and numerical
ranges are validated before use. The Web iframe requires same-origin traffic.
The Aladin logo and link must remain visible, as requested by CDS.
Aladin Lite is LGPL-3.0-or-later; HiPS surveys have their own attribution and
rights. Do not remove CDS/survey attribution.

References:
- https://cds-astro.github.io/aladin-lite/
- https://cds-astro.github.io/aladin-lite/Aladin.html
- https://pub.dev/packages/webview_flutter
- https://docs.flutter.dev/platform-integration/web/web-content-in-flutter

## Tests

```sh
flutter pub get

dart format lib test
flutter analyze
flutter test test/features/atlas
node --test test/js/atlas_bridge.test.cjs
flutter test
flutter build web
```

Manual smoke tests (internet required): launch Chrome, open Targets > Sky atlas,
confirm DSS2 tiles and CDS logo, zoom, drag, navigate back and return. Select
M31 from the catalog and a ranked recommendation and confirm centered RA/Dec,
marker and FoV. Test Android WebView and iOS/macOS WKWebView on devices with
WebGL2, and turn off network to verify error messaging.

When using the CI `--enforce-lockfile` flag, commit the updated `pubspec.lock`
after the first local `flutter pub get`.

The initial overlay highlights a catalogued object using its major-axis radius as an approximation. It is **not** an optical camera-framing rectangle.
