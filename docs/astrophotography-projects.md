# Offline imaging projects – v0.5.0 / Issue #27

## Storage

Database schema version **5** creates `imaging_projects` and
`imaging_project_targets`. Metadata and target links are written in one Drift
transaction. Deleting a project cascades to its link rows. Catalog target IDs
and optical-profile IDs are *intentionally* not foreign keys: removing or
changing an equipment setup or updating the catalog cannot silently delete a
project. The UI displays the retained ID when an associated record is missing.

Existing `projects.planned.v1` JSON records from Issue #25 are imported from
`app_settings` into the tables on first repository access. The source JSON
is deleted only after the entire import transaction commits. If parsing or
writing fails, the original data is retained. Upserts prevent duplicate
projects on subsequent access. New project operations do not write legacy JSON.

## Fields / lifecycle

- ID, title, description, freeform notes and imaging goal.
- Project status: Planned, In progress, Completed, Archived.
- Multiple local catalog target IDs, optional optical profile ID.
- Planned integration time as nonnegative integer seconds (UI: minutes).
- Optional observing date, location ID, UTC window start/end.
- UTC creation and modification timestamps.

Archive is reversible; deletion is explicit and requires confirmation.
Archived projects are hidden in the default Active filter and visible under
Archived. Projects can be created before any target is assigned and completed
through the editor. Session logs and actual integration totals belong to later
issues in v0.5.0.

## Migration and testing

The additive v4→v5 migration uses SQL `CREATE TABLE IF NOT EXISTS` alongside
existing generated v1–v4 Drift tables; no generated DAO code is required.
The schema exports in `drift_schemas/` remain the older snapshots until the
next `dart run drift_dev schema dump` maintenance step; current regression
coverage uses direct PRAGMA/SQLite checks for v5.

Run:

```sh
dart format lib test
flutter analyze
flutter test test/features/projects
flutter test
```

Also verify offline creation, app restart, project edit, archiving and restore,
confirmed deletion, target navigation, and a project whose equipment profile
has since been removed. The same repository is used by the target detail
screen's “Save as project” action.
