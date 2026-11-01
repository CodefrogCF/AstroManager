# AstroManager Testing Guidelines

## Overview

AstroManager uses automated testing to ensure reliability,
cross-platform compatibility, and predictable astronomical calculations.

All new features should include appropriate automated tests.

## Testing Levels

### Unit Tests

Used for:
- Astronomical calculations
- Domain models
- Validation rules
- Suitability scoring
- Serialization
- Pure business logic

Unit tests should be deterministic and independent of network services.

### Repository Tests

Used for:
- Drift database repositories
- CRUD operations
- Persistence
- Database migrations
- Import and export

Use in-memory SQLite for isolated repository tests.

Use temporary file-based SQLite databases when testing persistence
across database restarts.

### Provider Tests

Used for:
- Riverpod dependency injection
- Application state
- Loading and error states
- Repository overrides
- Asynchronous operations

External dependencies should be replaceable with fake or mock
implementations.

### Widget Tests

Used for:
- Navigation
- Settings
- Theme switching
- Forms
- Validation messages
- Error and empty states

Tests must not depend on an active network connection or real
production data.

### Integration Tests

Used for:
- Critical cross-feature workflows
- Platform-specific behavior
- Database upgrades
- External service integration

Integration tests may require additional platform setup.

## Test Organization

Tests should mirror the corresponding source feature.

Examples:

- lib/features/settings/ -> test/features/settings/
- lib/features/targets/ -> test/features/targets/
- lib/core/database/ -> test/core/database/

Shared test fixtures and fake repositories belong in `test/support/`.

## Naming Conventions

- Test files end with `_test.dart`.
- Test names describe expected behavior.
- Tests should use clear Arrange, Act, Assert structure.
- Group related tests with `group()`.

## Test Independence

Tests must:
- Avoid relying on execution order.
- Avoid real network services where practical.
- Avoid modifying production data.
- Clean up resources after execution.
- Use fixed dates and coordinates for astronomical reference tests.

## Astronomical Calculation Standards

All future astronomical calculations must be compared against
trusted reference values.

Tests should cover:
- Coordinate systems and epochs
- Time zones and daylight-saving changes
- Midnight boundaries
- Solar and lunar events
- Objects below the horizon
- Circumpolar objects
- Numerical precision and tolerances

Reference values and acceptable tolerances must be documented.

## Database Testing

Schema migrations must preserve existing data.

Whenever the database schema changes:
1. Increase the schema version.
2. Regenerate Drift code.
3. Generate or update migration steps.
4. Add or update migration tests.
5. Validate data integrity.

Do not silently delete existing user data during upgrades.

## Local Quality Checks

Before committing:

    dart format lib test
    flutter analyze
    flutter test

Before opening a pull request:

    dart format --output=none --set-exit-if-changed lib test
    flutter analyze
    flutter test
    flutter build web

## CI Requirements

Pull requests must pass:
- Formatting
- Static analysis
- Automated tests
- Drift generated-code verification
- Flutter Web build

Main branch builds additionally validate Android and Windows.

## Definition of Done

- [ ] Implementation meets issue acceptance criteria.
- [ ] Appropriate tests have been added or updated.
- [ ] Code formatting passes.
- [ ] Static analysis passes.
- [ ] Automated tests pass.
- [ ] Relevant platforms have been manually verified.
- [ ] Documentation is updated.
- [ ] CI checks pass.

## Code Coverage

Code coverage may be generated with:

    flutter test --coverage

Coverage is a diagnostic metric, not a substitute for meaningful tests.

No global minimum coverage threshold is enforced initially.