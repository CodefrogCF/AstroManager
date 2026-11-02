# Contributing to AstroManager

AstroManager is an offline-first Flutter/Dart astrophotography planner. Contributions should preserve user data, keep scientific limitations explicit and work without external services wherever practicable.

## Development setup

Use the Flutter SDK pinned in [`.fvmrc`](.fvmrc), Git and the build tools required for your target platform (Visual Studio C++ tools for Windows; Xcode on macOS for iOS). The primary commands are:

```bash
flutter pub get
flutter run -d chrome
dart format lib test
flutter analyze
flutter test --concurrency=2
node --test test/js/atlas_bridge.test.cjs
```

Run `dart run build_runner build --delete-conflicting-outputs` only when generated Drift models need rebuilding. Node.js is required for the JavaScript atlas test. The CI configuration is in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Code and tests

- Follow Dart formatting and analyzer guidance; use Riverpod providers and repositories rather than accessing storage from presentation widgets.
- Isolate astronomical calculations from network and UI dependencies. Record coordinate frames, epochs, units and numerical tolerances in code/tests.
- For new external providers, handle source restrictions, attribution, stale/absent data and network failure. Do not label estimates as measurements.
- Use fake providers and isolated SQLite executors in unit/widget tests. Cover invalid inputs, migrations, time zones/DST, missing data and permission denial.
- For a Drift schema change, increment the schema version, regenerate code, implement a lossless migration and add a migration test.
- Validate user-facing changes on actual platforms. Automated test success does not establish notification delivery, WebGL compatibility or real DEM/forecast accuracy.

See [Architecture and development](docs/architecture.md), [Data sources and limitations](docs/data-sources.md) and [Backup format](docs/backup-format.md).

## Pull requests

Submit focused changes with a concise rationale, tests and documentation updates when behavior or data sources change. Run the relevant checks first. Do not commit credentials, private locations, user databases, personal backups, proprietary datasets or generated device secrets.

## Licensing

Keep third-party notices and attribution with their applicable assets and algorithms. The source archive used for this documentation update has **no top-level AstroManager software LICENSE**; project-wide contribution/redistribution terms must be established by the repository owner rather than inferred from bundled third-party notices.
