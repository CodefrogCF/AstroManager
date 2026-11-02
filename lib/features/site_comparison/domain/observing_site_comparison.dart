import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../../core/astronomy/solar_events.dart';
import '../../../core/astronomy/target_visibility.dart';
import '../../intelligence/domain/models/suitability_score.dart';
import '../../intelligence/domain/services/astrophotography_suitability_scoring.dart';
import '../../light_pollution/data/light_pollution_repository.dart';
import '../../light_pollution/domain/light_pollution.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../terrain/domain/terrain_horizon.dart';
import '../../weather/domain/models/weather_cache.dart';

/// All sites are evaluated for the same target and local calendar date.
/// Their UTC intervals can differ because their time zones differ.
final class SiteComparisonInput {
  const SiteComparisonInput({
    required this.site,
    this.weather,
    this.terrain,
    this.lightPollution,
    this.weatherError,
    this.terrainError,
    this.lightPollutionError,
  });

  final ObservingLocation site;
  final WeatherForecastSnapshot? weather;
  final TerrainHorizonProfile? terrain;
  final LightPollutionSnapshot? lightPollution;
  final String? weatherError;
  final String? terrainError;
  final String? lightPollutionError;
}

final class SiteComparisonOptions {
  const SiteComparisonOptions({
    this.minimumAltitudeDegrees = 30,
    this.compareTerrain = true,
    this.compareLightPollution = true,
    this.sampleStep = const Duration(minutes: 10),
  });

  final double minimumAltitudeDegrees;
  final bool compareTerrain;
  final bool compareLightPollution;
  final Duration sampleStep;
}

final class SiteComparisonResult {
  SiteComparisonResult({
    required this.site,
    required this.nightStartUtc,
    required this.nightEndUtc,
    required this.astronomicalDarkness,
    required this.geometricVisibleDuration,
    required this.visibleDuration,
    required this.bestAltitudeDegrees,
    required this.score,
    required this.terrainKnownFraction,
    required this.terrainReductionFraction,
    required this.weather,
    required this.weatherUsable,
    required this.lightPollution,
    required List<String> missingData,
    required List<String> explanations,
  }) : missingData = List.unmodifiable(missingData),
       explanations = List.unmodifiable(explanations);

  final ObservingLocation site;
  final DateTime nightStartUtc;
  final DateTime nightEndUtc;
  final Duration astronomicalDarkness;
  final Duration geometricVisibleDuration;
  final Duration visibleDuration;
  final double? bestAltitudeDegrees;
  final double score;
  final double? terrainKnownFraction;
  final double? terrainReductionFraction;
  final WeatherForecastSnapshot? weather;
  final bool weatherUsable;
  final LightPollutionSnapshot? lightPollution;
  final List<String> missingData;
  final List<String> explanations;

  bool get isProvisional => missingData.isNotEmpty;
}

final class SiteComparisonReport {
  SiteComparisonReport({
    required this.target,
    required this.localDate,
    required List<SiteComparisonResult> rankedSites,
  }) : rankedSites = List.unmodifiable(rankedSites);

  final CelestialObject target;
  final DateTime localDate;
  final List<SiteComparisonResult> rankedSites;
  SiteComparisonResult get leader => rankedSites.first;
}

/// Pure evaluation: all provider requests are performed by the calling UI.
/// Scoring is heuristic, not a calibrated forecast of image quality.
abstract final class ObservingSiteComparison {
  static SiteComparisonReport compare({
    required CelestialObject target,
    required DateTime localDate,
    required DateTime evaluatedAtUtc,
    required List<SiteComparisonInput> sites,
    SiteComparisonOptions options = const SiteComparisonOptions(),
    WeatherCachePolicy weatherPolicy = const WeatherCachePolicy(),
  }) {
    target.validate();
    if (!evaluatedAtUtc.isUtc || sites.length < 2) {
      throw ArgumentError(
        'At least two sites and a UTC evaluation time required.',
      );
    }
    if (!options.minimumAltitudeDegrees.isFinite ||
        options.minimumAltitudeDegrees < 0 ||
        options.minimumAltitudeDegrees > 80 ||
        options.sampleStep < const Duration(minutes: 1) ||
        options.sampleStep > const Duration(hours: 1)) {
      throw ArgumentError('Invalid comparison altitude or sample resolution.');
    }
    final ids = <String>{};
    for (final site in sites) {
      site.site.validate();
      if (!ids.add(site.site.id)) {
        throw ArgumentError('A saved observing location may occur only once.');
      }
    }

    // VIIRS is a relative indicator. Readings from unlike sources or monthly
    // composites must not be compared numerically as if equivalent.
    final lightDatasets = sites
        .map((input) => input.lightPollution?.reading)
        .whereType<LightPollutionReading>()
        .where((reading) => reading.kind == NightLightKind.satelliteRadiance)
        .map(
          (reading) =>
              '${reading.sourceId}|'
              '${reading.datasetDate.year}-${reading.datasetDate.month}',
        )
        .toSet();
    final incompatibleLights =
        options.compareLightPollution && lightDatasets.length > 1;
    final results = <SiteComparisonResult>[
      for (final input in sites)
        _evaluate(
          target,
          localDate,
          evaluatedAtUtc,
          input,
          options,
          weatherPolicy,
          incompatibleLights,
        ),
    ];
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }
      final missing = a.missingData.length.compareTo(b.missingData.length);
      if (missing != 0) {
        return missing;
      }
      final visibility = b.visibleDuration.compareTo(a.visibleDuration);
      if (visibility != 0) {
        return visibility;
      }
      return a.site.id.compareTo(b.site.id);
    });
    return SiteComparisonReport(
      target: target,
      localDate: DateTime.utc(localDate.year, localDate.month, localDate.day),
      rankedSites: results,
    );
  }

  static SiteComparisonResult _evaluate(
    CelestialObject target,
    DateTime date,
    DateTime evaluated,
    SiteComparisonInput input,
    SiteComparisonOptions options,
    WeatherCachePolicy policy,
    bool incompatibleLights,
  ) {
    final site = input.site;
    final sun = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: date,
    );
    final observer = ObserverPosition(
      latitudeDegrees: site.latitude,
      longitudeDegrees: site.longitude,
      elevationMeters: site.elevationMeters,
    );
    final position = EquatorialPosition(
      raDegrees: target.raDegrees,
      decDegrees: target.decDegrees,
    );
    final darkness = [
      for (final interval in sun.astronomicalDarkness)
        VisibilityInterval(
          startUtc: interval.startUtc,
          endUtc: interval.endUtc,
        ),
    ];
    final geometric = TargetVisibility.calculate(
      targetJ2000: position,
      observer: observer,
      startUtc: sun.nightStartUtc,
      endUtc: sun.nightEndUtc,
      minimumAltitudeDegrees: options.minimumAltitudeDegrees,
      sampleStep: options.sampleStep,
      allowedIntervals: darkness,
    );
    final missing = <String>[];
    final notes = <String>[];
    final darkDuration = darkness.fold<Duration>(
      Duration.zero,
      (sum, interval) => sum + interval.duration,
    );

    TerrainHorizonProfile? terrain;
    if (options.compareTerrain) {
      final candidate = input.terrain;
      if (candidate == null ||
          (candidate.latitude - site.latitude).abs() > 1e-7 ||
          (candidate.longitude - site.longitude).abs() > 1e-7 ||
          (candidate.observerElevationMeters - site.elevationMeters).abs() >
              0.01) {
        missing.add(
          'Terrain horizon unavailable${input.terrainError == null ? '' : ': ${input.terrainError}'}',
        );
      } else {
        terrain = candidate;
        if (!terrain.isComplete) {
          missing.add(
            'Terrain horizon incomplete (${terrain.knownBearings}/${terrain.bearings.length} bearings); visibility is an upper estimate.',
          );
        }
      }
    } else {
      notes.add('Terrain was not requested; geometric horizon used.');
    }

    final visibility = terrain == null
        ? geometric
        : TargetVisibility.calculate(
            targetJ2000: position,
            observer: observer,
            startUtc: sun.nightStartUtc,
            endUtc: sun.nightEndUtc,
            minimumAltitudeDegrees: options.minimumAltitudeDegrees,
            sampleStep: options.sampleStep,
            allowedIntervals: darkness,
            terrainHorizon: terrain,
          );

    final weather = input.weather;
    final forecastMatches =
        weather != null &&
        (weather.forecast.latitudeDegrees - site.latitude).abs() <= 0.02 &&
        (weather.forecast.longitudeDegrees - site.longitude).abs() <= 0.02;
    final validWeather =
        forecastMatches &&
        !weather.isStale &&
        weather.origin != WeatherForecastOrigin.staleFallback &&
        weather.origin != WeatherForecastOrigin.staleCache &&
        !weather.isStaleAt(evaluated, policy);
    if (!validWeather) {
      missing.add(
        'Weather unavailable, stale or for another location${input.weatherError == null ? '' : ': ${input.weatherError}'}',
      );
    }

    LightPollutionReading? nightLights;
    if (options.compareLightPollution) {
      final snapshot = input.lightPollution;
      final reading = snapshot?.reading;
      if (!incompatibleLights &&
          snapshot != null &&
          !snapshot.isStale &&
          reading != null &&
          reading.kind == NightLightKind.satelliteRadiance &&
          (reading.latitude - site.latitude).abs() < 0.001 &&
          (reading.longitude - site.longitude).abs() < 0.001) {
        nightLights = reading;
        notes.add(
          'Night lights: ${reading.value.toStringAsFixed(2)} ${reading.unit}, '
          '${reading.sourceName} (${reading.datasetDate.year}-${reading.datasetDate.month.toString().padLeft(2, '0')}); satellite radiance, not Bortle/SQM.',
        );
      } else {
        missing.add(
          incompatibleLights
              ? 'Satellite night-light datasets differ in source or month; excluded from scoring.'
              : 'Comparable satellite night-light data unavailable${input.lightPollutionError == null ? '' : ': ${input.lightPollutionError}'}',
        );
      }
    } else {
      notes.add('Satellite night-light comparison was not requested.');
    }

    // A common scoring profile for every site, without an imaging-setup/FOV
    // term (no setup is selected by the user). Optional radiance has modest
    // weight; weather never receives an optimistic default when unavailable.
    final weights = options.compareLightPollution
        ? const SuitabilityWeights(
            altitude: 0.21,
            visibleDuration: 0.15,
            astronomicalDarkness: 0.20,
            weather: 0.27,
            moonlight: 0.11,
            fieldOfView: 0,
            lightPollution: 0.06,
          )
        : const SuitabilityWeights(
            altitude: 0.23,
            visibleDuration: 0.16,
            astronomicalDarkness: 0.21,
            weather: 0.29,
            moonlight: 0.11,
            fieldOfView: 0,
            lightPollution: 0,
          );
    final score = AstrophotographySuitabilityScoring.score(
      target: target,
      observer: observer,
      startUtc: sun.nightStartUtc,
      endUtc: sun.nightEndUtc,
      evaluatedAtUtc: evaluated,
      weather: validWeather ? weather : null,
      lightPollution: nightLights,
      profile: SuitabilityScoringProfile(
        weights: weights,
        minimumAltitudeDegrees: options.minimumAltitudeDegrees,
        goodAltitudeDegrees: 85,
        sampleStep: options.sampleStep,
      ),
    );

    if (validWeather &&
        score.factor(SuitabilityFactor.weather).status !=
            SuitabilityDataStatus.complete) {
      missing.add('Weather forecast is incomplete for this observing night.');
    }

    // Apply terrain reduction only when the referenced DEM matches the site.
    // Incomplete DEM profiles make this a provisional upper estimate, not a
    // guarantee of line of sight.
    final geometricMicros = geometric.totalVisibleDuration.inMicroseconds;
    final visibleMicros = visibility.totalVisibleDuration.inMicroseconds;
    final reduction = terrain == null || geometricMicros == 0
        ? null
        : (1 - visibleMicros / geometricMicros).clamp(0.0, 1.0).toDouble();
    final adjustedScore = reduction == null
        ? score.score
        : (score.score * (1 - reduction)).clamp(0.0, 100.0).toDouble();

    notes.add(
      'Target ≥ ${options.minimumAltitudeDegrees.toStringAsFixed(0)}° '
      'during astronomical darkness: ${visibility.totalVisibleDuration.inMinutes} min '
      '(geometric: ${geometric.totalVisibleDuration.inMinutes} min).',
    );
    notes.add(
      'Astronomical darkness: ${darkDuration.inMinutes} min, '
      'site-local night ${site.timeZone}.',
    );
    if (reduction != null) {
      notes.add(
        'DEM terrain reduces geometric visible time by '
        '${(reduction * 100).toStringAsFixed(0)}%; score adjusted proportionally.',
      );
    }
    notes.addAll(
      score.factors.values
          .where((factor) => factor.weight > 0)
          .map((factor) => '${factor.factor.label}: ${factor.explanation}'),
    );
    notes.addAll(score.constraints);
    return SiteComparisonResult(
      site: site,
      nightStartUtc: sun.nightStartUtc,
      nightEndUtc: sun.nightEndUtc,
      astronomicalDarkness: darkDuration,
      geometricVisibleDuration: geometric.totalVisibleDuration,
      visibleDuration: visibility.totalVisibleDuration,
      bestAltitudeDegrees: visibility.bestAltitudeDegrees,
      score: adjustedScore,
      terrainKnownFraction: terrain == null
          ? null
          : terrain.knownBearings / terrain.bearings.length,
      terrainReductionFraction: reduction,
      weather: weather,
      weatherUsable: validWeather,
      lightPollution: input.lightPollution,
      missingData: missing,
      explanations: notes,
    );
  }
}
