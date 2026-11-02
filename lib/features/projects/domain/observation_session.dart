import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A single exposure sequence within an imaging project. UTC is authoritative;
/// the IANA zone and observed offset preserve the original civil time even
/// across daylight-saving transitions and subsequent location edits.
final class ObservationSession {
  ObservationSession({
    required this.id,
    required this.projectId,
    required this.startedAtUtc,
    required this.timeZoneId,
    required this.utcOffsetMinutes,
    required this.exposureSeconds,
    required this.frameCount,
    required this.acceptedFrames,
    required this.rejectedFrames,
    this.endedAtUtc,
    this.locationId,
    this.locationName,
    this.cameraId,
    this.cameraName,
    this.opticId,
    this.opticName,
    this.mountId,
    this.mountName,
    this.iso,
    this.gain,
    this.apertureFNumber,
    this.binning = 1,
    this.filterName = '',
    this.sensorTemperatureC,
    this.notes = '',
  }) {
    validate();
  }

  final String id;
  final String projectId;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final String timeZoneId;
  final int utcOffsetMinutes;
  final String? locationId;
  final String? locationName;
  final String? cameraId;
  final String? cameraName;
  final String? opticId;
  final String? opticName;
  final String? mountId;
  final String? mountName;
  final double exposureSeconds;
  final int frameCount;
  final int acceptedFrames;
  final int rejectedFrames;
  final int? iso;
  final double? gain;
  final double? apertureFNumber;
  final int binning;
  final String filterName;
  final double? sensorTemperatureC;
  final String notes;

  double get totalExposureSeconds => frameCount * exposureSeconds;
  double get acceptedIntegrationSeconds => acceptedFrames * exposureSeconds;

  static bool _zonesReady = false;

  static tz.Location zone(String id) {
    if (!_zonesReady) {
      tz_data.initializeTimeZones();
      _zonesReady = true;
    }
    try {
      return tz.getLocation(id);
    } on tz.LocationNotFoundException {
      throw const FormatException('Unknown IANA time zone.');
    }
  }

  /// Converts a local wall-clock selection to a unique UTC instant. Times
  /// skipped by a DST transition are rejected rather than silently shifted.
  /// Callers must pass the civil date/time components without first applying
  /// the device's time zone (e.g. use DateTime.utc as a component carrier).
  static DateTime utcFromWallClock(DateTime wallClock, String zoneId) {
    final location = zone(zoneId);
    final candidate = tz.TZDateTime(
      location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    );
    // Round-trip through a real UTC instant. A TZDateTime constructor may
    // normalize a nonexistent spring-forward time to the next valid time.
    // Using the offset of that real instant exposes such normalization.
    final instant = candidate.toUtc();
    final offset = tz.TZDateTime.from(instant, location).timeZoneOffset;
    final restoredWallClock = instant.add(offset);
    if (restoredWallClock.year != wallClock.year ||
        restoredWallClock.month != wallClock.month ||
        restoredWallClock.day != wallClock.day ||
        restoredWallClock.hour != wallClock.hour ||
        restoredWallClock.minute != wallClock.minute) {
      throw const FormatException(
        'This time does not exist in the selected time zone (DST).',
      );
    }
    return instant;
  }

  static int offsetAt(DateTime utc, String zoneId) =>
      tz.TZDateTime.from(utc, zone(zoneId)).timeZoneOffset.inMinutes;

  void validate() {
    if (id.trim().isEmpty ||
        projectId.trim().isEmpty ||
        !startedAtUtc.isUtc ||
        (endedAtUtc != null &&
            (!endedAtUtc!.isUtc || endedAtUtc!.isBefore(startedAtUtc))) ||
        timeZoneId.trim().isEmpty ||
        utcOffsetMinutes < -14 * 60 ||
        utcOffsetMinutes > 14 * 60 ||
        utcOffsetMinutes != offsetAt(startedAtUtc, timeZoneId) ||
        !exposureSeconds.isFinite ||
        exposureSeconds <= 0 ||
        exposureSeconds > 86400 ||
        frameCount < 1 ||
        frameCount > 10000000 ||
        acceptedFrames < 0 ||
        rejectedFrames < 0 ||
        acceptedFrames + rejectedFrames > frameCount ||
        (iso != null && (iso! < 1 || iso! > 10000000)) ||
        (gain != null && (!gain!.isFinite || gain! < 0 || gain! > 100000)) ||
        (iso != null && gain != null) ||
        (apertureFNumber != null &&
            (!apertureFNumber!.isFinite ||
                apertureFNumber! <= 0 ||
                apertureFNumber! > 128)) ||
        binning < 1 ||
        binning > 16 ||
        (sensorTemperatureC != null &&
            (!sensorTemperatureC!.isFinite ||
                sensorTemperatureC! < -273.15 ||
                sensorTemperatureC! > 100)) ||
        filterName.length > 120 ||
        notes.length > 20000 ||
        !_validSnapshot(locationId, locationName) ||
        !_validSnapshot(cameraId, cameraName) ||
        !_validSnapshot(opticId, opticName) ||
        !_validSnapshot(mountId, mountName)) {
      throw const FormatException('Invalid observation session.');
    }
  }

  static bool _validSnapshot(String? id, String? name) =>
      (id == null && name == null) ||
      (id != null &&
          id.trim().isNotEmpty &&
          name != null &&
          name.trim().isNotEmpty &&
          name.length <= 200);
}

/// Only metadata lives in SQLite. Image bytes live in app-managed files on
/// native platforms and in a separate IndexedDB object store on web.
final class SessionImageAttachment {
  const SessionImageAttachment({
    required this.id,
    required this.sessionId,
    required this.fileName,
    required this.storageKey,
    required this.byteLength,
    required this.createdAtUtc,
  });

  final String id;
  final String sessionId;
  final String fileName;
  final String storageKey;
  final int byteLength;
  final DateTime createdAtUtc;
}
