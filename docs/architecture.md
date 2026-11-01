# AstroManager Architecture

## Overview

AstroManager follows a feature-first architecture with
separated presentation, application, domain, and data layers.

The application is designed for offline-first operation,
testability, and cross-platform compatibility.

## Project Structure

- `app/` - Application bootstrap and global configuration
- `core/` - Shared infrastructure and cross-cutting concerns
- `features/` - Independent application features
- `shared/` - Reusable presentation components

## Feature Layers

### Presentation

Contains Flutter widgets, screens, and UI-specific components.

Responsibilities:
- Display application state
- Handle user interactions
- Observe application providers

### Application

Coordinates feature workflows and exposes state.

Responsibilities:
- Riverpod providers and controllers
- Application-specific use cases
- Orchestration of domain operations

### Domain

Contains framework-independent business definitions.

Responsibilities:
- Domain models
- Repository interfaces
- Business rules
- Astronomical calculations

### Data

Implements persistence and external integrations.

Responsibilities:
- Repository implementations
- Database adapters
- REST API clients
- Local files and cached data

## Dependency Rules

1. Domain must not depend on Flutter, Riverpod, or data implementations.
2. Data may depend on domain interfaces and models.
3. Application coordinates domain and repository operations.
4. Presentation consumes application state.
5. UI widgets must not access storage or HTTP clients directly.
6. Cross-feature interactions should use public interfaces or services.

## Dependency Injection

Riverpod manages dependencies.

Providers should be declared at the top level and remain
close to their respective feature modules.

Repository implementations must be replaceable through
provider overrides during testing.

## Asynchronous Operations

- Use Future for one-time asynchronous operations.
- Use Stream for continuously changing data.
- Explicitly represent loading, data, and error states.
- Avoid hiding unexpected failures.
- Do not expose provider-specific types in domain models.

## Error Handling

Data adapters translate relevant external exceptions
into application-level failures.

Expected failures should be handled explicitly.

Unexpected programming errors should remain observable
during development and testing.

Errors must not expose sensitive location data,
credentials, or other private information.

## Offline-First Principles

- Core astronomical calculations run locally.
- User-owned data is stored locally by default.
- Network services are optional where feasible.
- Cached external data includes freshness metadata.
- Offline and stale-data states must be distinguishable.

## Testing

- Unit tests cover domain logic.
- Provider tests verify dependency injection.
- Repository tests verify data contracts.
- Widget tests verify presentation behavior.
- Integration tests verify critical workflows.

## Future Architecture Extensions

- Drift/SQLite persistence
- Astronomical calculation services
- Weather provider abstraction
- Local celestial object catalog
- Target recommendation engine
- Sky atlas integration
- Optional remote processing services