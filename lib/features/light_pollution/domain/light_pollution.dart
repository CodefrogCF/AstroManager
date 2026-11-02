/// These quantities must never be silently converted into each other.
enum NightLightKind {
  measuredSkyBrightness,
  modeledSkyBrightness,
  satelliteRadiance,
}

/// A single georeferenced reading or model output with immutable provenance.
/// Satellite upward radiance is NOT an SQM reading or a Bortle class.
final class LightPollutionReading {
  const LightPollutionReading({
    required this.kind,
    required this.value,
    required this.sourceId,
    required this.sourceName,
    required this.datasetDate,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.sourceUrl,
    this.license,
    this.sourceCatalogUpdatedAt,
  });

  final NightLightKind kind;
  final double value;
  final String sourceId;
  final String sourceName;

  /// Date of the actual sample/composite (NOT the retrieval date).
  final DateTime datasetDate;
  final double latitude;
  final double longitude;
  final String description;
  final String? sourceUrl;
  final String? license;

  /// The catalogue metadata update date (not the dataset collection date).
  final DateTime? sourceCatalogUpdatedAt;

  String get unit => switch (kind) {
    NightLightKind.satelliteRadiance => 'nW/cm²/sr',
    NightLightKind.measuredSkyBrightness ||
    NightLightKind.modeledSkyBrightness => 'mag/arcsec²',
  };

  String get kindLabel => switch (kind) {
    NightLightKind.satelliteRadiance => 'Satellite upward radiance',
    NightLightKind.measuredSkyBrightness => 'Measured zenith sky brightness',
    NightLightKind.modeledSkyBrightness => 'Modeled zenith sky brightness',
  };

  void validate() {
    if (!value.isFinite ||
        value < 0 ||
        (kind != NightLightKind.satelliteRadiance && value > 30) ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !datasetDate.isUtc ||
        sourceId.isEmpty ||
        sourceName.isEmpty) {
      throw const FormatException('Invalid light pollution reading.');
    }
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'value': value,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'datasetDate': datasetDate.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'sourceUrl': sourceUrl,
    'license': license,
    'sourceCatalogUpdatedAt': sourceCatalogUpdatedAt?.toIso8601String(),
  };

  factory LightPollutionReading.fromJson(Map<String, dynamic> json) {
    final reading = LightPollutionReading(
      kind: NightLightKind.values.byName(json['kind'] as String),
      value: (json['value'] as num).toDouble(),
      sourceId: json['sourceId'] as String,
      sourceName: json['sourceName'] as String,
      datasetDate: DateTime.parse(json['datasetDate'] as String).toUtc(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      license: json['license'] as String?,
      sourceCatalogUpdatedAt: json['sourceCatalogUpdatedAt'] == null
          ? null
          : DateTime.parse(json['sourceCatalogUpdatedAt'] as String).toUtc(),
    );
    reading.validate();
    return reading;
  }
}

/// A conservative, relative comparison of *the same* VIIRS dataset.
/// 0 means darker and 1 brighter. Not a physical model of sky glow.
abstract final class SatelliteRadianceIndicator {
  static double? relativeBrightness(LightPollutionReading? reading) {
    if (reading == null || reading.kind != NightLightKind.satelliteRadiance) {
      return null;
    }
    reading.validate();
    // Compress bright urban outliers without claiming an absolute Bortle value.
    return reading.value / (reading.value + 5.0);
  }

  static double? relativeDarknessScore(LightPollutionReading? reading) {
    final brightness = relativeBrightness(reading);
    return brightness == null ? null : 100 * (1 - brightness);
  }
}

abstract interface class LightPollutionProvider {
  String get id;

  /// Returns null only for genuine no-data conditions. Network failures throw.
  Future<LightPollutionReading?> fetch({
    required double latitude,
    required double longitude,
  });
}
