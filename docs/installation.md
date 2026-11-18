# Installation and platform support

AstroManager v1.0.0 uses local storage. Back up an existing installation before upgrading. Open **Settings → Backup & restore → Export backup** to export a portable `.ambackup` file, optionally including session images. [English guide](user-guide.md) · [Deutsche Anleitung](user-guide.de.md)

## Choose a platform

| Platform | Requirements | Install or open |
| --- | --- | --- |
| Android | Android 7.0 (API 24) or newer | Download the signed `AstroManager-1.0.0-android.apk` from GitHub Releases. Open it on the device and allow installation from the app you used to open the file if Android prompts. To update an existing installation, use a build signed with the same release key. |
| iOS | iOS 15 or newer, plus a Mac with Xcode for local builds | [Build and install on your own iPhone](#build-for-your-iphone) using your Apple Account in Xcode. |
| Web | A desktop or mobile browser with WebAssembly. Sky imagery also requires WebGL. | Open the hosted URL linked on the release page. To self-host, extract the Web ZIP and serve its contents from an HTTP server. Use HTTPS for a public deployment and configure `.wasm` files with the MIME type `application/wasm`. |
| Windows | x64 on Windows 11 and the Microsoft Visual C++ x64 runtime | Extract the entire `AstroManager-1.0.0-windows-x64.zip` to a local folder. Run `astromanager.exe` there. Keep its DLLs and `data` folder together. |
| macOS | macOS 12 or newer | Download the macOS ZIP for your hardware if listed under the release assets. Extract it, move `AstroManager.app` to Applications and open it. See [first launch on macOS](#first-launch-on-macos) for packages marked `unnotarized`. |

The [GitHub release page](https://github.com/CodefrogCF/AstroManager/releases)
lists available packages and their SHA-256 checksums. Follow the
[Microsoft Visual C++ redistributable instructions](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
for the Windows runtime.

## First launch on macOS

For a ZIP marked `unnotarized`, verify the SHA-256 checksum from the release
page before extracting it. Gatekeeper may block the extracted app on the
first launch. If you trust the download and choose to open it, try opening
the app and then look under **System Settings → Privacy & Security** for
**Open Anyway**. Managed device policies can restrict this option.
[Apple's instructions for opening apps](https://support.apple.com/en-us/102445)

## Build for your iPhone

Use a Mac with Xcode and iOS platform support, Git and the Flutter version
in [`.fvmrc`](../.fvmrc). Follow the Flutter iOS setup guide for toolchain
setup, including CocoaPods if needed. A free Apple Account in Xcode provides
a Personal Team for installing on your own iPhone.
[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) ·
[Apple Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account/)

1. Clone the current default branch. The iOS location permission fix was
   made after the `v1.0.0` tag.

   ```sh
   git clone https://github.com/CodefrogCF/AstroManager.git
   cd AstroManager
   flutter pub get --enforce-lockfile
   open ios/Runner.xcworkspace
   ```

2. Sign in under **Xcode → Settings → Accounts**. Select the **Runner**
   target and open **Signing & Capabilities**. Enable **Automatically manage
   signing** and select your Personal Team. If Xcode rejects the bundle
   identifier, use a unique one for your team, such as
   `com.yourname.astromanager` with your own name in place of `yourname`.
3. Connect and unlock the iPhone. Confirm **Trust This Computer** if asked.
   On iOS 16 and later, enable **Settings → Privacy & Security → Developer
   Mode** and follow the restart prompts.
4. List the connected devices and replace `IPHONE_DEVICE_ID` with the ID
   shown for your physical iPhone.

   ```sh
   flutter devices
   flutter run --release --no-pub -d "IPHONE_DEVICE_ID"
   ```

5. If iOS reports an untrusted developer, open **Settings → General → VPN &
   Device Management**, select your developer team and follow the trust
   prompt. Then open AstroManager on the iPhone.

Personal Team provisioning expires after seven days. Build and install the
app again when the profile expires. TestFlight and App Store distribution
require an Apple Developer Program membership.
[Apple's account and distribution overview](https://developer.apple.com/help/account/basics/about-your-developer-account/)

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
- **iOS ab 15.** [AstroManager selbst fürs iPhone bauen](#ios-selbst-bauen).
- **macOS ab 12.** Das passende macOS-ZIP aus den Release-Assets laden,
  sofern es dort angeboten wird. ZIP entpacken, `AstroManager.app` nach
  **Programme** verschieben und öffnen. Bei einem als `unnotarized`
  gekennzeichneten ZIP zuerst die SHA-256-Prüfsumme abgleichen. Falls
  Gatekeeper den Start blockiert und du der Quelle vertraust, kannst du nach
  dem Startversuch unter **Systemeinstellungen → Datenschutz & Sicherheit**
  nach **Dennoch öffnen** suchen. Auf verwalteten Macs kann diese Option
  gesperrt sein. [Apple-Anleitung zum Öffnen von Apps](https://support.apple.com/de-de/102445)

Vor einem Update persönliche Daten unter **Einstellungen → Sicherung und
Wiederherstellung** als `.ambackup` sichern. Den eingebetteten Atlas unter
Windows über die Web-App öffnen. Benachrichtigungen sind auf Android und iOS
verfügbar. Die [deutsche Anleitung](user-guide.de.md) beschreibt den Ablauf
für eine Beobachtungsnacht.

### iOS selbst bauen

Du brauchst einen Mac mit Xcode und iOS-Plattformunterstützung, Git und die
Flutter-Version aus [`.fvmrc`](../.fvmrc). Die Flutter-Anleitung beschreibt
die Einrichtung einschließlich CocoaPods bei Bedarf. Ein kostenloser
Apple Account reicht für das **Personal Team** in Xcode und die Installation
auf deinem eigenen iPhone.
[Flutter-Einrichtung für iOS](https://docs.flutter.dev/platform-integration/ios/setup) ·
[Apple-Dokumentation zum Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account/)

1. Klone den aktuellen Standardbranch. Der iOS-Standortfix entstand nach
   dem Tag `v1.0.0`.

   ```sh
   git clone https://github.com/CodefrogCF/AstroManager.git
   cd AstroManager
   flutter pub get --enforce-lockfile
   open ios/Runner.xcworkspace
   ```

2. Melde dich unter **Xcode → Settings → Accounts** an. Öffne beim Ziel
   **Runner** den Reiter **Signing & Capabilities**, aktiviere
   **Automatically manage signing** und wähle dein Personal Team. Falls
   Xcode die Bundle-ID ablehnt, verwende eine eindeutige ID für dein Team,
   zum Beispiel `com.deinname.astromanager` mit deinem eigenen Namen.
3. Verbinde und entsperre dein iPhone und bestätige bei Bedarf die
   Vertrauensabfrage. Aktiviere ab iOS 16 unter **Einstellungen → Datenschutz
   & Sicherheit → Entwicklermodus** den Entwicklermodus und folge den
   Hinweisen zum Neustart.
4. Zeige die verbundenen Geräte an und ersetze `IPHONE_GERAETE_ID` durch die
   ID deines iPhones.

   ```sh
   flutter devices
   flutter run --release --no-pub -d "IPHONE_GERAETE_ID"
   ```

5. Falls iOS dem Entwicklungsteam noch nicht vertraut, öffne
   **Einstellungen → Allgemein → VPN und Geräteverwaltung**, wähle dein
   Team und bestätige die Vertrauensabfrage. Öffne dann AstroManager.

Das Profil eines Personal Teams läuft nach sieben Tagen ab. Baue und
installiere die App danach erneut. Für TestFlight und den App Store ist eine
Mitgliedschaft im Apple Developer Program erforderlich.
[Apple-Übersicht zu Accounts und Verteilung](https://developer.apple.com/help/account/basics/about-your-developer-account/)
