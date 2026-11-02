import '../../intelligence/domain/models/observation_window.dart';
import 'observation_alert.dart';

/// Pure eligibility check: uses actual recommendation windows rather than
/// inventing scores from forecast percentages. Stale/incomplete forecast
/// coverage never triggers an alert. A selected window must start soon.
abstract final class ObservationAlertEvaluator {
  static ObservationWindow? bestEligible({
    required ObservationAlertRule rule,
    required ObservationWindowRecommendations recommendations,
    required DateTime nowUtc,
    Duration lookAhead = const Duration(hours: 48),
  }) {
    rule.validate();
    if (!rule.enabled || !nowUtc.isUtc || lookAhead <= Duration.zero) {
      return null;
    }
    final upper = nowUtc.add(lookAhead);
    final matches = recommendations.rankedWindows.where(
      (window) =>
          window.targetId == rule.targetId &&
          !window.startUtc.isBefore(nowUtc) &&
          !window.startUtc.isAfter(upper) &&
          window.duration >= Duration(minutes: rule.minimumDurationMinutes) &&
          window.score.score.isFinite &&
          window.score.score >= rule.minimumScore &&
          window.weatherStatus == WindowWeatherStatus.complete,
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.first; // Recommendation engine already ranks descending.
  }

  /// Deterministic, DST-safe duplicate key. One alert per configured rule and
  /// *observing night*, even if forecasts change the preferred window.
  static String fingerprint(String ruleId, DateTime nightStartUtc) {
    if (ruleId.isEmpty || !nightStartUtc.isUtc) {
      throw ArgumentError('Expected alert ID and UTC night start.');
    }
    return '$ruleId|${nightStartUtc.toIso8601String()}';
  }
}
