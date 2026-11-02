# Issue #31 — AstroManager portable backup v1

## File format

The backup is a **ZIP archive** generated offline with the file extension
`.ambackup` (for example, `AstroManager-2026-11-02.ambackup`). This is a
filename change only: the internal ZIP structure and `formatVersion: 1` remain
unchanged. The restore picker also accepts legacy `.zip` backup files. Backups
are **not encrypted**. The archive contains:

- `manifest.json`: `format: "astromanager-backup"`, `formatVersion: 1`,
  `databaseSchemaVersion: 6`, UTC creation time, the optional theme name,
  a SHA-256 digest of `data.json`, counts by table and image metadata.
- `data.json`: a JSON object mapping table names to arrays of complete rows.
  Supported tables: `app_settings`, `observing_locations`, `equipment_items`,
  `optical_profiles`, `imaging_projects`, `imaging_project_targets`,
  `observation_sessions`, `observation_session_images`.
- `images/<id>.bin`: optional original image contents. Manifest entries include
  ID, path, byte length, and SHA-256 digest. Attachments without image bytes
  are **not** exported as metadata, preventing broken restored references.

User preferences and observation plans from `app_settings` are included.
The theme stored in SharedPreferences is written to the manifest and reapplied
on successful restoration. The built-in OpenNGC catalog, forecast caches,
and external/temporary device data are not backed up. Project target IDs still
refer to the same bundled catalog on the destination installation.

## Restore rules

1. A ZIP must pass validation (archive, manifest version, table counts, file
   list, checksums, column names and size limits) before any data is written.
2. **Merge** uses ordinary SQL `INSERT`, never `INSERT OR REPLACE` or an upsert.
   Existing IDs or keys cause an error. The entire SQLite transaction rolls
   back: a conflict cannot produce a partial import.
3. **Replace all** requires an additional destructive-action confirmation in
   the UI. Existing user tables are cleared and restored in a single SQLite
   transaction. Schema tables and the built-in celestial catalog are retained.
4. Images are staged with new randomly generated, opaque storage keys and
   their original attachment metadata IDs. On transaction failure the new
   image files are removed. On success old detached files are cleaned up on a
   best-effort basis. Image contents are **never** embedded into SQLite.
5. Referential integrity is checked with `PRAGMA foreign_key_check` before
   commit. SQLite constraints additionally guard malformed rows.
6. UTC instants, recorded UTC offsets, IANA zone IDs, equipment name snapshots,
   project IDs, night-plan links and all other persisted fields are preserved.

Current implementation accepts only format version 1 / database schema 6.
Other versions are safely rejected rather than guessed or silently converted.
Maximum supported archive and decoded payload: 256 MiB; maximum image: 20 MiB.

## Manual verification

Run `flutter pub get`, `dart format lib test`, `flutter analyze`, and
`flutter test`. Verify Settings → Backup & restore on Android, iOS and Web:
export with and without image attachments; import to an empty installation;
merge a backup into an existing installation (duplicate IDs must be rejected);
replace an existing installation using both explicit confirmations; finally
restart the app and inspect projects, sessions, night plans and attachment bytes.

For production, keep backup files in a protected location. Password-based
backup encryption and selective merge/ID remapping are separate enhancements.
