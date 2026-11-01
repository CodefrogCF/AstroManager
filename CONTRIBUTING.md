# Contributing to AstroManager

Thank you for your interest in contributing to AstroManager.

AstroManager is an open-source, offline-first astrophotography
planning application built with Flutter and Dart.

## Development Requirements

- Flutter SDK (see `.fvmrc`)
- Dart SDK included with Flutter
- Git
- Compatible IDE, such as VS Code or Android Studio
- Platform-specific development tools

Windows desktop development requires the appropriate
Visual Studio C++ tooling.

Apple platform development requires macOS and Xcode.

## Getting Started

Clone the repository:

    git clone https://github.com/CodefrogCF/AstroManager.git
    cd AstroManager

Install dependencies:

    flutter pub get

Generate source files:

    dart run build_runner build

Check your environment:

    flutter doctor -v

Run the application:

    flutter run -d chrome

## Project Architecture

AstroManager uses feature-first architecture with four layers:

- Presentation
- Application
- Domain
- Data

For architectural details, see:

[Architecture Documentation](docs/architecture.md)

## Branch Naming

Use descriptive branches:

- `feature/<issue-number>-<description>`
- `fix/<issue-number>-<description>`
- `refactor/<description>`
- `docs/<description>`
- `chore/<description>`

Example:

    feature/8-observing-locations

## Coding Standards

- Follow effective Dart conventions.
- Use `dart format`.
- Keep business logic outside Flutter widgets.
- Prefer strongly typed domain models.
- Access persistence through repository abstractions.
- Use Riverpod for dependency injection and application state.
- Avoid introducing unnecessary dependencies.
- Document non-obvious astronomical algorithms.

## Testing

Every functional change should include appropriate tests.

Run:

    dart format lib test
    flutter analyze
    flutter test

See [Testing Guidelines](docs/testing.md) for details.

## Database Changes

When modifying the Drift database:

1. Update the table definitions.
2. Increment the schema version if needed.
3. Regenerate Drift classes.
4. Create the required migration.
5. Add migration tests.
6. Verify existing user data remains intact.

## External Services

External providers must:
- Use clear interfaces.
- Handle unavailable data.
- Respect rate limits and licensing.
- Document required attribution.
- Avoid unnecessary collection of user data.

## Pull Requests

Before opening a pull request:

1. Link the relevant GitHub issue.
2. Describe the implementation.
3. Include tests for changed behavior.
4. Update documentation where required.
5. Run local quality checks.
6. Ensure GitHub Actions checks pass.

Prefer small, focused pull requests.

## Commit Messages

Use concise, descriptive commit messages.

Examples:

    feat: implement observing location management
    fix: correct target visibility calculation
    test: add lunar ephemeris reference cases
    docs: update architecture documentation
    refactor: separate weather provider interfaces
    chore: update CI configuration

## Privacy and Security

Do not commit:
- API keys
- Credentials
- Private user data
- Precise personal location information
- Local environment files containing secrets

Report security-sensitive issues privately when possible.

## Licensing

Contributions are subject to the license selected for
the AstroManager repository.