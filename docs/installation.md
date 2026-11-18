# Installation and platform support

AstroManager v1.0.0 uses local storage. Back up an existing installation before upgrading. Open **Settings → Backup & restore → Export backup** to export a portable `.ambackup` file, optionally including session images. [English guide](user-guide.md) · [Deutsche Anleitung](user-guide.de.md)

## Choose a platform

| Platform | Requirements | Install or open |
| --- | --- | --- |
| Android | Android 7.0 (API 24) or newer | Download the signed `AstroManager-1.0.0-android.apk` from GitHub Releases. Open it on the device and allow installation from the app you used to open the file if Android prompts. To update an existing installation, use a build signed with the same release key. |
| iOS | iOS 15 or newer | Install through the distribution channel linked from the release page. Device installation requires a signed and provisioned build. |
| Web | A desktop or mobile browser with WebAssembly. Sky imagery also requires WebGL. | Open the hosted URL linked on the release page. To self-host, extract the Web ZIP and serve its contents from an HTTP server. Use HTTPS for a public deployment and configure `.wasm` files with the MIME type `application/wasm`. |
| Windows | x64 on Windows 11 and the Microsoft Visual C++ x64 runtime | Extract the entire `AstroManager-1.0.0-windows-x64.zip` to a local folder. Run `astromanager.exe` there. Keep its DLLs and `data` folder together. |
| macOS | macOS 12 or newer | Install the signed macOS package listed for your hardware on the release page. |

The [GitHub release page](https://github.com/CodefrogCF/AstroManager/releases)
lists available packages and their SHA-256 checksums. Follow the
[Microsoft Visual C++ redistributable instructions](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
for the Windows runtime.

## Features by platform

- **Sky Atlas.** Interactive imagery is available on Web and on compatible
  Android, iOS and macOS WebViews. On Windows, open AstroManager Web to use the
  embedded atlas. Target coordinates, planning and framing calculations are
  available locally.
- **Opportunity alerts.** Android and iOS can show local notifications with
  permission. Forecasts are evaluated on launch, foreground return or **Check
  now**. Longer-term plans and rankings are available on all target platforms.
- **Terrain.** New profiles depend on the public elevation provider and dataset
  coverage. Browser requests may be blocked by the provider. A native app can
  request a profile for its own local cache.
- **Offline.** Installed apps can open local catalogs and records, calculate
  visibility and read saved forecasts and terrain. Web startup depends on the
  deployment origin and browser caching. Use the same browser profile and origin
  to access saved Web records.

## Deutsch

- **Android ab Version 7.** Die signierte APK aus den GitHub-Releases auf dem
  Gerät öffnen und die Installation bei Bedarf für die verwendete App erlauben.
  Bei einem Update muss die Signatur zur vorhandenen Installation passen.
- **Windows 11 (x64).** Das ZIP vollständig entpacken, bei Bedarf die
  Microsoft Visual C++ Redistributable (x64) installieren und
  `astromanager.exe` aus dem entpackten Ordner öffnen.
- **Web.** Die verlinkte Web-App in einem Browser mit WebAssembly öffnen. Für
  Atlasbilder muss auch WebGL verfügbar sein. Für eigenes Hosting das Web-ZIP
  auf einem Webserver bereitstellen. Öffentliche Installationen per HTTPS
  ausliefern und für `.wasm` den MIME-Typ `application/wasm` setzen.
- **iOS ab 15 und macOS ab 12.** Die auf der Release-Seite verlinkte
  Distribution für das jeweilige Gerät verwenden.

Vor einem Update persönliche Daten unter **Einstellungen → Sicherung und
Wiederherstellung** als `.ambackup` sichern. Den eingebetteten Atlas unter
Windows über die Web-App öffnen. Benachrichtigungen sind auf Android und iOS
verfügbar. Die [deutsche Anleitung](user-guide.de.md) beschreibt den Ablauf
für eine Beobachtungsnacht.
