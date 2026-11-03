import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/astronomical_coordinates.dart';
import '../../../core/astronomy/lunar_ephemeris.dart';
import '../../../core/astronomy/solar_events.dart';
import '../../locations/domain/models/observing_location.dart';
import 'top_targets.dart';

enum TonightDarknessState { none, partial, continuous }

/// Local-noon to following-local-noon astronomical summary.
/// All interval arithmetic uses absolute UTC instants (including DST nights).
final class TonightConditions {
  const TonightConditions({
    required this.night,
    required this.sunset,
    required this.sunrise,
    required this.astronomicalDusk,
    required this.astronomicalDawn,
    required this.moon,
    required this.moonEvents,
    required this.darknessDuration,
    required this.darknessState,
  });

  final SolarDayEvents night;
  final SolarEvent? sunset;
  final SolarEvent? sunrise;
  final SolarEvent? astronomicalDusk;
  final SolarEvent? astronomicalDawn;
  final LunarPosition moon;
  final LunarEventWindow moonEvents;
  final Duration darknessDuration;
  final TonightDarknessState darknessState;

  DateTime get localDate => night.localDate;
  Duration get observationWindow =>
      night.nightEndUtc.difference(night.nightStartUtc);

  /// Only future parts of actual astronomical-darkness intervals are counted.
  Duration remainingDarknessAt(DateTime nowUtc) {
    final now = nowUtc.toUtc();
    var microseconds = 0;
    for (final interval in night.astronomicalDarkness) {
      final start = now.isAfter(interval.startUtc) ? now : interval.startUtc;
      if (interval.endUtc.isAfter(start)) {
        microseconds += interval.endUtc.difference(start).inMicroseconds;
      }
    }
    return Duration(microseconds: microseconds);
  }
}

/// Uses the same local-night policy and ephemerides as Discovery and Planner.
/// This calculation is entirely offline and independent of weather requests.
abstract final class TonightConditionsCalculator {
  static DateTime currentNight(ObservingLocation location, DateTime nowUtc) =>
      DashboardTargetSelection.currentNight(location, nowUtc.toUtc());

  static TonightConditions calculate({
    required ObservingLocation location,
    required DateTime localDate,
  }) {
    location.validate();
    final day = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: localDate,
    );
    final followingDay = SolarEvents.calculateForLocalDate(
      location: location,
      localDate: DateTime.utc(
        localDate.year,
        localDate.month,
        localDate.day + 1,
      ),
    );

    SolarEvent? crossing(SolarThreshold threshold, bool rising) {
      final matches =
          <SolarEvent>[
                ...day.forThreshold(threshold).crossings,
                ...followingDay.forThreshold(threshold).crossings,
              ]
              .where(
                (event) =>
                    event.isRising == rising &&
                    !event.utc.isBefore(day.nightStartUtc) &&
                    event.utc.isBefore(day.nightEndUtc),
              )
              .toList()
            ..sort((a, b) => a.utc.compareTo(b.utc));
      return matches.isEmpty ? null : matches.first;
    }

    // The Moon's displayed phase is sampled at midnight belonging to this
    // observing night, in the *observing site's* time zone, not device time.
    final zone = SolarEvents.timeZone(location.timeZone);
    final midnight = tz.TZDateTime(
      zone,
      localDate.year,
      localDate.month,
      localDate.day + 1,
    ).toUtc();
    final observer = ObserverPosition(
      latitudeDegrees: location.latitude,
      longitudeDegrees: location.longitude,
      elevationMeters: location.elevationMeters,
    );
    final moon = LunarEphemeris.positionAt(at: midnight, observer: observer);
    final moonEvents = LunarEphemeris.calculateForObservingNight(
      location: location,
      localDate: localDate,
    );

    final totalMicros = day.astronomicalDarkness.fold<int>(
      0,
      (sum, interval) => sum + interval.duration.inMicroseconds,
    );
    final windowMicros = day.nightEndUtc
        .difference(day.nightStartUtc)
        .inMicroseconds;
    final state = totalMicros == 0
        ? TonightDarknessState.none
        : totalMicros >= windowMicros
        ? TonightDarknessState.continuous
        : TonightDarknessState.partial;
    return TonightConditions(
      night: day,
      sunset: crossing(SolarThreshold.horizon, false),
      sunrise: crossing(SolarThreshold.horizon, true),
      astronomicalDusk: crossing(SolarThreshold.astronomical, false),
      astronomicalDawn: crossing(SolarThreshold.astronomical, true),
      moon: moon,
      moonEvents: moonEvents,
      darknessDuration: Duration(microseconds: totalMicros),
      darknessState: state,
    );
  }
}
