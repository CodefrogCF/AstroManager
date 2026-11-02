# Issue #28 — Observation Session Logging

## Schema v6

The `observation_sessions` table contains one dated exposure sequence per
project. It has a cascading project FK, an index on `(project_id,
started_at_utc)` and nullable identifiers **plus name snapshots** for observing
locations, cameras, optics and mounts. Snapshots are deliberately independent
of equipment records so history survives equipment edits/deletion.

`started_at_utc` is an ISO-8601 UTC instant. The IANA `time_zone_id` and the
offset at that instant (`utc_offset_minutes`) are stored together. The UI
records the wall-clock time in the selected observing location's time zone,
falling back to UTC when no location is selected. Skipped spring-forward times
are rejected; the initial occurrence is chosen for ambiguous fall-back times.
The actual UTC instant and offset are preserved to disambiguate the record.

The counted exposure duration is `exposure_seconds * frame_count` and the
usable integration duration is `exposure_seconds * accepted_frames`. A frame
can be unclassified: accepted + rejected must be <= total. ISO and gain are
mutually exclusive. Aperture f-number, binning, filter and camera temperature
are optional parameters.

## Image attachments

`observation_session_images` stores only file metadata and a generated opaque
storage key. Native platforms store binary data in the app's support directory
under `session_images/`; web stores binary data in a separate IndexedDB object
store, `astromanager-session-attachments`. Up to 20 MiB per image (JPEG, PNG,
WebP, GIF, HEIC) is supported. Images can be added, previewed and removed from
each session in its parent project's detail view. Session deletion also removes
its files; project deletion removes cascading session files and metadata.

**Future backup work:** Full portable export/restore in the milestone must copy
these detached image payloads, not just the SQLite database. A browser's site
data or an app's local app directory can be removed independently by the OS.

## Testing

Run `flutter pub get`, `dart format lib test`, `flutter analyze`, then
`flutter test`. Tests cover domain validation, UTC/DST, CRUD and multiple
sessions per project, historical equipment snapshots, detached attachment
storage, persistence after reopening SQLite and v5→v6 migration.
