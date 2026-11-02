import '../../../../core/astronomy/astronomical_coordinates.dart';
import '../../../../core/astronomy/lunar_ephemeris.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../core/astronomy/target_visibility.dart';
import '../../../equipment/domain/models/equipment_models.dart';
import '../../../intelligence/domain/models/observation_window.dart';
import '../../../intelligence/domain/services/observation_window_recommendation.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../../weather/domain/models/weather_cache.dart';
import '../../../weather/domain/models/weather_forecast.dart';
import '../../domain/models/celestial_object.dart';

final class OpticalSetupSuggestion {
  const OpticalSetupSuggestion({
    required this.profile,
    required this.metrics,
    required this.fitsTarget,
    required this.description,
  });

  final OpticalProfile profile;
  final OpticalMetrics metrics;
  final bool? fitsTarget;
  final String description;
}

final class TargetDetailAnalysisResult {
  const TargetDetailAnalysisResult({
    required this.visibility,
    required this.moon,
    required this.solar,
    required this.recommendations,
    required this.equipment,
  });

  final TargetVisibilityResult visibility;
  final LunarConditions moon;
  final SolarDayEvents solar;
  final ObservationWindowRecommendations recommendations;
  final List<OpticalSetupSuggestion> equipment;

  ObservationWindow? get bestWindow => recommendations.rankedWindows.isEmpty
      ? null
      : recommendations.rankedWindows.first;
}

/// Deterministic, offline astronomy and scoring. All current-weather data is
/// injected with explicit provenance; no provider or UI dependencies.
abstract final class TargetDetailAnalysis {
  static TargetDetailAnalysisResult calculate({
    required CelestialObject object,
    required ObservingLocation location,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    WeatherForecastSnapshot? weather,
    EquipmentInventory? inventory,
    String? selectedProfileId,
  }) {
    object.validate();
    location.validate();
    final solar = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: localDate,
    );
    final coords = EquatorialPosition(
      raDegrees: object.raDegrees,
      decDegrees: object.decDegrees,
    );
    final observer = ObserverPosition(
      latitudeDegrees: location.latitude,
      longitudeDegrees: location.longitude,
      elevationMeters: location.elevationMeters,
    );
    final visibility = TargetVisibility.forObservingNight(
      targetJ2000: coords,
      location: location,
      localDate: localDate,
      sampleStep: const Duration(minutes: 10),
    );
    final setupSuggestions = _setups(object, inventory);
    OpticalMetrics? optics;
    for (final setup in setupSuggestions) {
      if (setup.profile.id == selectedProfileId) optics = setup.metrics;
    }
    final recommendation = ObservationWindowRecommendation.forObservingNight(
      targets: [object],
      location: location,
      localDate: localDate,
      evaluatedAtUtc: evaluatedAtUtc,
      weather: weather,
      optics: optics,
      options: const ObservationWindowOptions(
        minimumSessionDuration: Duration(minutes: 30),
        maximumSessionDuration: Duration(hours: 4),
        maximumRecommendations: 3,
      ),
    );
    final best = recommendation.rankedWindows.isEmpty
        ? null
        : recommendation.rankedWindows.first;
    final moonAt = best == null
        ? solar.nightStartUtc.add(
            solar.nightEndUtc.difference(solar.nightStartUtc) ~/ 2,
          )
        : best.startUtc.add(best.duration ~/ 2);
    final moon = LunarEphemeris.conditionsForTarget(
      at: moonAt,
      observer: observer,
      targetJ2000: coords,
    );
    return TargetDetailAnalysisResult(
      visibility: visibility,
      moon: moon,
      solar: solar,
      recommendations: recommendation,
      equipment: List.unmodifiable(setupSuggestions),
    );
  }

  static List<OpticalSetupSuggestion> _setups(
    CelestialObject object,
    EquipmentInventory? inventory,
  ) {
    if (inventory == null) return const [];
    final results = <OpticalSetupSuggestion>[];
    for (final profile in inventory.profiles) {
      try {
        final metrics = inventory.metricsFor(profile);
        final major = object.majorAxisArcmin;
        final minor = object.minorAxisArcmin;
        final fits = major == null
            ? null
            : major / 60 <= metrics.horizontalFovDegrees &&
                  (minor ?? major) / 60 <= metrics.verticalFovDegrees;
        results.add(
          OpticalSetupSuggestion(
            profile: profile,
            metrics: metrics,
            fitsTarget: fits,
            description: fits == null
                ? 'Angular size unknown — verify framing in atlas'
                : fits
                ? 'Target fits the sensor field at 0° rotation'
                : 'Target exceeds this orientation; rotate or use wider optics',
          ),
        );
      } catch (_) {
        // Broken equipment references must never block target details.
        continue;
      }
    }
    results.sort((a, b) {
      final aFit = a.fitsTarget == true
          ? 0
          : a.fitsTarget == null
          ? 1
          : 2;
      final bFit = b.fitsTarget == true
          ? 0
          : b.fitsTarget == null
          ? 1
          : 2;
      final order = aFit.compareTo(bFit);
      return order == 0 ? a.profile.name.compareTo(b.profile.name) : order;
    });
    return results;
  }

  /// Select the most relevant normalized forecast hour without inventing data.
  static HourlyWeatherForecast? nearestWeatherHour(
    WeatherForecastSnapshot? weather,
    DateTime utc,
  ) {
    if (weather == null || weather.forecast.hours.isEmpty) return null;
    HourlyWeatherForecast? nearest;
    var smallest = const Duration(days: 10000);
    for (final hour in weather.forecast.hours) {
      final difference = hour.timeUtc.difference(utc).abs();
      if (difference < smallest) {
        nearest = hour;
        smallest = difference;
      }
    }
    // Never display a distant hour as the forecast for the observation time.
    return smallest <= const Duration(minutes: 59) ? nearest : null;
  }
}
