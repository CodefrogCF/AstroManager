import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../equipment/domain/models/equipment_models.dart';
import '../../intelligence/domain/models/observation_window.dart';
import '../../intelligence/domain/models/suitability_score.dart';
import '../../intelligence/domain/services/observation_window_recommendation.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../domain/discovery_results.dart';

abstract interface class DiscoveryEvaluator {
  Future<List<RankedDiscoveryTarget>> evaluate({
    required List<CelestialObject> targets,
    required ObservingLocation location,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    required int minimumDurationMinutes,
    required double minimumAltitudeDegrees,
    required WeatherForecastSnapshot? weather,
    required OpticalMetrics? optics,
    required bool Function() isCurrent,
  });
}

final class DefaultDiscoveryEvaluator implements DiscoveryEvaluator {
  const DefaultDiscoveryEvaluator();

  @override
  Future<List<RankedDiscoveryTarget>> evaluate({
    required List<CelestialObject> targets,
    required ObservingLocation location,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    required int minimumDurationMinutes,
    required double minimumAltitudeDegrees,
    required WeatherForecastSnapshot? weather,
    required OpticalMetrics? optics,
    required bool Function() isCurrent,
  }) async {
    final results = <RankedDiscoveryTarget>[];
    final options = ObservationWindowOptions(
      minimumSessionDuration: Duration(minutes: minimumDurationMinutes),
      maximumSessionDuration: const Duration(hours: 3),
      candidateStep: const Duration(minutes: 30),
      maximumRecommendations: 1,
    );
    final profile = SuitabilityScoringProfile(
      minimumAltitudeDegrees: minimumAltitudeDegrees,
      sampleStep: const Duration(minutes: 15),
    );
    for (final target in targets) {
      if (!isCurrent()) return const [];
      final ranked = ObservationWindowRecommendation.forObservingNight(
        targets: [target],
        location: location,
        localDate: localDate,
        evaluatedAtUtc: evaluatedAtUtc,
        weather: weather,
        optics: optics,
        scoringProfile: profile,
        options: options,
      ).rankedWindows;
      if (ranked.isNotEmpty) {
        results.add(
          RankedDiscoveryTarget(object: target, window: ranked.first),
        );
      }
      // A bounded, asynchronous per-target loop keeps interactions responsive
      // on Flutter Web, where compute() is not a separate worker isolate.
      await Future<void>.delayed(Duration.zero);
    }
    return rankDiscoveryTargets(results);
  }
}

final discoveryEvaluatorProvider = Provider<DiscoveryEvaluator>((ref) {
  return const DefaultDiscoveryEvaluator();
});
