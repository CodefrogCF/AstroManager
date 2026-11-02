import 'observation_session.dart';
import 'planned_imaging_project.dart';

/// Derives usable imaging time from accepted light frames only.
/// Values are kept as doubles: exposure durations can contain fractions of a
/// second, and rounding each individual session would lose integration time.
abstract final class IntegrationTimeCalculator {
  static double acceptedSeconds(ObservationSession session) =>
      session.exposureSeconds * session.acceptedFrames;

  static ProjectIntegrationSummary forProject(
    PlannedImagingProject project,
    Iterable<ObservationSession> sessions,
  ) {
    var acceptedSeconds = 0.0;
    var acceptedFrames = 0;
    var rejectedFrames = 0;
    var sessionCount = 0;

    for (final session in sessions) {
      // The same repository may contain sessions from different projects.
      // Never count a session against an unrelated project's goal.
      if (session.projectId != project.id) {
        continue;
      }
      sessionCount++;
      acceptedFrames += session.acceptedFrames;
      rejectedFrames += session.rejectedFrames;
      acceptedSeconds += IntegrationTimeCalculator.acceptedSeconds(session);
    }

    return ProjectIntegrationSummary(
      acceptedSeconds: acceptedSeconds,
      targetSeconds: project.plannedIntegrationSeconds,
      sessionCount: sessionCount,
      acceptedFrames: acceptedFrames,
      rejectedFrames: rejectedFrames,
    );
  }
}

/// `targetSeconds == 0` means no goal is configured, rather than 0% progress.
final class ProjectIntegrationSummary {
  const ProjectIntegrationSummary({
    required this.acceptedSeconds,
    required this.targetSeconds,
    required this.sessionCount,
    required this.acceptedFrames,
    required this.rejectedFrames,
  });

  final double acceptedSeconds;
  final int targetSeconds;
  final int sessionCount;
  final int acceptedFrames;
  final int rejectedFrames;

  bool get hasTarget => targetSeconds > 0;

  /// Uncapped percentage; projects can exceed their original imaging target.
  double? get progressPercent =>
      hasTarget ? acceptedSeconds / targetSeconds * 100 : null;

  /// Capped strictly for the visual progress bar.
  double? get progressFraction {
    if (!hasTarget) {
      return null;
    }
    final fraction = acceptedSeconds / targetSeconds;
    if (fraction < 0) {
      return 0;
    }
    if (fraction > 1) {
      return 1;
    }
    return fraction;
  }

  double? get remainingSeconds {
    if (!hasTarget) {
      return null;
    }
    final remaining = targetSeconds - acceptedSeconds;
    return remaining > 0 ? remaining : 0.0;
  }

  bool get targetReached => hasTarget && acceptedSeconds >= targetSeconds;
}

/// Human-readable times. Never round values before calculating a total.
abstract final class IntegrationTimeFormatter {
  static String format(num seconds) {
    final value = seconds.toDouble();
    if (!value.isFinite || value < 0) {
      throw const FormatException(
        'Integration time must be finite and non-negative.',
      );
    }
    if (value == 0) {
      return '0 s';
    }
    if (value < 0.000001) {
      return '<0.000001 s';
    }
    if (value < 60) {
      return '${_decimal(value, value < 1 ? 6 : 3)} s';
    }
    if (value < 3600) {
      return '${_decimal(value / 60, 3)} min';
    }
    return '${_decimal(value / 3600, 3)} h';
  }

  static String _decimal(double value, int digits) {
    final formatted = value.toStringAsFixed(digits);
    return formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
