import '../../../../core/astronomy/target_visibility.dart';
import 'suitability_score.dart';

/// Indicates whether a candidate has trustworthy weather information for
/// its *entire* interval. A cached, outdated forecast is never considered fresh.
enum WindowWeatherStatus { complete, partial, missing, stale }

/// Controls the interval search. All durations are measured as elapsed UTC
/// time, never as wall-clock time; DST transitions therefore cannot alter them.
final class ObservationWindowOptions {
  const ObservationWindowOptions({
    this.minimumSessionDuration = const Duration(hours: 1),
    this.maximumSessionDuration = const Duration(hours: 4),
    this.candidateStep = const Duration(minutes: 30),
    this.maximumRecommendations = 10,
    this.maximumOverlapFraction = 0.8,
  });

  final Duration minimumSessionDuration;
  final Duration maximumSessionDuration;
  final Duration candidateStep;
  final int maximumRecommendations;

  /// Suppress nearly identical windows of the SAME target. Other targets are
  /// always ranked independently. Set to 1.0 to keep all distinct candidates.
  final double maximumOverlapFraction;

  void validate() {
    if (minimumSessionDuration < const Duration(minutes: 15) ||
        maximumSessionDuration < minimumSessionDuration ||
        maximumSessionDuration > const Duration(hours: 24)) {
      throw ArgumentError(
        'Expected 15 minutes <= minimum duration <= maximum duration <= 24 hours.',
      );
    }
    if (candidateStep < const Duration(minutes: 5) ||
        candidateStep > const Duration(hours: 1)) {
      throw ArgumentError.value(
        candidateStep,
        'candidateStep',
        'Expected between 5 and 60 minutes.',
      );
    }
    if (maximumRecommendations < 1 || maximumRecommendations > 100) {
      throw ArgumentError.value(
        maximumRecommendations,
        'maximumRecommendations',
      );
    }
    if (!maximumOverlapFraction.isFinite ||
        maximumOverlapFraction <= 0 ||
        maximumOverlapFraction > 1) {
      throw ArgumentError.value(
        maximumOverlapFraction,
        'maximumOverlapFraction',
        'Expected > 0 and <= 1.',
      );
    }
  }
}

/// One ranked recommendation, with a full scoring breakdown and explicit
/// forecast coverage. Boundaries are inclusive start, exclusive end, in UTC.
final class ObservationWindow {
  const ObservationWindow({
    required this.targetId,
    required this.targetDesignation,
    required this.startUtc,
    required this.endUtc,
    required this.bestAltitudeDegrees,
    required this.bestAltitudeAtUtc,
    required this.score,
    required this.weatherStatus,
    required this.weatherTimeCoverage,
    required this.weatherParameterCoverage,
    required this.explanation,
  });

  final String targetId;
  final String targetDesignation;
  final DateTime startUtc;
  final DateTime endUtc;
  final double? bestAltitudeDegrees;
  final DateTime? bestAltitudeAtUtc;
  final TargetSuitabilityScore score;
  final WindowWeatherStatus weatherStatus;

  /// Fraction of UTC time covered by at least one usable weather parameter.
  final double weatherTimeCoverage;

  /// Fraction of expected hourly weather parameters, weighted by elapsed time.
  /// Missing parameters and unsupported layers count as not covered.
  final double weatherParameterCoverage;
  final String explanation;

  Duration get duration => endUtc.difference(startUtc);
  bool get isProvisional =>
      score.isProvisional || weatherStatus != WindowWeatherStatus.complete;
}

/// Results include rejected targets so a user can distinguish an unsuitable
/// object from a calculation which was never performed.
final class ObservationWindowRecommendations {
  ObservationWindowRecommendations({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.minimumAltitudeDegrees,
    required List<VisibilityInterval> astronomicalDarkness,
    required List<ObservationWindow> rankedWindows,
    required Map<String, String> excludedTargets,
  }) : astronomicalDarkness = List.unmodifiable(astronomicalDarkness),
       rankedWindows = List.unmodifiable(rankedWindows),
       excludedTargets = Map.unmodifiable(excludedTargets);

  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final double minimumAltitudeDegrees;
  final List<VisibilityInterval> astronomicalDarkness;
  final List<ObservationWindow> rankedWindows;
  final Map<String, String> excludedTargets;

  bool get hasAstronomicalDarkness => astronomicalDarkness.isNotEmpty;
}
