# Issue #36 — Observation opportunity notifications

## Behavior

- Opt-in, default **disabled**. Rules select an OpenNGC catalog target and saved observing location, minimum suitability score (0–100) and continuous observing duration (15–1440 min).
- Settings → Observation opportunity alerts → **Enable** requests Android/iOS permission explicitly. Permission is **not** requested at app startup.
- The app evaluates the current and next observing night when it launches, resumes, or **Check now** is pressed. A night means local 12:00 until the following local 12:00, with timezone-aware UTC boundaries.
- Every assessment calls `ObservationWindowRecommendation.forObservingNight` and the existing `WeatherForecastService`, not a duplicate heuristic. Only a **complete, current weather window** above both thresholds may notify; no alerts on stale/missing forecasts. The engine may still mark other factors provisional; its score and constraints are preserved.
- A sent alert is recorded under `observation.alerts.v1` in `app_settings` using rule ID + UTC observing-night start. Repeat evaluations and forecast revisions do not notify again for the same night. Old fingerprints are trimmed after 30 days. These preferences and fingerprints are exported in `.ambackup`.
- The app never silently enables monitoring or requests exact-alarm permissions. Disabled rules generate neither checks nor alerts. On a failure (offline, unavailable forecast, OS rejection) a future explicit/foreground check may retry; the test UI reports unavailable sources.

## Platforms and permissions

- **Android:** `flutter_local_notifications` (22.3.3), Android 13+ `POST_NOTIFICATIONS`, desugaring enabled in Gradle. No `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, or boot receiver: notifications are displayed after an active evaluation, not registered as future alarms.
- **iOS:** local `UNUserNotificationCenter` notices with explicit permission; initialization itself does not request permissions. The application delegate is configured for foreground presentation.
- **Web, Windows, Linux, macOS:** storage and editing supported, system notifications disabled in this version (explicit indicator in the settings). No browser notification permission prompts.

## Background limitations

**This is not continuous autonomous weather monitoring.** Flutter processes may be suspended or terminated; neither Android nor iOS guarantees periodic background execution. OS delivery is subject to notification permissions, Do Not Disturb/focus modes, and device settings. When the app is closed and does not run, **no forecasts are refreshed and no new alerts are issued**. Existing alerts already delivered remain in the notification tray according to the platform.

A future opt-in server-side scheduler, or OS-supported, best-effort platform background tasks, can add monitoring. Any remote solution must clearly disclose network use and opt-in data transfers; this issue does not require either.

## Data & limitations

The chosen observing-site time zone and UTC instants are used for the night key so midnight and DST transitions are unambiguous. Alerts are derived from a forecasting model, not guaranteed cloud-free skies. Missing targets or deleted locations are skipped. Duplicate protection is maintained locally across ordinary app restarts; a restore to a different device carries the same history.

## Test scenarios

- Rule serialization, version mismatch, bad threshold and duplicate IDs.
- SQLite persistence of disabled/enabled settings and delivered night fingerprints.
- Thresholds, duration, missing/stale weather, next-night eligibility.
- Repeat evaluation does not send duplicate notifications; disabling rules prevents sends.
- DST-aware selection of the observing date.
- `.ambackup` round trip retains alert rules and their deduplication history.

## Installation checks

1. Run `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test`.
2. On an Android and an iOS physical device, create a rule and enable notifications. Confirm a permission prompt is shown only when enabling.
3. Use **Check now** with a fresh eligible forecast, then repeat and confirm no duplicate alert. Disable the global toggle and confirm further checks produce no notifications.
4. Confirm an offline or stale weather snapshot never generates a false favorable alert. Test the application after restart and return to foreground.
