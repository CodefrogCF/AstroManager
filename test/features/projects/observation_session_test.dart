import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';

ObservationSession sample({
  double exposure = 60,
  int frames = 10,
  int accepted = 8,
  int rejected = 2,
  int? iso = 800,
  double? gain,
  DateTime? started,
  String zone = 'Europe/Zurich',
  int? offset,
}) {
  final timestamp = started ?? DateTime.utc(2026, 11, 2, 19);
  return ObservationSession(
    id: 's1',
    projectId: 'project1',
    startedAtUtc: timestamp,
    timeZoneId: zone,
    utcOffsetMinutes: offset ?? ObservationSession.offsetAt(timestamp, zone),
    exposureSeconds: exposure,
    frameCount: frames,
    acceptedFrames: accepted,
    rejectedFrames: rejected,
    iso: iso,
    gain: gain,
  );
}

void main() {
  test('accepted and total integration are derived without rounding', () {
    final session = sample(exposure: 2.5);
    expect(session.acceptedIntegrationSeconds, 20);
    expect(session.totalExposureSeconds, 25);
  });

  test('rejects inconsistent exposure, frame counts and sensor settings', () {
    expect(() => sample(exposure: 0), throwsFormatException);
    expect(() => sample(exposure: double.nan), throwsFormatException);
    expect(() => sample(frames: 0), throwsFormatException);
    expect(() => sample(frames: 5), throwsFormatException);
    expect(() => sample(accepted: -1), throwsFormatException);
    expect(() => sample(iso: 800, gain: 100), throwsFormatException);
    expect(() => sample(iso: 0), throwsFormatException);
    expect(() => sample(gain: -1, iso: null), throwsFormatException);
  });

  test('UTC, zone and offset identify the real instant unambiguously', () {
    final winter = DateTime.utc(2026, 11, 2, 19);
    final summer = DateTime.utc(2026, 7, 2, 19);
    expect(ObservationSession.offsetAt(winter, 'Europe/Zurich'), 60);
    expect(ObservationSession.offsetAt(summer, 'Europe/Zurich'), 120);
    expect(() => sample(offset: 120), throwsFormatException);
    expect(() => sample(started: winter.toLocal()), throwsFormatException);
    expect(() => sample(zone: 'Not/An_IANA_Zone'), throwsFormatException);
  });

  test('rejects nonexistent DST spring-forward wall time', () {
    expect(
      () => ObservationSession.utcFromWallClock(
        // UTC acts only as a carrier for unmodified wall-clock fields.
        DateTime.utc(2026, 3, 29, 2, 30),
        'Europe/Zurich',
      ),
      throwsFormatException,
    );
  });

  test('valid wall times on both sides of DST jump resolve correctly', () {
    expect(
      ObservationSession.utcFromWallClock(
        DateTime.utc(2026, 3, 29, 1, 30),
        'Europe/Zurich',
      ),
      DateTime.utc(2026, 3, 29, 0, 30),
    );
    expect(
      ObservationSession.utcFromWallClock(
        DateTime.utc(2026, 3, 29, 3, 30),
        'Europe/Zurich',
      ),
      DateTime.utc(2026, 3, 29, 1, 30),
    );
  });

  test('two fall-back instants are distinct despite matching wall clock', () {
    final early = sample(started: DateTime.utc(2026, 10, 25, 0, 30));
    final late = sample(started: DateTime.utc(2026, 10, 25, 1, 30));
    expect(early.utcOffsetMinutes, 120);
    expect(late.utcOffsetMinutes, 60);
    expect(early.startedAtUtc, isNot(late.startedAtUtc));
  });

  test('historical snapshots require a name with each equipment id', () {
    expect(
      () => ObservationSession(
        id: 'a',
        projectId: 'project',
        startedAtUtc: DateTime.utc(2026),
        timeZoneId: 'UTC',
        utcOffsetMinutes: 0,
        exposureSeconds: 60,
        frameCount: 1,
        acceptedFrames: 1,
        rejectedFrames: 0,
        cameraId: 'camera-without-name',
      ),
      throwsFormatException,
    );
  });
}
