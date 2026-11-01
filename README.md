# astromanager

## Development

AstroManager is built with Flutter and Dart.

### Requirements

- Flutter SDK matching `.fvmrc`
- Dart SDK
- Git
- Platform-specific build tools

### Getting Started

Clone the repository:

    git clone https://github.com/CodefrogCF/AstroManager.git
    cd AstroManager

Install dependencies:

    flutter pub get

Generate Drift classes:

    dart run build_runner build --delete-conflicting-outputs

Start the application:

    flutter run -d chrome

### Quality Checks

    dart format lib test
    flutter analyze
    flutter test

### Supported Development Targets

- Android
- Web
- Windows

iOS and macOS support is planned and will be validated
when their respective platform integrations are ready.

## Documentation

- [Development Roadmap](ROADMAP.md)
- [Architecture](docs/architecture.md)
- [Testing Guidelines](docs/testing.md)
- [Contributing](CONTRIBUTING.md)

## Continuous Integration

GitHub Actions automatically verifies code formatting,
static analysis, automated tests, generated Drift code,
and supported platform builds.

[View CI Workflow](.github/workflows/ci.yml)