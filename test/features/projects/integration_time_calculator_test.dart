import 'package:astromanager/features/projects/domain/integration_time_calculator.dart';
import 'package:astromanager/features/projects/domain/observation_session.dart';
import 'package:astromanager/features/projects/domain/planned_imaging_project.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedImagingProject project({String id = 'm31', int target = 10800}) =>
    PlannedImagingProject(
      id: id,
      title: 'Andromeda Galaxy (M31)',
      targetIds: const ['NGC0224'],
      createdAtUtc: DateTime.utc(2026, 11, 2),
      plannedIntegrationSeconds: target,
    );

ObservationSession session(
  String id, {
  String projectId = 'm31',
  double exposure = 60,
  int accepted = 60,
  int rejected = 0,
  int? frames,
}) => ObservationSession(
  id: id,
  projectId: projectId,
  startedAtUtc: DateTime.utc(2026, 11, 2),
  timeZoneId: 'UTC',
  utcOffsetMinutes: 0,
  exposureSeconds: exposure,
  frameCount: frames ?? accepted + rejected,
  acceptedFrames: accepted,
  rejectedFrames: rejected,
);

void main() {
  test('M31: two sessions accumulate 1 h + 1.5 h of usable integration', () {
    final summary = IntegrationTimeCalculator.forProject(project(), [
      session('s1', accepted: 60, rejected: 10),
      session('s2', accepted: 90, rejected: 10),
    ]);
    expect(summary.sessionCount, 2);
    expect(summary.acceptedFrames, 150);
    expect(summary.rejectedFrames, 20);
    expect(summary.acceptedSeconds, 9000);
    expect(summary.progressPercent, closeTo(83.333333, 0.00001));
    expect(summary.progressFraction, closeTo(5 / 6, 0.00001));
    expect(summary.remainingSeconds, 1800);
    expect(summary.targetReached, false);
    expect(IntegrationTimeFormatter.format(summary.acceptedSeconds), '2.5 h');
  });

  test('rejected and unclassified frames never contribute', () {
    final s = session(
      's',
      exposure: 45.5,
      accepted: 2,
      rejected: 4,
      frames: 10,
    );
    expect(s.totalExposureSeconds, 455);
    expect(IntegrationTimeCalculator.acceptedSeconds(s), 91);
    final summary = IntegrationTimeCalculator.forProject(project(), [s]);
    expect(summary.acceptedSeconds, 91);
    expect(summary.rejectedFrames, 4);
  });

  test('project with no sessions has zero progress', () {
    final summary = IntegrationTimeCalculator.forProject(project(), []);
    expect(summary.acceptedSeconds, 0);
    expect(summary.sessionCount, 0);
    expect(summary.progressPercent, 0);
    expect(summary.progressFraction, 0);
    expect(summary.remainingSeconds, 10800);
    expect(summary.targetReached, false);
  });

  test(
    'no configured target still tracks integration, without a percentage',
    () {
      final summary = IntegrationTimeCalculator.forProject(project(target: 0), [
        session('s'),
      ]);
      expect(summary.acceptedSeconds, 3600);
      expect(summary.hasTarget, false);
      expect(summary.progressPercent, null);
      expect(summary.progressFraction, null);
      expect(summary.remainingSeconds, null);
      expect(summary.targetReached, false);
    },
  );

  test('over-target percentage is not capped; progress bar is', () {
    final summary = IntegrationTimeCalculator.forProject(
      project(target: 1800),
      [session('s')],
    );
    expect(summary.progressPercent, 200);
    expect(summary.progressFraction, 1);
    expect(summary.remainingSeconds, 0);
    expect(summary.targetReached, true);
  });

  test('other projects are ignored even if passed in the same iterable', () {
    final summary = IntegrationTimeCalculator.forProject(project(), [
      session('own', accepted: 10),
      session('different', projectId: 'm42', accepted: 100),
    ]);
    expect(summary.sessionCount, 1);
    expect(summary.acceptedSeconds, 600);
  });

  test('editing, deleting and changing goal always recomputes from inputs', () {
    final sessions = [session('s1', accepted: 60), session('s2', accepted: 90)];
    expect(
      IntegrationTimeCalculator.forProject(project(), sessions).acceptedSeconds,
      9000,
    );
    sessions[0] = session('s1', accepted: 30);
    expect(
      IntegrationTimeCalculator.forProject(project(), sessions).acceptedSeconds,
      7200,
    );
    sessions.removeAt(1);
    expect(
      IntegrationTimeCalculator.forProject(project(), sessions).acceptedSeconds,
      1800,
    );
    expect(
      IntegrationTimeCalculator.forProject(
        project(target: 1800),
        sessions,
      ).progressPercent,
      100,
    );
  });

  test('fractional exposures are summed without per-session rounding', () {
    final summary = IntegrationTimeCalculator.forProject(project(), [
      session('a', exposure: 0.125, accepted: 3),
      session('b', exposure: 0.125, accepted: 5),
    ]);
    expect(summary.acceptedSeconds, 1);
    expect(IntegrationTimeFormatter.format(0.125), '0.125 s');
  });

  test('extreme allowed inputs remain finite and do not overflow', () {
    final summary = IntegrationTimeCalculator.forProject(project(), [
      session('large', exposure: 86400, accepted: 10000000),
      session('empty', exposure: 0.000001, accepted: 0, rejected: 1),
    ]);
    expect(summary.acceptedSeconds, 864000000000);
    expect(summary.acceptedSeconds.isFinite, true);
    expect(summary.progressFraction, 1);
  });

  test(
    'format chooses seconds, minutes or hours and rejects invalid values',
    () {
      expect(IntegrationTimeFormatter.format(0), '0 s');
      expect(IntegrationTimeFormatter.format(30), '30 s');
      expect(IntegrationTimeFormatter.format(60), '1 min');
      expect(IntegrationTimeFormatter.format(375), '6.25 min');
      expect(IntegrationTimeFormatter.format(3600), '1 h');
      expect(IntegrationTimeFormatter.format(9000), '2.5 h');
      expect(IntegrationTimeFormatter.format(0.00000001), '<0.000001 s');
      expect(() => IntegrationTimeFormatter.format(-1), throwsFormatException);
      expect(
        () => IntegrationTimeFormatter.format(double.nan),
        throwsFormatException,
      );
      expect(
        () => IntegrationTimeFormatter.format(double.infinity),
        throwsFormatException,
      );
    },
  );
}
