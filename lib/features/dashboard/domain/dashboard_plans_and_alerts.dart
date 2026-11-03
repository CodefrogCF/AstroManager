import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../alerts/domain/observation_alert.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../planner/domain/night_observation_block.dart';

/// One future or currently running observation with its overlap status.
final class DashboardPlannedObservation {
  const DashboardPlannedObservation({
    required this.block,
    required this.conflictingIds,
  });

  final NightObservationBlock block;
  final Set<String> conflictingIds;
  bool get hasConflict => conflictingIds.isNotEmpty;
}

/// All times are stored as UTC; the date keys use the observing site's zone.
/// Day increments are calendar-based to avoid DST-related skipped nights.
abstract final class DashboardUpcomingPlans {
  static DateTime currentNight(ObservingLocation site, DateTime nowUtc) {
    final local = tz.TZDateTime.from(
      nowUtc.toUtc(),
      SolarEvents.timeZone(site.timeZone),
    );
    return DateTime.utc(
      local.year,
      local.month,
      local.day - (local.hour < 12 ? 1 : 0),
    );
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static List<NightPlanKey> keys({
    required String locationId,
    required DateTime firstNight,
    required int nights,
  }) {
    if (nights < 1 || nights > 14) {
      throw ArgumentError.value(nights, 'nights');
    }
    return List.generate(nights, (index) {
      final day = DateTime.utc(
        firstNight.year,
        firstNight.month,
        firstNight.day + index,
      );
      return NightPlanKey(locationId, dateKey(day));
    });
  }

  static List<DashboardPlannedObservation> aggregate({
    required Iterable<NightObservationBlock> blocks,
    required DateTime nowUtc,
  }) {
    final entries = blocks.toList();
    // Conflicts are meaningful within a particular site and saved night.
    // Include ended entries when detecting overlap with a still-running block.
    final groups = <NightPlanKey, List<NightObservationBlock>>{};
    for (final block in entries) {
      groups
          .putIfAbsent(
            NightPlanKey(block.locationId, block.nightDate),
            () => [],
          )
          .add(block);
    }
    final conflicts = <NightPlanKey, Map<String, Set<String>>>{
      for (final group in groups.entries)
        group.key: NightPlanConflicts.detect(group.value),
    };
    final current =
        entries.where((block) => block.endUtc.isAfter(nowUtc.toUtc())).toList()
          ..sort((a, b) {
            final byTime = a.startUtc.compareTo(b.startUtc);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    return List.unmodifiable([
      for (final block in current)
        DashboardPlannedObservation(
          block: block,
          conflictingIds: Set<String>.unmodifiable(
            conflicts[NightPlanKey(
                  block.locationId,
                  block.nightDate,
                )]?[block.id] ??
                const <String>{},
          ),
        ),
    ]);
  }
}

/// Delivered history records successful notifications for actual eligible
/// weather-based windows *at the time they were checked*. A delivery is not
/// a live/current forecast or a promise of future background monitoring.
final class DashboardNotifiedOpportunity {
  const DashboardNotifiedOpportunity({
    required this.rule,
    required this.nightStartUtc,
    required this.notifiedAtUtc,
  });

  final ObservationAlertRule rule;
  final DateTime nightStartUtc;
  final DateTime notifiedAtUtc;
}

final class DashboardAlertOverview {
  const DashboardAlertOverview({
    required this.notificationsEnabled,
    required this.rules,
    required this.recentNotifications,
  });

  final bool notificationsEnabled;
  final List<ObservationAlertRule> rules;
  final List<DashboardNotifiedOpportunity> recentNotifications;

  /// Only enabled rules are shown as monitoring when the global switch is on.
  List<ObservationAlertRule> get monitoredRules => notificationsEnabled
      ? List.unmodifiable(rules.where((rule) => rule.enabled))
      : const [];

  static DashboardAlertOverview fromState({
    required ObservationAlertState state,
    required String locationId,
    required DateTime nowUtc,
    Duration recentFor = const Duration(days: 7),
  }) {
    final rules = state.rules
        .where((rule) => rule.locationId == locationId)
        .toList(growable: false);
    final recent = <DashboardNotifiedOpportunity>[];
    if (state.enabled) {
      for (final rule in rules.where((rule) => rule.enabled)) {
        final prefix = '${rule.id}|';
        for (final entry in state.delivered.entries) {
          if (!entry.key.startsWith(prefix)) {
            continue;
          }
          final deliveredAt = entry.value.toUtc();
          final age = nowUtc.toUtc().difference(deliveredAt);
          if (age.isNegative || age > recentFor) {
            continue;
          }
          final nightStart = DateTime.tryParse(
            entry.key.substring(prefix.length),
          );
          if (nightStart == null || !nightStart.isUtc) {
            continue;
          }
          recent.add(
            DashboardNotifiedOpportunity(
              rule: rule,
              nightStartUtc: nightStart,
              notifiedAtUtc: deliveredAt,
            ),
          );
        }
      }
    }
    recent.sort((a, b) {
      final recentFirst = b.notifiedAtUtc.compareTo(a.notifiedAtUtc);
      return recentFirst != 0 ? recentFirst : a.rule.id.compareTo(b.rule.id);
    });
    return DashboardAlertOverview(
      notificationsEnabled: state.enabled,
      rules: List.unmodifiable(rules),
      recentNotifications: List.unmodifiable(recent),
    );
  }
}
