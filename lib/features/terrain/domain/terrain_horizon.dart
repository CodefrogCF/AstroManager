import 'dart:math' as math;

import '../../locations/domain/models/observing_location.dart';

/// Resolution is angular (true bearing clockwise from north) and radial.
/// Keep the public elevation service's request budget bounded.
final class TerrainHorizonOptions {
  const TerrainHorizonOptions({
    this.azimuthStepDegrees = 10,
    this.maximumDistanceMeters = 15000,
    this.distanceStepMeters = 1000,
  });

  final int azimuthStepDegrees;
  final int maximumDistanceMeters;
  final int distanceStepMeters;

  int get bearingCount => 360 ~/ azimuthStepDegrees;
  int get samplesPerBearing =>
      (maximumDistanceMeters / distanceStepMeters).ceil();

  void validate() {
    if (azimuthStepDegrees < 1 ||
        azimuthStepDegrees > 60 ||
        360 % azimuthStepDegrees != 0 ||
        maximumDistanceMeters < 1000 ||
        maximumDistanceMeters > 60000 ||
        distanceStepMeters < 100 ||
        distanceStepMeters > 5000 ||
        distanceStepMeters > maximumDistanceMeters ||
        bearingCount * samplesPerBearing > 3000) {
      throw ArgumentError(
        'Invalid terrain resolution, radius, or sample budget.',
      );
    }
  }
}

final class TerrainPoint {
  const TerrainPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// A nullable result means the requested coordinate has no elevation data.
abstract interface class TerrainElevationProvider {
  String get id;
  Future<List<double?>> elevations(List<TerrainPoint> points);
}

final class TerrainBearing {
  const TerrainBearing({
    required this.azimuthDegrees,
    required this.altitudeDegrees,
    this.distanceMeters,
  });
  final double azimuthDegrees;

  /// Null means unknown, never "unobstructed".
  final double? altitudeDegrees;
  final double? distanceMeters;

  Map<String, Object?> toJson() => {
    'azimuth': azimuthDegrees,
    'altitude': altitudeDegrees,
    'distance': distanceMeters,
  };

  factory TerrainBearing.fromJson(Map<String, dynamic> json) {
    final az = (json['azimuth'] as num).toDouble();
    final altitude = (json['altitude'] as num?)?.toDouble();
    final distance = (json['distance'] as num?)?.toDouble();
    if (!az.isFinite ||
        az < 0 ||
        az >= 360 ||
        (altitude != null &&
            (!altitude.isFinite || altitude < -90 || altitude > 90)) ||
        (distance != null && (!distance.isFinite || distance <= 0))) {
      throw const FormatException('Invalid horizon bearing.');
    }
    return TerrainBearing(
      azimuthDegrees: az,
      altitudeDegrees: altitude,
      distanceMeters: distance,
    );
  }
}

final class TerrainHorizonProfile {
  TerrainHorizonProfile({
    required this.sourceId,
    required this.createdAtUtc,
    required this.latitude,
    required this.longitude,
    required this.observerElevationMeters,
    required this.options,
    required List<TerrainBearing> bearings,
  }) : bearings = List.unmodifiable(bearings) {
    options.validate();
    if (!createdAtUtc.isUtc ||
        !latitude.isFinite ||
        latitude.abs() > 90 ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        !observerElevationMeters.isFinite ||
        sourceId.isEmpty ||
        this.bearings.length != options.bearingCount) {
      throw const FormatException('Invalid terrain profile.');
    }
    for (var i = 0; i < this.bearings.length; i++) {
      if ((this.bearings[i].azimuthDegrees - i * options.azimuthStepDegrees)
              .abs() >
          0.00001) {
        throw const FormatException(
          'Terrain bearings must cover the full circle.',
        );
      }
    }
  }

  final String sourceId;
  final DateTime createdAtUtc;
  final double latitude;
  final double longitude;
  final double observerElevationMeters;
  final TerrainHorizonOptions options;
  final List<TerrainBearing> bearings;

  int get knownBearings =>
      bearings.where((bearing) => bearing.altitudeDegrees != null).length;
  bool get isComplete => knownBearings == bearings.length;

  /// Linear interpolation including 360/0 wrap. Never interpolate through
  /// missing data, and never infer an unobstructed horizon from missing data.
  double? altitudeAt(double azimuthDegrees) {
    if (!azimuthDegrees.isFinite) {
      return null;
    }
    final az = (azimuthDegrees % 360 + 360) % 360;
    final position = az / options.azimuthStepDegrees;
    final index = position.floor() % bearings.length;
    final fraction = position - position.floor();
    final a = bearings[index].altitudeDegrees;
    if (fraction.abs() < 1e-12) {
      return a;
    }
    final b = bearings[(index + 1) % bearings.length].altitudeDegrees;
    if (a == null || b == null) {
      return null;
    }
    return a + (b - a) * fraction;
  }

  bool? blocks({
    required double azimuthDegrees,
    required double targetAltitudeDegrees,
  }) {
    final height = altitudeAt(azimuthDegrees);
    if (height == null) {
      return null;
    }
    return targetAltitudeDegrees < height;
  }

  Map<String, Object?> toJson() => {
    'format': 1,
    'source': sourceId,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'observerElevationMeters': observerElevationMeters,
    'azimuthStepDegrees': options.azimuthStepDegrees,
    'maximumDistanceMeters': options.maximumDistanceMeters,
    'distanceStepMeters': options.distanceStepMeters,
    'bearings': [for (final b in bearings) b.toJson()],
  };

  factory TerrainHorizonProfile.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 1) {
      throw const FormatException('Unsupported horizon profile format.');
    }
    final date = DateTime.parse(json['createdAtUtc'] as String);
    if (!date.isUtc) {
      throw const FormatException('Profile timestamp must be UTC.');
    }
    return TerrainHorizonProfile(
      sourceId: json['source'] as String,
      createdAtUtc: date,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      observerElevationMeters: (json['observerElevationMeters'] as num)
          .toDouble(),
      options: TerrainHorizonOptions(
        azimuthStepDegrees: json['azimuthStepDegrees'] as int,
        maximumDistanceMeters: json['maximumDistanceMeters'] as int,
        distanceStepMeters: json['distanceStepMeters'] as int,
      ),
      bearings: [
        for (final value in json['bearings'] as List)
          TerrainBearing.fromJson(Map<String, dynamic>.from(value as Map)),
      ],
    );
  }
}

/// Sphere-based geodesic sampling and geometric elevation angles.
/// Curvature is included, atmospheric refraction is intentionally excluded.
abstract final class TerrainHorizonCalculator {
  static const double earthRadiusMeters = 6371008.8;
  static const double _toRadians = math.pi / 180;

  static TerrainPoint destination(
    TerrainPoint origin,
    double azimuthDegrees,
    double distanceMeters,
  ) {
    final phi = origin.latitude * _toRadians;
    final lambda = origin.longitude * _toRadians;
    final direction = azimuthDegrees * _toRadians;
    final delta = distanceMeters / earthRadiusMeters;
    final latitude = math.asin(
      math.sin(phi) * math.cos(delta) +
          math.cos(phi) * math.sin(delta) * math.cos(direction),
    );
    final longitude =
        lambda +
        math.atan2(
          math.sin(direction) * math.sin(delta) * math.cos(phi),
          math.cos(delta) - math.sin(phi) * math.sin(latitude),
        );
    final lng = ((longitude / _toRadians + 540) % 360) - 180;
    return TerrainPoint(latitude / _toRadians, lng);
  }

  static double elevationAngleDegrees({
    required double observerElevationMeters,
    required double terrainElevationMeters,
    required double distanceMeters,
  }) {
    if (!observerElevationMeters.isFinite ||
        !terrainElevationMeters.isFinite ||
        !distanceMeters.isFinite ||
        distanceMeters <= 0) {
      throw ArgumentError('Invalid elevation sample or distance.');
    }
    // Sagitta approximation d² / 2R (error negligible for ranges <= 60 km).
    final drop = distanceMeters * distanceMeters / (2 * earthRadiusMeters);
    return math.atan2(
          terrainElevationMeters - observerElevationMeters - drop,
          distanceMeters,
        ) /
        _toRadians;
  }

  static Future<TerrainHorizonProfile> calculate({
    required ObservingLocation site,
    required TerrainElevationProvider provider,
    required TerrainHorizonOptions options,
    DateTime? nowUtc,
  }) async {
    site.validate();
    options.validate();
    final points = <TerrainPoint>[];
    final distances = <double>[];
    final origin = TerrainPoint(site.latitude, site.longitude);
    for (var az = 0; az < 360; az += options.azimuthStepDegrees) {
      for (var sample = 1; sample <= options.samplesPerBearing; sample++) {
        final distance = math
            .min(
              sample * options.distanceStepMeters,
              options.maximumDistanceMeters,
            )
            .toDouble();
        points.add(destination(origin, az.toDouble(), distance));
        distances.add(distance);
      }
    }
    final heights = await provider.elevations(points);
    if (heights.length != points.length) {
      throw const FormatException(
        'Elevation provider returned an unexpected point count.',
      );
    }
    final bearings = <TerrainBearing>[];
    final steps = options.samplesPerBearing;
    for (var i = 0; i < options.bearingCount; i++) {
      double? bestAltitude;
      double? bestDistance;
      var completeRay = true;
      for (var j = 0; j < steps; j++) {
        final index = i * steps + j;
        final height = heights[index];
        if (height == null || !height.isFinite) {
          completeRay = false;
          continue;
        }
        final angle = elevationAngleDegrees(
          observerElevationMeters: site.elevationMeters,
          terrainElevationMeters: height,
          distanceMeters: distances[index],
        );
        if (bestAltitude == null || angle > bestAltitude) {
          bestAltitude = angle;
          bestDistance = distances[index];
        }
      }
      bearings.add(
        TerrainBearing(
          azimuthDegrees: i * options.azimuthStepDegrees.toDouble(),
          altitudeDegrees: completeRay ? bestAltitude : null,
          distanceMeters: completeRay ? bestDistance : null,
        ),
      );
    }
    return TerrainHorizonProfile(
      sourceId: provider.id,
      createdAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
      latitude: site.latitude,
      longitude: site.longitude,
      observerElevationMeters: site.elevationMeters,
      options: options,
      bearings: bearings,
    );
  }
}
