/// A suitability score describes one explicit observation interval, not a night.
/// All scored contributions are dimensionless and normalized to 0..100.
enum SuitabilityFactor {
  altitude,
  visibleDuration,
  astronomicalDarkness,
  weather,
  moonlight,
  fieldOfView,
  lightPollution;

  String get label => switch (this) {
    SuitabilityFactor.altitude => 'Target altitude',
    SuitabilityFactor.visibleDuration => 'Visibility duration',
    SuitabilityFactor.astronomicalDarkness => 'Astronomical darkness',
    SuitabilityFactor.weather => 'Weather',
    SuitabilityFactor.moonlight => 'Moonlight interference',
    SuitabilityFactor.fieldOfView => 'Optical field of view',
    SuitabilityFactor.lightPollution => 'Local satellite night-light indicator',
  };
}

/// 'Partial' means the calculation relied on incomplete source parameters.
/// Missing factors do not contribute an optimistic default score.
enum SuitabilityDataStatus { complete, partial, missing }

/// Relative importance, not a universal astronomical calibration.
/// Any nonnegative finite weights are accepted, provided their sum is > 0.
final class SuitabilityWeights {
  const SuitabilityWeights({
    this.altitude = 0.18,
    this.visibleDuration = 0.12,
    this.astronomicalDarkness = 0.20,
    this.weather = 0.28,
    this.moonlight = 0.14,
    this.fieldOfView = 0.08,
    this.lightPollution = 0,
  });

  final double altitude;
  final double visibleDuration;
  final double astronomicalDarkness;
  final double weather;
  final double moonlight;
  final double fieldOfView;

  /// Opt-in. Raw upward radiance is only a relative site indicator.
  final double lightPollution;

  double forFactor(SuitabilityFactor factor) => switch (factor) {
    SuitabilityFactor.altitude => altitude,
    SuitabilityFactor.visibleDuration => visibleDuration,
    SuitabilityFactor.astronomicalDarkness => astronomicalDarkness,
    SuitabilityFactor.weather => weather,
    SuitabilityFactor.moonlight => moonlight,
    SuitabilityFactor.fieldOfView => fieldOfView,
    SuitabilityFactor.lightPollution => lightPollution,
  };

  double get total =>
      altitude +
      visibleDuration +
      astronomicalDarkness +
      weather +
      moonlight +
      fieldOfView +
      lightPollution;

  void validate() {
    for (final factor in SuitabilityFactor.values) {
      final value = forFactor(factor);
      if (!value.isFinite || value < 0) {
        throw ArgumentError.value(
          value,
          factor.name,
          'Expected finite nonnegative weight.',
        );
      }
    }
    if (!total.isFinite || total <= 0) {
      throw ArgumentError('At least one scoring weight must be positive.');
    }
  }
}

/// Application/profile-specific scoring rules.
/// A different profile may be supplied for wide-field nebulae vs galaxies.
final class SuitabilityScoringProfile {
  const SuitabilityScoringProfile({
    this.weights = const SuitabilityWeights(),
    this.minimumAltitudeDegrees = 30,
    this.goodAltitudeDegrees = 65,
    this.sampleStep = const Duration(minutes: 10),
    this.maximumScoreWithoutWeather = 50,
  });

  final SuitabilityWeights weights;
  final double minimumAltitudeDegrees;
  final double goodAltitudeDegrees;
  final Duration sampleStep;

  /// Conservative ceiling when weather is absent, stale or wholly unavailable.
  final double maximumScoreWithoutWeather;

  void validate() {
    weights.validate();
    if (!minimumAltitudeDegrees.isFinite ||
        minimumAltitudeDegrees < -90 ||
        minimumAltitudeDegrees >= 90 ||
        !goodAltitudeDegrees.isFinite ||
        goodAltitudeDegrees <= minimumAltitudeDegrees ||
        goodAltitudeDegrees > 90) {
      throw ArgumentError(
        'Expected -90 <= minimum altitude < good altitude <= 90.',
      );
    }
    if (sampleStep < const Duration(minutes: 1) ||
        sampleStep > const Duration(hours: 1)) {
      throw ArgumentError.value(
        sampleStep,
        'sampleStep',
        'Expected 1 minute to 1 hour.',
      );
    }
    if (!maximumScoreWithoutWeather.isFinite ||
        maximumScoreWithoutWeather < 0 ||
        maximumScoreWithoutWeather > 100) {
      throw ArgumentError.value(
        maximumScoreWithoutWeather,
        'maximumScoreWithoutWeather',
      );
    }
  }
}

/// Transparent score and weighted contribution for one factor.
/// Missing factor's [rawScore] is null and [contribution] is zero.
final class SuitabilityFactorResult {
  const SuitabilityFactorResult({
    required this.factor,
    required this.status,
    required this.rawScore,
    required this.weight,
    required this.contribution,
    required this.dataCoverage,
    required this.explanation,
  });

  final SuitabilityFactor factor;
  final SuitabilityDataStatus status;
  final double? rawScore;
  final double weight;
  final double contribution;
  final double dataCoverage;
  final String explanation;
}

/// Interval-level output. All times are absolute UTC instants.
final class TargetSuitabilityScore {
  TargetSuitabilityScore({
    required this.targetId,
    required this.startUtc,
    required this.endUtc,
    required this.score,
    required this.dataCoverage,
    required this.isProvisional,
    required this.visibleDuration,
    required this.astronomicalDarkDuration,
    required this.usableDuration,
    required this.bestUsableAltitudeDegrees,
    required Map<SuitabilityFactor, SuitabilityFactorResult> factors,
    required List<String> constraints,
  }) : factors = Map.unmodifiable(factors),
       constraints = List.unmodifiable(constraints);

  final String targetId;
  final DateTime startUtc;
  final DateTime endUtc;
  final double score;

  /// Weighted fraction of independently available input data (0..1).
  final double dataCoverage;
  final bool isProvisional;
  final Duration visibleDuration;
  final Duration astronomicalDarkDuration;
  final Duration usableDuration;
  final double? bestUsableAltitudeDegrees;
  final Map<SuitabilityFactor, SuitabilityFactorResult> factors;

  /// Explicit hard constraints, e.g. no target visibility in darkness.
  final List<String> constraints;

  SuitabilityFactorResult factor(SuitabilityFactor factor) => factors[factor]!;
}
