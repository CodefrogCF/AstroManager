import 'dart:math' as math;

import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../locations/domain/models/observing_location.dart';
import 'sky_atlas_models.dart';

/// Converts a local altitude/azimuth direction to the mean J2000 sky frame.
/// Azimuth: 0=N, 90=E, 180=S, 270=W.
abstract final class SkyDomeGeometry {
  static const double _rad = math.pi / 180;
  static const double _deg = 180 / math.pi;

  static SkyAtlasPosition horizontalToJ2000({
    required ObserverPosition observer,
    required DateTime utc,
    required double altitudeDegrees,
    required double azimuthDegrees,
  }) {
    observer.validate();
    if (!altitudeDegrees.isFinite ||
        altitudeDegrees < -90 ||
        altitudeDegrees > 90 ||
        !azimuthDegrees.isFinite) {
      throw ArgumentError('Invalid altitude or azimuth.');
    }

    final latitude = observer.latitudeDegrees * _rad;
    final altitude = altitudeDegrees * _rad;
    final azimuth = azimuthDegrees * _rad;
    final sinDec =
        math.sin(altitude) * math.sin(latitude) +
        math.cos(altitude) * math.cos(latitude) * math.cos(azimuth);
    final cosDecCosH =
        math.sin(altitude) * math.cos(latitude) -
        math.cos(altitude) * math.sin(latitude) * math.cos(azimuth);
    final cosDecSinH = -math.cos(altitude) * math.sin(azimuth);
    final hourAngle = math.atan2(cosDecSinH, cosDecCosH) * _deg;
    final dateRa = AstronomicalCoordinates.normalizeDegrees(
      AstronomicalCoordinates.localMeanSiderealDegrees(
            utc,
            observer.longitudeDegrees,
          ) -
          hourAngle,
    );
    final dateDec = math.asin(sinDec.clamp(-1.0, 1.0)) * _deg;
    return _meanOfDateToJ2000(raDegrees: dateRa, decDegrees: dateDec, utc: utc);
  }

  /// Inverse of the IAU 1976 J2000 -> mean-of-date precession implemented
  /// by AstronomicalCoordinates.precessJ2000ToDate().
  static SkyAtlasPosition _meanOfDateToJ2000({
    required double raDegrees,
    required double decDegrees,
    required DateTime utc,
  }) {
    final t =
        (AstronomicalCoordinates.julianDate(utc) -
            AstronomicalCoordinates.j2000JulianDate) /
        36525.0;
    final zeta =
        (2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600 * _rad;
    final z =
        (2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600 * _rad;
    final theta =
        (2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600 * _rad;
    final dateRa = raDegrees * _rad - z;
    final dateDec = decDegrees * _rad;
    final a = math.cos(dateDec) * math.sin(dateRa);
    final b = math.cos(dateDec) * math.cos(dateRa);
    final c = math.sin(dateDec);
    final x = math.cos(theta) * b + math.sin(theta) * c;
    final y = a;
    final w = -math.sin(theta) * b + math.cos(theta) * c;
    final ra = AstronomicalCoordinates.normalizeDegrees(
      (math.atan2(y, x) - zeta) * _deg,
    );
    final dec = math.atan2(w, math.sqrt(x * x + y * y)) * _deg;
    return SkyAtlasPosition(raDegrees: ra, decDegrees: dec);
  }

  static SkyDomeOverlay calculate({
    required ObservingLocation location,
    required DateTime utc,
    double minimumAltitudeDegrees = 25,
  }) {
    location.validate();
    if (!minimumAltitudeDegrees.isFinite ||
        minimumAltitudeDegrees < 0 ||
        minimumAltitudeDegrees > 80) {
      throw ArgumentError.value(
        minimumAltitudeDegrees,
        'minimumAltitudeDegrees',
      );
    }
    final observer = ObserverPosition(
      latitudeDegrees: location.latitude,
      longitudeDegrees: location.longitude,
      elevationMeters: location.elevationMeters,
    );
    SkyAtlasPosition direction(double alt, double az) => horizontalToJ2000(
      observer: observer,
      utc: utc,
      altitudeDegrees: alt,
      azimuthDegrees: az,
    );
    List<SkyAtlasPosition> ring(double altitude) => [
      for (var index = 0; index <= 120; index++)
        direction(altitude, index * 3.0),
    ];

    final cardinals = <SkyAtlasMarker>[
      for (final entry in const [
        (0.0, 'N'),
        (90.0, 'E'),
        (180.0, 'S'),
        (270.0, 'W'),
      ])
        SkyAtlasMarker(
          id: 'horizon-${entry.$2}',
          label: entry.$2,
          position: direction(2, entry.$1),
        ),
    ];

    return SkyDomeOverlay(
      zenith: direction(90, 0),
      horizon: ring(0),
      altitude30: ring(30),
      altitude60: ring(60),
      minimumAltitude: minimumAltitudeDegrees == 0
          ? const []
          : ring(minimumAltitudeDegrees),
      minimumAltitudeDegrees: minimumAltitudeDegrees,
      cardinals: cardinals,
    );
  }
}
