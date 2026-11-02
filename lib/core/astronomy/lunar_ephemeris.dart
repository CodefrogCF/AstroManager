// Lunar position model and Meeus Chapter 47 periodic-term data adapted from
// Sonia Keys, meeus/v3/moonposition/moonposition.go, MIT License (2013).
// https://github.com/soniakeys/meeus/blob/master/v3/moonposition/moonposition.go
// See docs/data-sources.md for attribution and model limitations.
import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../../features/locations/domain/models/observing_location.dart';
import 'astronomical_coordinates.dart';
import 'solar_events.dart';

const _radiansPerDegree = math.pi / 180.0;
const _degreesPerRadian = 180.0 / math.pi;
const _earthEquatorialRadiusKm = 6378.14;
const _moonRadiusKm = 1737.4;

/// Phase sectors by synodic elongation (0 = new, 0.5 = full).
enum LunarPhase {
  newMoon('New Moon'),
  waxingCrescent('Waxing Crescent'),
  firstQuarter('First Quarter'),
  waxingGibbous('Waxing Gibbous'),
  fullMoon('Full Moon'),
  waningGibbous('Waning Gibbous'),
  lastQuarter('Last Quarter'),
  waningCrescent('Waning Crescent');

  const LunarPhase(this.label);
  final String label;
}

/// The Moon's position and illumination at an absolute UTC instant.
///
/// [geocentricEquatorial] and [topocentricEquatorial] use mean equator/equinox
/// of date; never feed these through J2000 precession a second time.
final class LunarPosition {
  const LunarPosition({
    required this.utc,
    required this.geocentricEquatorial,
    required this.topocentricEquatorial,
    required this.horizontal,
    required this.eclipticLongitudeDegrees,
    required this.eclipticLatitudeDegrees,
    required this.distanceKilometers,
    required this.illuminationFraction,
    required this.phaseFraction,
    required this.phase,
    required this.elongationDegrees,
  });

  final DateTime utc;
  final EquatorialPosition geocentricEquatorial;
  final EquatorialPosition topocentricEquatorial;
  final HorizontalPosition horizontal;
  final double eclipticLongitudeDegrees;
  final double eclipticLatitudeDegrees;
  final double distanceKilometers;
  final double illuminationFraction;
  final double phaseFraction;
  final LunarPhase phase;
  final double elongationDegrees;
}

/// Snapshot for evaluating moonlight risk for a catalog target.
/// The angular separation is observer-dependent because the Moon's
/// significant parallax is included.
final class LunarConditions {
  const LunarConditions({
    required this.moon,
    required this.targetSeparationDegrees,
  });

  final LunarPosition moon;
  final double targetSeparationDegrees;
}

/// A rise or set crossing. UTC remains the source of truth across DST.
final class LunarEvent {
  const LunarEvent({
    required this.utc,
    required this.local,
    required this.isRise,
  });

  final DateTime utc;
  final tz.TZDateTime local;
  final bool isRise;
}

enum LunarCrossingState { crossings, alwaysAbove, alwaysBelow }

/// All crossings in the requested local day or observation-night window.
/// A window can contain only a rise, only a set, both or neither.
final class LunarEventWindow {
  LunarEventWindow({
    required this.startUtc,
    required this.endUtc,
    required this.timeZone,
    required this.state,
    required List<LunarEvent> events,
  }) : events = List.unmodifiable(events);

  final DateTime startUtc;
  final DateTime endUtc;
  final String timeZone;
  final LunarCrossingState state;
  final List<LunarEvent> events;

  LunarEvent? get moonrise {
    for (final event in events) {
      if (event.isRise) return event;
    }
    return null;
  }

  LunarEvent? get moonset {
    for (final event in events) {
      if (!event.isRise) return event;
    }
    return null;
  }
}

/// Pure, offline lunar computations. No persistent data or network access.
///
/// The Meeus lunar series provides *geocentric mean ecliptic of date* values.
/// The local horizon calculation subtracts the observer's geocentric position
/// (topocentric parallax). Refraction is used ONLY as an event threshold.
abstract final class LunarEphemeris {
  static const _step = Duration(minutes: 5);

  static double _rad(double degrees) => degrees * _radiansPerDegree;
  static double _deg(double radians) => radians * _degreesPerRadian;
  static double _sin(double degrees) => math.sin(_rad(degrees));
  static double _cos(double degrees) => math.cos(_rad(degrees));
  static double _norm(double degrees) =>
      AstronomicalCoordinates.normalizeDegrees(degrees);

  /// Moon position for any instant and observer; input DateTime zone is ignored
  /// because DateTime represents an absolute instant.
  static LunarPosition positionAt({
    required DateTime at,
    required ObserverPosition observer,
  }) {
    observer.validate();
    final utc = at.toUtc();
    final jd = AstronomicalCoordinates.julianDate(utc);
    // UTC approximates TT in this planning-oriented implementation.
    final t = (jd - AstronomicalCoordinates.j2000JulianDate) / 36525;

    final lp = _norm(
      218.3164477 +
          t *
              (481267.88123421 +
                  t * (-0.0015786 + t * (1 / 538841 - t / 65194000))),
    );
    final d = _norm(
      297.8501921 +
          t *
              (445267.1114034 +
                  t * (-0.0018819 + t * (1 / 545868 - t / 113065000))),
    );
    final m = _norm(
      357.5291092 + t * (35999.0502909 + t * (-0.0001535 + t / 24490000)),
    );
    final mp = _norm(
      134.9633964 +
          t *
              (477198.8675055 +
                  t * (0.0087414 + t * (1 / 69699 - t / 14712000))),
    );
    final f = _norm(
      93.272095 +
          t *
              (483202.0175233 +
                  t * (-0.0036539 + t * (-1 / 3526000 + t / 863310000))),
    );
    final a1 = 119.75 + 131.849 * t;
    final a2 = 53.09 + 479264.290 * t;
    final a3 = 313.45 + 481266.484 * t;
    final e = 1 - 0.002516 * t - 0.0000074 * t * t;

    var longitudeSum = 3958 * _sin(a1) + 1962 * _sin(lp - f) + 318 * _sin(a2);
    var radiusSum = 0.0;
    for (final term in _longitudeDistanceTerms) {
      final phase = term.d * d + term.m * m + term.mp * mp + term.f * f;
      final weight = math.pow(e, term.m.abs()).toDouble();
      longitudeSum += term.longitude.toDouble() * weight * _sin(phase);
      radiusSum += term.radius.toDouble() * weight * _cos(phase);
    }
    var latitudeSum =
        -2235 * _sin(lp) +
        382 * _sin(a3) +
        175 * _sin(a1 - f) +
        175 * _sin(a1 + f) +
        127 * _sin(lp - mp) -
        115 * _sin(lp + mp);
    for (final term in _latitudeTerms) {
      final phase = term.d * d + term.m * m + term.mp * mp + term.f * f;
      latitudeSum +=
          term.latitude.toDouble() *
          math.pow(e, term.m.abs()).toDouble() *
          _sin(phase);
    }

    final lambda = _norm(lp + longitudeSum / 1000000);
    final beta = latitudeSum / 1000000;
    final distance = 385000.56 + radiusSum / 1000;
    final epsilon = _meanObliquity(t);
    final lambdaRad = _rad(lambda);
    final betaRad = _rad(beta);
    final epsilonRad = _rad(epsilon);
    final x = math.cos(betaRad) * math.cos(lambdaRad);
    final y =
        math.cos(betaRad) * math.sin(lambdaRad) * math.cos(epsilonRad) -
        math.sin(betaRad) * math.sin(epsilonRad);
    final z =
        math.cos(betaRad) * math.sin(lambdaRad) * math.sin(epsilonRad) +
        math.sin(betaRad) * math.cos(epsilonRad);
    final equatorial = EquatorialPosition(
      raDegrees: _norm(_deg(math.atan2(y, x))),
      decDegrees: _deg(math.atan2(z, math.sqrt(x * x + y * y))),
    );

    final sidereal = AstronomicalCoordinates.localMeanSiderealDegrees(
      utc,
      observer.longitudeDegrees,
    );
    final hourAngle = _rad(
      AstronomicalCoordinates.hourAngleDegrees(
        localSiderealDegrees: sidereal,
        rightAscensionDegrees: equatorial.raDegrees,
      ),
    );
    final declination = _rad(equatorial.decDegrees);
    final latitude = _rad(observer.latitudeDegrees);
    // Geodetic to geocentric observer coordinates, in Earth radii.
    final u = math.atan(0.99664719 * math.tan(latitude));
    final rhoSin =
        0.99664719 * math.sin(u) +
        observer.elevationMeters /
            1000 /
            _earthEquatorialRadiusKm *
            math.sin(latitude);
    final rhoCos =
        math.cos(u) +
        observer.elevationMeters /
            1000 /
            _earthEquatorialRadiusKm *
            math.cos(latitude);
    final xTopo =
        distance * math.cos(declination) * math.cos(hourAngle) -
        _earthEquatorialRadiusKm * rhoCos;
    final yTopo = -distance * math.cos(declination) * math.sin(hourAngle);
    final zTopo =
        distance * math.sin(declination) - _earthEquatorialRadiusKm * rhoSin;
    final decTopo = math.atan2(zTopo, math.sqrt(xTopo * xTopo + yTopo * yTopo));
    final hourAngleTopo = math.atan2(-yTopo, xTopo);
    final equatorialTopo = EquatorialPosition(
      raDegrees: _norm(sidereal - _deg(hourAngleTopo)),
      decDegrees: _deg(decTopo),
    );
    final horizontal = AstronomicalCoordinates.equatorialToHorizontal(
      equatorialOfDate: equatorialTopo,
      observer: observer,
      time: utc,
    );

    final sun = SolarEvents.sunEquatorialPosition(utc);
    final separation = AstronomicalCoordinates.angularSeparationDegrees(
      equatorial,
      sun,
    );
    final cosElongation = _cos(separation);
    final sunDistanceKm = 149597870.7;
    final illuminationCosine =
        (distance - sunDistanceKm * cosElongation) /
        math.sqrt(
          sunDistanceKm * sunDistanceKm +
              distance * distance -
              2 * sunDistanceKm * distance * cosElongation,
        );
    final illuminated = ((1 + illuminationCosine) / 2)
        .clamp(0.0, 1.0)
        .toDouble();
    // Derive the Sun's mean ecliptic longitude in the same frame as the Moon.
    final sunRa = _rad(sun.raDegrees);
    final sunDec = _rad(sun.decDegrees);
    final sunLon = _norm(
      _deg(
        math.atan2(
          math.sin(sunRa) * math.cos(sunDec) * math.cos(epsilonRad) +
              math.sin(sunDec) * math.sin(epsilonRad),
          math.cos(sunRa) * math.cos(sunDec),
        ),
      ),
    );
    final phaseFraction = _norm(lambda - sunLon) / 360;
    final phase = LunarPhase.values[((phaseFraction * 8 + 0.5).floor()) % 8];

    return LunarPosition(
      utc: utc,
      geocentricEquatorial: equatorial,
      topocentricEquatorial: equatorialTopo,
      horizontal: horizontal,
      eclipticLongitudeDegrees: lambda,
      eclipticLatitudeDegrees: beta,
      distanceKilometers: distance,
      illuminationFraction: illuminated,
      phaseFraction: phaseFraction,
      phase: phase,
      elongationDegrees: separation,
    );
  }

  /// Angular distance on the observer's sky, using the Moon's topocentric
  /// position and the catalog target's mean J2000 coordinates precessed to date.
  static LunarConditions conditionsForTarget({
    required DateTime at,
    required ObserverPosition observer,
    required EquatorialPosition targetJ2000,
  }) {
    targetJ2000.validate();
    final moon = positionAt(at: at, observer: observer);
    final targetOfDate = AstronomicalCoordinates.precessJ2000ToDate(
      j2000: targetJ2000,
      time: at,
    );
    return LunarConditions(
      moon: moon,
      targetSeparationDegrees: AstronomicalCoordinates.angularSeparationDegrees(
        moon.topocentricEquatorial,
        targetOfDate,
      ),
    );
  }

  /// Events in a local civil day (midnight to next midnight), respecting DST.
  static LunarEventWindow calculateForLocalDate({
    required ObservingLocation location,
    required DateTime localDate,
  }) {
    location.validate();
    final zone = SolarEvents.timeZone(location.timeZone);
    final start = tz.TZDateTime(
      zone,
      localDate.year,
      localDate.month,
      localDate.day,
    );
    final end = tz.TZDateTime(
      zone,
      localDate.year,
      localDate.month,
      localDate.day + 1,
    );
    return _scan(location, zone, start.toUtc(), end.toUtc());
  }

  /// Events across the observing night (local noon to following local noon).
  static LunarEventWindow calculateForObservingNight({
    required ObservingLocation location,
    required DateTime localDate,
  }) {
    location.validate();
    final zone = SolarEvents.timeZone(location.timeZone);
    final start = tz.TZDateTime(
      zone,
      localDate.year,
      localDate.month,
      localDate.day,
      12,
    );
    final end = tz.TZDateTime(
      zone,
      localDate.year,
      localDate.month,
      localDate.day + 1,
      12,
    );
    return _scan(location, zone, start.toUtc(), end.toUtc());
  }

  static LunarEventWindow _scan(
    ObservingLocation location,
    tz.Location zone,
    DateTime startUtc,
    DateTime endUtc,
  ) {
    final observer = ObserverPosition(
      latitudeDegrees: location.latitude,
      longitudeDegrees: location.longitude,
      elevationMeters: location.elevationMeters,
    );
    // At apparent top-limb contact: topocentric geometric center equals
    // -(standard refraction + angular semidiameter). Terrain is ignored.
    double difference(DateTime at) {
      final position = positionAt(at: at, observer: observer);
      final semidiameterDegrees = _deg(
        math.asin(_moonRadiusKm / position.distanceKilometers),
      );
      return position.horizontal.altitudeDegrees + 0.5667 + semidiameterDegrees;
    }

    final crossings = <LunarEvent>[];
    var left = startUtc;
    var leftValue = difference(left);
    final beginsAbove = leftValue >= 0;
    while (left.isBefore(endUtc)) {
      final candidate = left.add(_step);
      final right = candidate.isBefore(endUtc) ? candidate : endUtc;
      final rightValue = difference(right);
      if ((leftValue < 0 && rightValue >= 0) ||
          (leftValue >= 0 && rightValue < 0)) {
        final rising = leftValue < 0;
        var low = left.millisecondsSinceEpoch;
        var high = right.millisecondsSinceEpoch;
        while (high - low > 1000) {
          final mid = low + (high - low) ~/ 2;
          final midValue = difference(
            DateTime.fromMillisecondsSinceEpoch(mid, isUtc: true),
          );
          if ((midValue >= 0) == rising) {
            high = mid;
          } else {
            low = mid;
          }
        }
        final utc = DateTime.fromMillisecondsSinceEpoch(
          low + (high - low) ~/ 2,
          isUtc: true,
        );
        crossings.add(
          LunarEvent(
            utc: utc,
            local: tz.TZDateTime.from(utc, zone),
            isRise: rising,
          ),
        );
      }
      left = right;
      leftValue = rightValue;
    }
    return LunarEventWindow(
      startUtc: startUtc,
      endUtc: endUtc,
      timeZone: location.timeZone,
      events: crossings,
      state: crossings.isNotEmpty
          ? LunarCrossingState.crossings
          : beginsAbove
          ? LunarCrossingState.alwaysAbove
          : LunarCrossingState.alwaysBelow,
    );
  }

  static double _meanObliquity(double t) {
    final arcseconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813));
    return 23 + (26 + arcseconds / 60) / 60;
  }
}

final class _LongitudeDistanceTerm {
  const _LongitudeDistanceTerm(
    this.d,
    this.m,
    this.mp,
    this.f,
    this.longitude,
    this.radius,
  );
  final int d;
  final int m;
  final int mp;
  final int f;
  final int longitude;
  final int radius;
}

final class _LatitudeTerm {
  const _LatitudeTerm(this.d, this.m, this.mp, this.f, this.latitude);
  final int d;
  final int m;
  final int mp;
  final int f;
  final int latitude;
}

// Meeus Table 47.A, longitude (microdegrees) / distance (millikilometers).
const _longitudeDistanceTerms = <_LongitudeDistanceTerm>[
  _LongitudeDistanceTerm(0, 0, 1, 0, 6288774, -20905355),
  _LongitudeDistanceTerm(2, 0, -1, 0, 1274027, -3699111),
  _LongitudeDistanceTerm(2, 0, 0, 0, 658314, -2955968),
  _LongitudeDistanceTerm(0, 0, 2, 0, 213618, -569925),
  _LongitudeDistanceTerm(0, 1, 0, 0, -185116, 48888),
  _LongitudeDistanceTerm(0, 0, 0, 2, -114332, -3149),
  _LongitudeDistanceTerm(2, 0, -2, 0, 58793, 246158),
  _LongitudeDistanceTerm(2, -1, -1, 0, 57066, -152138),
  _LongitudeDistanceTerm(2, 0, 1, 0, 53322, -170733),
  _LongitudeDistanceTerm(2, -1, 0, 0, 45758, -204586),
  _LongitudeDistanceTerm(0, 1, -1, 0, -40923, -129620),
  _LongitudeDistanceTerm(1, 0, 0, 0, -34720, 108743),
  _LongitudeDistanceTerm(0, 1, 1, 0, -30383, 104755),
  _LongitudeDistanceTerm(2, 0, 0, -2, 15327, 10321),
  _LongitudeDistanceTerm(0, 0, 1, 2, -12528, 0),
  _LongitudeDistanceTerm(0, 0, 1, -2, 10980, 79661),
  _LongitudeDistanceTerm(4, 0, -1, 0, 10675, -34782),
  _LongitudeDistanceTerm(0, 0, 3, 0, 10034, -23210),
  _LongitudeDistanceTerm(4, 0, -2, 0, 8548, -21636),
  _LongitudeDistanceTerm(2, 1, -1, 0, -7888, 24208),
  _LongitudeDistanceTerm(2, 1, 0, 0, -6766, 30824),
  _LongitudeDistanceTerm(1, 0, -1, 0, -5163, -8379),
  _LongitudeDistanceTerm(1, 1, 0, 0, 4987, -16675),
  _LongitudeDistanceTerm(2, -1, 1, 0, 4036, -12831),
  _LongitudeDistanceTerm(2, 0, 2, 0, 3994, -10445),
  _LongitudeDistanceTerm(4, 0, 0, 0, 3861, -11650),
  _LongitudeDistanceTerm(2, 0, -3, 0, 3665, 14403),
  _LongitudeDistanceTerm(0, 1, -2, 0, -2689, -7003),
  _LongitudeDistanceTerm(2, 0, -1, 2, -2602, 0),
  _LongitudeDistanceTerm(2, -1, -2, 0, 2390, 10056),
  _LongitudeDistanceTerm(1, 0, 1, 0, -2348, 6322),
  _LongitudeDistanceTerm(2, -2, 0, 0, 2236, -9884),
  _LongitudeDistanceTerm(0, 1, 2, 0, -2120, 5751),
  _LongitudeDistanceTerm(0, 2, 0, 0, -2069, 0),
  _LongitudeDistanceTerm(2, -2, -1, 0, 2048, -4950),
  _LongitudeDistanceTerm(2, 0, 1, -2, -1773, 4130),
  _LongitudeDistanceTerm(2, 0, 0, 2, -1595, 0),
  _LongitudeDistanceTerm(4, -1, -1, 0, 1215, -3958),
  _LongitudeDistanceTerm(0, 0, 2, 2, -1110, 0),
  _LongitudeDistanceTerm(3, 0, -1, 0, -892, 3258),
  _LongitudeDistanceTerm(2, 1, 1, 0, -810, 2616),
  _LongitudeDistanceTerm(4, -1, -2, 0, 759, -1897),
  _LongitudeDistanceTerm(0, 2, -1, 0, -713, -2117),
  _LongitudeDistanceTerm(2, 2, -1, 0, -700, 2354),
  _LongitudeDistanceTerm(2, 1, -2, 0, 691, 0),
  _LongitudeDistanceTerm(2, -1, 0, -2, 596, 0),
  _LongitudeDistanceTerm(4, 0, 1, 0, 549, -1423),
  _LongitudeDistanceTerm(0, 0, 4, 0, 537, -1117),
  _LongitudeDistanceTerm(4, -1, 0, 0, 520, -1571),
  _LongitudeDistanceTerm(1, 0, -2, 0, -487, -1739),
  _LongitudeDistanceTerm(2, 1, 0, -2, -399, 0),
  _LongitudeDistanceTerm(0, 0, 2, -2, -381, -4421),
  _LongitudeDistanceTerm(1, 1, 1, 0, 351, 0),
  _LongitudeDistanceTerm(3, 0, -2, 0, -340, 0),
  _LongitudeDistanceTerm(4, 0, -3, 0, 330, 0),
  _LongitudeDistanceTerm(2, -1, 2, 0, 327, 0),
  _LongitudeDistanceTerm(0, 2, 1, 0, -323, 1165),
  _LongitudeDistanceTerm(1, 1, -1, 0, 299, 0),
  _LongitudeDistanceTerm(2, 0, 3, 0, 294, 0),
  _LongitudeDistanceTerm(2, 0, -1, -2, 0, 8752),
];

// Meeus Table 47.B, ecliptic latitude (microdegrees).
const _latitudeTerms = <_LatitudeTerm>[
  _LatitudeTerm(0, 0, 0, 1, 5128122),
  _LatitudeTerm(0, 0, 1, 1, 280602),
  _LatitudeTerm(0, 0, 1, -1, 277693),
  _LatitudeTerm(2, 0, 0, -1, 173237),
  _LatitudeTerm(2, 0, -1, 1, 55413),
  _LatitudeTerm(2, 0, -1, -1, 46271),
  _LatitudeTerm(2, 0, 0, 1, 32573),
  _LatitudeTerm(0, 0, 2, 1, 17198),
  _LatitudeTerm(2, 0, 1, -1, 9266),
  _LatitudeTerm(0, 0, 2, -1, 8822),
  _LatitudeTerm(2, -1, 0, -1, 8216),
  _LatitudeTerm(2, 0, -2, -1, 4324),
  _LatitudeTerm(2, 0, 1, 1, 4200),
  _LatitudeTerm(2, 1, 0, -1, -3359),
  _LatitudeTerm(2, -1, -1, 1, 2463),
  _LatitudeTerm(2, -1, 0, 1, 2211),
  _LatitudeTerm(2, -1, -1, -1, 2065),
  _LatitudeTerm(0, 1, -1, -1, -1870),
  _LatitudeTerm(4, 0, -1, -1, 1828),
  _LatitudeTerm(0, 1, 0, 1, -1794),
  _LatitudeTerm(0, 0, 0, 3, -1749),
  _LatitudeTerm(0, 1, -1, 1, -1565),
  _LatitudeTerm(1, 0, 0, 1, -1491),
  _LatitudeTerm(0, 1, 1, 1, -1475),
  _LatitudeTerm(0, 1, 1, -1, -1410),
  _LatitudeTerm(0, 1, 0, -1, -1344),
  _LatitudeTerm(1, 0, 0, -1, -1335),
  _LatitudeTerm(0, 0, 3, 1, 1107),
  _LatitudeTerm(4, 0, 0, -1, 1021),
  _LatitudeTerm(4, 0, -1, 1, 833),
  _LatitudeTerm(0, 0, 1, -3, 777),
  _LatitudeTerm(4, 0, -2, 1, 671),
  _LatitudeTerm(2, 0, 0, -3, 607),
  _LatitudeTerm(2, 0, 2, -1, 596),
  _LatitudeTerm(2, -1, 1, -1, 491),
  _LatitudeTerm(2, 0, -2, 1, -451),
  _LatitudeTerm(0, 0, 3, -1, 439),
  _LatitudeTerm(2, 0, 2, 1, 422),
  _LatitudeTerm(2, 0, -3, -1, 421),
  _LatitudeTerm(2, 1, -1, 1, -366),
  _LatitudeTerm(2, 1, 0, 1, -351),
  _LatitudeTerm(4, 0, 0, 1, 331),
  _LatitudeTerm(2, -1, 1, 1, 315),
  _LatitudeTerm(2, -2, 0, -1, 302),
  _LatitudeTerm(0, 0, 1, 3, -283),
  _LatitudeTerm(2, 1, 1, -1, -229),
  _LatitudeTerm(1, 1, 0, -1, 223),
  _LatitudeTerm(1, 1, 0, 1, 223),
  _LatitudeTerm(0, 1, -2, -1, -220),
  _LatitudeTerm(2, 1, -1, -1, -220),
  _LatitudeTerm(1, 0, 1, 1, -185),
  _LatitudeTerm(2, -1, -2, -1, 181),
  _LatitudeTerm(0, 1, 2, 1, -177),
  _LatitudeTerm(4, 0, -2, -1, 176),
  _LatitudeTerm(4, -1, -1, -1, 166),
  _LatitudeTerm(1, 0, 1, -1, -164),
  _LatitudeTerm(4, 0, 1, -1, 132),
  _LatitudeTerm(1, 0, -1, -1, -119),
  _LatitudeTerm(4, -1, 0, -1, 115),
  _LatitudeTerm(2, -2, 0, 1, 107),
];
