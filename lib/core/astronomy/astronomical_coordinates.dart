import 'dart:math' as math;

/// Mean equatorial coordinates, in degrees.
///
/// Right ascension: [0, 360)
/// Declination: [-90, 90]
final class EquatorialPosition {
  const EquatorialPosition({required this.raDegrees, required this.decDegrees});

  final double raDegrees;
  final double decDegrees;

  void validate() {
    if (!raDegrees.isFinite || raDegrees < 0 || raDegrees >= 360) {
      throw ArgumentError.value(
        raDegrees,
        'raDegrees',
        'Expected 0 <= RA < 360 degrees.',
      );
    }

    if (!decDegrees.isFinite || decDegrees < -90 || decDegrees > 90) {
      throw ArgumentError.value(
        decDegrees,
        'decDegrees',
        'Expected -90 <= Dec <= 90 degrees.',
      );
    }
  }
}

/// Geographic observing position.
///
/// East longitude is positive; west longitude is negative.
/// Elevation is retained for future atmospheric models.
final class ObserverPosition {
  const ObserverPosition({
    required this.latitudeDegrees,
    required this.longitudeDegrees,
    this.elevationMeters = 0,
  });

  final double latitudeDegrees;
  final double longitudeDegrees;
  final double elevationMeters;

  void validate() {
    if (!latitudeDegrees.isFinite ||
        latitudeDegrees < -90 ||
        latitudeDegrees > 90) {
      throw ArgumentError.value(
        latitudeDegrees,
        'latitudeDegrees',
        'Latitude must be between -90 and 90.',
      );
    }

    if (!longitudeDegrees.isFinite ||
        longitudeDegrees < -180 ||
        longitudeDegrees > 180) {
      throw ArgumentError.value(
        longitudeDegrees,
        'longitudeDegrees',
        'Longitude must be between -180 and 180.',
      );
    }

    if (!elevationMeters.isFinite) {
      throw ArgumentError.value(
        elevationMeters,
        'elevationMeters',
        'Elevation must be finite.',
      );
    }
  }
}

/// Geometric horizontal coordinates.
///
/// Azimuth convention:
/// 0 = North, 90 = East, 180 = South, 270 = West.
///
/// Azimuth is null at the exact zenith and nadir because
/// a compass direction is geometrically undefined there.
final class HorizontalPosition {
  const HorizontalPosition({
    required this.altitudeDegrees,
    required this.azimuthDegrees,
  });

  final double altitudeDegrees;
  final double? azimuthDegrees;

  double get zenithDistanceDegrees => 90 - altitudeDegrees;

  bool get isAboveHorizon => altitudeDegrees > 0;

  double? get relativeAirmass =>
      AstronomicalCoordinates.relativeAirmass(altitudeDegrees);
}

/// Result for one catalog position, observer and instant.
final class AstronomicalPositionResult {
  const AstronomicalPositionResult({
    required this.utc,
    required this.julianDate,
    required this.greenwichSiderealDegrees,
    required this.localSiderealDegrees,
    required this.hourAngleDegrees,
    required this.meanEquatorialOfDate,
    required this.horizontal,
  });

  final DateTime utc;
  final double julianDate;
  final double greenwichSiderealDegrees;
  final double localSiderealDegrees;
  final double hourAngleDegrees;
  final EquatorialPosition meanEquatorialOfDate;
  final HorizontalPosition horizontal;
}

/// Pure astronomical calculation functions.
///
/// Working assumptions:
/// - Input celestial positions are mean equatorial J2000.
/// - UTC approximates UT1 for sidereal time.
/// - IAU 1976 precession produces mean coordinates of date.
/// - Local MEAN sidereal time is used consistently.
/// - No nutation, proper motion, annual aberration, parallax,
///   refraction or local horizon model is applied.
abstract final class AstronomicalCoordinates {
  static const double j2000JulianDate = 2451545.0;

  static const double _degToRad = math.pi / 180;
  static const double _radToDeg = 180 / math.pi;

  static double _radians(double degrees) => degrees * _degToRad;

  static double _degrees(double radians) => radians * _radToDeg;

  static double _clampUnit(double value) => value.clamp(-1.0, 1.0).toDouble();

  static double normalizeDegrees(double degrees) {
    if (!degrees.isFinite) {
      throw ArgumentError.value(degrees, 'degrees', 'Angle must be finite.');
    }

    final result = degrees % 360.0;
    return result < 0 ? result + 360.0 : result;
  }

  /// Signed angle in [-180, 180) degrees.
  static double normalizeSignedDegrees(double degrees) {
    final result = normalizeDegrees(degrees);
    return result >= 180 ? result - 360 : result;
  }

  /// JD derived from a UTC-based Unix timestamp.
  ///
  /// DateTime represents an instant, so local and UTC
  /// DateTime objects for that instant yield the same JD.
  static double julianDate(DateTime time) {
    return time.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
  }

  /// Greenwich Mean Sidereal Time in degrees.
  ///
  /// Classical mean sidereal time polynomial.
  /// UTC is used as an approximation of UT1.
  static double greenwichMeanSiderealDegrees(DateTime time) {
    final jd = julianDate(time);
    final t = (jd - j2000JulianDate) / 36525.0;

    final degrees =
        280.46061837 +
        360.98564736629 * (jd - j2000JulianDate) +
        0.000387933 * t * t -
        (t * t * t) / 38710000.0;

    return normalizeDegrees(degrees);
  }

  /// Local Mean Sidereal Time, east longitude positive.
  static double localMeanSiderealDegrees(
    DateTime time,
    double longitudeDegrees,
  ) {
    if (!longitudeDegrees.isFinite ||
        longitudeDegrees < -180 ||
        longitudeDegrees > 180) {
      throw ArgumentError.value(
        longitudeDegrees,
        'longitudeDegrees',
        'Longitude must be between -180 and 180.',
      );
    }

    return normalizeDegrees(
      greenwichMeanSiderealDegrees(time) + longitudeDegrees,
    );
  }

  /// Hour angle in [-180, 180) degrees.
  ///
  /// Negative: east of meridian.
  /// Positive: west of meridian.
  static double hourAngleDegrees({
    required double localSiderealDegrees,
    required double rightAscensionDegrees,
  }) {
    if (!localSiderealDegrees.isFinite || !rightAscensionDegrees.isFinite) {
      throw ArgumentError('Sidereal time and RA must be finite.');
    }

    return normalizeSignedDegrees(localSiderealDegrees - rightAscensionDegrees);
  }

  /// Precess mean equatorial J2000 coordinates to the
  /// mean equator and equinox of the supplied date.
  ///
  /// IAU 1976 / Lieske model, with the J2000 epoch
  /// as the starting point.
  static EquatorialPosition precessJ2000ToDate({
    required EquatorialPosition j2000,
    required DateTime time,
  }) {
    j2000.validate();

    final t = (julianDate(time) - j2000JulianDate) / 36525.0;

    // Precession angles in arcseconds.
    final zetaArcsec = 2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t;

    final zArcsec = 2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t;

    final thetaArcsec = 2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t;

    final zeta = _radians(zetaArcsec / 3600);
    final z = _radians(zArcsec / 3600);
    final theta = _radians(thetaArcsec / 3600);

    final ra0 = _radians(j2000.raDegrees);
    final dec0 = _radians(j2000.decDegrees);

    final a = math.cos(dec0) * math.sin(ra0 + zeta);

    final b =
        math.cos(theta) * math.cos(dec0) * math.cos(ra0 + zeta) -
        math.sin(theta) * math.sin(dec0);

    final c =
        math.sin(theta) * math.cos(dec0) * math.cos(ra0 + zeta) +
        math.cos(theta) * math.sin(dec0);

    final ra = math.atan2(a, b) + z;
    final dec = math.atan2(c, math.sqrt(a * a + b * b));

    return EquatorialPosition(
      raDegrees: normalizeDegrees(_degrees(ra)),
      decDegrees: _degrees(dec),
    );
  }

  /// Transform mean equatorial coordinates OF DATE to
  /// geometric horizontal coordinates at the observer.
  ///
  /// Do not pass raw J2000 coordinates here unless
  /// intentionally omitting precession.
  static HorizontalPosition equatorialToHorizontal({
    required EquatorialPosition equatorialOfDate,
    required ObserverPosition observer,
    required DateTime time,
  }) {
    equatorialOfDate.validate();
    observer.validate();

    final lst = localMeanSiderealDegrees(time, observer.longitudeDegrees);

    final h = _radians(
      hourAngleDegrees(
        localSiderealDegrees: lst,
        rightAscensionDegrees: equatorialOfDate.raDegrees,
      ),
    );

    final dec = _radians(equatorialOfDate.decDegrees);

    final lat = _radians(observer.latitudeDegrees);

    // Unit-vector components in local ENU coordinates.
    final east = -math.cos(dec) * math.sin(h);

    final north =
        math.sin(dec) * math.cos(lat) -
        math.cos(dec) * math.sin(lat) * math.cos(h);

    final up =
        math.sin(dec) * math.sin(lat) +
        math.cos(dec) * math.cos(lat) * math.cos(h);

    final altitude = _degrees(math.asin(_clampUnit(up)));

    final horizontalLength = math.sqrt(east * east + north * north);

    final double? azimuth = horizontalLength < 1e-12
        ? null
        : normalizeDegrees(_degrees(math.atan2(east, north)));

    return HorizontalPosition(
      altitudeDegrees: altitude,
      azimuthDegrees: azimuth,
    );
  }

  /// Complete pipeline from catalog J2000 coordinates
  /// to the geometric position at one observing instant.
  static AstronomicalPositionResult calculateJ2000({
    required EquatorialPosition j2000,
    required ObserverPosition observer,
    required DateTime time,
  }) {
    j2000.validate();
    observer.validate();

    final utc = time.toUtc();
    final equatorial = precessJ2000ToDate(j2000: j2000, time: utc);

    final gmst = greenwichMeanSiderealDegrees(utc);
    final lst = localMeanSiderealDegrees(utc, observer.longitudeDegrees);

    final hourAngle = hourAngleDegrees(
      localSiderealDegrees: lst,
      rightAscensionDegrees: equatorial.raDegrees,
    );

    final horizontal = equatorialToHorizontal(
      equatorialOfDate: equatorial,
      observer: observer,
      time: utc,
    );

    return AstronomicalPositionResult(
      utc: utc,
      julianDate: julianDate(utc),
      greenwichSiderealDegrees: gmst,
      localSiderealDegrees: lst,
      hourAngleDegrees: hourAngle,
      meanEquatorialOfDate: equatorial,
      horizontal: horizontal,
    );
  }

  /// Great-circle separation between two equatorial
  /// coordinate pairs, in degrees.
  ///
  /// Uses the haversine formula for good stability
  /// even for small separations and RA wraparound.
  static double angularSeparationDegrees(
    EquatorialPosition first,
    EquatorialPosition second,
  ) {
    first.validate();
    second.validate();

    final dec1 = _radians(first.decDegrees);
    final dec2 = _radians(second.decDegrees);

    final deltaDec = dec2 - dec1;
    final deltaRa = _radians(second.raDegrees - first.raDegrees);

    final sinHalfDec = math.sin(deltaDec / 2);
    final sinHalfRa = math.sin(deltaRa / 2);

    final haversine =
        sinHalfDec * sinHalfDec +
        math.cos(dec1) * math.cos(dec2) * sinHalfRa * sinHalfRa;

    final bounded = haversine.clamp(0.0, 1.0).toDouble();

    return _degrees(2 * math.asin(math.sqrt(bounded)));
  }

  /// Approximate relative optical airmass using
  /// Kasten-Young (1989).
  ///
  /// Returns null below or exactly at the geometric
  /// horizon. It is an approximation, not a measurement
  /// of local atmospheric transparency.
  static double? relativeAirmass(double altitudeDegrees) {
    if (!altitudeDegrees.isFinite ||
        altitudeDegrees < -90 ||
        altitudeDegrees > 90) {
      throw ArgumentError.value(
        altitudeDegrees,
        'altitudeDegrees',
        'Altitude must be between -90 and 90.',
      );
    }

    if (altitudeDegrees <= 0) {
      return null;
    }

    final denominator =
        math.sin(_radians(altitudeDegrees)) +
        0.50572 * math.pow(altitudeDegrees + 6.07995, -1.6364);

    return math.max(1.0, 1.0 / denominator);
  }
}
