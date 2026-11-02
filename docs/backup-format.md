# Portable Backup Format (`.ambackup`)

AstroManager's data export is an **offline-created ZIP container** using the extension `.ambackup`. This document describes **format version 1**, as implemented with database schema version **6** in the current source. The `.ambackup` extension does not imply compression beyond ZIP or any encryption. The file picker also accepts earlier `.zip` backups using the same supported format.

## Archive layout

```text
AstroManager-YYYY-MM-DD.ambackup
├── manifest.json
├── data.json
└── images/
    └── <opaque-id>.bin      # only if image attachments were included
```

- `manifest.json` identifies `format: "astromanager-backup"`, `formatVersion: 1`, `databaseSchemaVersion: 6`, UTC export time, optional theme, per-table row counts, the SHA-256 digest of `data.json`, and optional image metadata (archive path, length and SHA-256 digest).
- `data.json` is structured JSON with table names mapped to complete row arrays. It includes `app_settings`, `observing_locations`, `equipment_items`, `optical_profiles`, `imaging_projects`, `imaging_project_targets`, `observation_sessions` and `observation_session_images` when images are included.
- `images/` contains detached image binaries. If the user excludes images, the exporter omits image attachment rows rather than creating broken references. Image bytes are never stored in SQLite.

Versioned `app_settings` entries include saved night plans, mosaic configurations, opportunity-alert rules and notification deduplication history. The manifest also preserves the selected theme. The bundled OpenNGC catalog, external caches, temporary files and downloaded sky imagery are not included.

## Validation and restoration

Before writing, the importer checks ZIP structure, supported format/schema versions, checksums, filenames, size limits, table counts, required columns and foreign-key consistency. Bad or unsupported archives are rejected with an error. It does not guess at unsupported schema conversions.

Two user-visible modes are supported:

| Mode | Behavior |
| --- | --- |
| **Merge (no overwrites)** | Uses ordinary inserts; conflicting IDs/keys abort the entire transaction without modifying pre-existing records. It does not silently remap IDs. |
| **Replace all data** | Requires an additional destructive-action confirmation; saved user rows are replaced transactionally. The built-in catalog and schema are not deleted. |

Image payloads are staged under new opaque keys during restore. A failed database transaction removes newly staged files; after success obsolete detached image files are cleaned on a best-effort basis. Foreign keys are checked before commit. UTC timestamps, site zones/offsets and historical equipment name snapshots remain part of the records.

The implemented limits are **256 MiB** per supported archive/decoded payload and **20 MiB** per attachment. Confirm these limits in code before changing export behavior or advertising compatibility with a new format.

## Security and compatibility

- Backups are **not password protected or encrypted**; store them in a private location.
- Importing a backup is not a synchronization mechanism and does not resolve record conflicts automatically.
- A future format/schema revision needs explicit migration support and round-trip tests; never reinterpret arbitrary ZIP files as trusted input.
- Use backups before reinstalling the app or clearing a browser's site data. Local data is not automatically transferred across devices.

## Regression checks

Run `flutter analyze` and `flutter test` and manually verify export/restore (with and without attachments) on the desired platform. Test importing into an empty installation, merging conflicting IDs, replacing existing data after confirmation and reopening the application after restore. See [Architecture and development](architecture.md) for the broader test workflow.
