// Fixed observations and forecasts for deterministic, network-free
// integration tests of the suitability and recommendation engines.
//
// All source timestamps are UTC and fixed. Changing the machine clock,
// locale, time zone, or internet connection cannot change a scenario.
import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/weather/domain/models/weather_cache.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';

abstract final class RecommendationScenarios {
  static const observer = ObserverPosition(
    latitudeDegrees: 47.48,
    longitudeDegrees: 8.21,
    elevationMeters: 400,
  );

  static const location = ObservingLocation(
    id: 'fixed-zurich',
    name: 'Fixed Zurich site',
    latitude: 47.48,
    longitude: 8.21,
    elevationMeters: 400,
    timeZone: 'Europe/Zurich',
    isDefault: true,
  );

  /// A synthetic near-polar object visible throughout the autumn night.
  static const circumpolar = CelestialObject(
    id: 'fixture-north',
    designation: 'Fixed northern target',
    category: CelestialCategory.nebula,
    sourceType: 'Fixture',
    raDegrees: 80,
    decDegrees: 89.5,
    constellation: 'UMi',
    commonNames: '',
    aliases: '',
    majorAxisArcmin: 30,
    minorAxisArcmin: 20,
  );

  static const secondNorthern = CelestialObject(
    id: 'fixture-north-2',
    designation: 'Second fixed northern target',
    category: CelestialCategory.galaxy,
    sourceType: 'Fixture',
    raDegrees: 120,
    decDegrees: 85,
    constellation: 'UMi',
    commonNames: '',
    aliases: '',
    majorAxisArcmin: 30,
    minorAxisArcmin: 20,
  );

  /// Cannot reach 30° altitude at a latitude of 47.48° north.
  static const farSouth = CelestialObject(
    id: 'fixture-south',
    designation: 'Unobservable southern target',
    category: CelestialCategory.galaxy,
    sourceType: 'Fixture',
    raDegrees: 120,
    decDegrees: -80,
    constellation: 'Oct',
    commonNames: '',
    aliases: '',
    majorAxisArcmin: 30,
    minorAxisArcmin: 20,
  );

  static const optics = OpticalMetrics(
    effectiveFocalLengthMm: 800,
    effectiveFocalRatio: 5,
    horizontalFovDegrees: 1,
    verticalFovDegrees: 1,
    pixelScaleXArcsec: 1.5,
    pixelScaleYArcsec: 1.5,
  );

  static final startUtc = DateTime.utc(2026, 11, 1, 20);
  static final endUtc = DateTime.utc(2026, 11, 1, 22);
  static final evaluatedAtUtc = DateTime.utc(2026, 11, 1, 19, 40);

  static HourlyWeatherForecast hour(
    DateTime utc, {
    double cloudPercent = 0,
    double precipitationMm = 0,
    double precipitationProbabilityPercent = 0,
    double windMetersPerSecond = 2,
    bool missingTotalClouds = false,
    bool unavailableLowClouds = false,
    bool missingAll = false,
  }) {
    if (missingAll) {
      return HourlyWeatherForecast(timeUtc: utc);
    }
    return HourlyWeatherForecast(
      timeUtc: utc,
      totalCloudCoverPercent: missingTotalClouds
          ? const WeatherValue<double>.missing()
          : WeatherValue<double>.available(cloudPercent),
      lowCloudCoverPercent: unavailableLowClouds
          ? const WeatherValue<double>.unavailable()
          : WeatherValue<double>.available(cloudPercent),
      midCloudCoverPercent: WeatherValue<double>.available(cloudPercent),
      highCloudCoverPercent: WeatherValue<double>.available(cloudPercent),
      precipitationMillimeters: WeatherValue<double>.available(precipitationMm),
      precipitationProbabilityPercent: WeatherValue<double>.available(
        precipitationProbabilityPercent,
      ),
      windSpeedMetersPerSecond: WeatherValue<double>.available(
        windMetersPerSecond,
      ),
      windGustMetersPerSecond: const WeatherValue<double>.available(3),
      relativeHumidityPercent: const WeatherValue<double>.available(40),
      visibilityMeters: const WeatherValue<double>.available(30000),
    );
  }

  /// Forecast coverage may be sparse. Omitted hours are never interpolated.
  static WeatherForecastSnapshot forecast({
    double cloudPercent = 0,
    double precipitationMm = 0,
    double precipitationProbabilityPercent = 0,
    bool missingTotalClouds = false,
    bool unavailableLowClouds = false,
    bool missingAll = false,
    bool stale = false,
    bool wrongLocation = false,
    List<DateTime>? hoursUtc,
  }) {
    final times =
        hoursUtc ?? [startUtc, startUtc.add(const Duration(hours: 1))];
    return WeatherForecastSnapshot(
      forecast: WeatherForecast(
        provider: const WeatherProviderMetadata(
          id: 'offline-fixture',
          name: 'Offline forecast fixture',
        ),
        latitudeDegrees: wrongLocation ? 0 : observer.latitudeDegrees,
        longitudeDegrees: observer.longitudeDegrees,
        issuedAtUtc: DateTime.utc(2026, 11, 1, 19, 20),
        fetchedAtUtc: DateTime.utc(2026, 11, 1, 19, 30),
        hours: [
          for (final time in times)
            hour(
              time,
              cloudPercent: cloudPercent,
              precipitationMm: precipitationMm,
              precipitationProbabilityPercent: precipitationProbabilityPercent,
              missingTotalClouds: missingTotalClouds,
              unavailableLowClouds: unavailableLowClouds,
              missingAll: missingAll,
            ),
        ],
      ),
      origin: stale
          ? WeatherForecastOrigin.staleFallback
          : WeatherForecastOrigin.network,
      checkedAtUtc: evaluatedAtUtc,
      isStale: stale,
    );
  }
}
