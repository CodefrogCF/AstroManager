import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../intelligence/domain/models/observation_window.dart';
import '../../intelligence/domain/services/observation_window_recommendation.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../../weather/domain/providers/weather_provider.dart';
import '../data/observation_alert_store.dart';
import '../data/observation_notification_gateway.dart';
import '../domain/observation_alert.dart';
import '../domain/observation_alert_evaluator.dart';

final class ObservationAlertCheckResult {
  const ObservationAlertCheckResult({
    required this.sent,
    required this.alreadyDelivered,
    required this.unavailable,
  });
  final int sent;
  final int alreadyDelivered;
  final int unavailable;
}

/// Replaceable seam for network/astronomy tests. The production implementation
/// runs the *same* engine and weather source as target discovery.
abstract interface class ObservationOpportunitySource {
  Future<ObservationWindowRecommendations> recommend({
    required ObservationAlertRule rule,
    required ObservingLocation site,
    required CelestialObject target,
    required DateTime localDate,
    required DateTime nowUtc,
  });
}

final class LiveObservationOpportunitySource
    implements ObservationOpportunitySource {
  const LiveObservationOpportunitySource(this.weather);
  final Future<WeatherForecastSnapshot> Function(WeatherForecastRequest)
  weather;

  @override
  Future<ObservationWindowRecommendations> recommend({
    required ObservationAlertRule rule,
    required ObservingLocation site,
    required CelestialObject target,
    required DateTime localDate,
    required DateTime nowUtc,
  }) async {
    final night = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: localDate,
    );
    final forecast = await weather(
      WeatherForecastRequest(
        latitudeDegrees: site.latitude,
        longitudeDegrees: site.longitude,
        startUtc: night.nightStartUtc,
        endUtc: night.nightEndUtc,
      ),
    );
    return ObservationWindowRecommendation.forObservingNight(
      targets: [target],
      location: site,
      localDate: localDate,
      evaluatedAtUtc: nowUtc,
      weather: forecast,
      options: ObservationWindowOptions(
        minimumSessionDuration: Duration(minutes: rule.minimumDurationMinutes),
        maximumSessionDuration: Duration(
          minutes: rule.minimumDurationMinutes > 240
              ? rule.minimumDurationMinutes
              : 240,
        ),
        candidateStep: const Duration(minutes: 30),
        maximumRecommendations: 10,
      ),
    );
  }
}

final observationOpportunitySourceProvider =
    Provider<ObservationOpportunitySource>((ref) {
      return LiveObservationOpportunitySource(
        (request) => ref.read(weatherForecastServiceProvider).load(request),
      );
    });

/// Serializes evaluations inside the app. No periodic background scheduler is
/// installed. Disabled alerts never initiate a forecast fetch or notification.
final class ObservationAlertMonitor {
  ObservationAlertMonitor({
    required this.store,
    required this.gateway,
    required this.opportunities,
    required this.locations,
    required this.targetById,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final ObservationAlertStore store;
  final ObservationNotificationGateway gateway;
  final ObservationOpportunitySource opportunities;
  final Future<List<ObservingLocation>> Function() locations;
  final Future<CelestialObject?> Function(String) targetById;
  final DateTime Function() _clock;
  Future<ObservationAlertCheckResult>? _running;

  Future<ObservationAlertCheckResult> checkNow() =>
      _running ??= _run().whenComplete(() => _running = null);

  static DateTime observingDate(ObservingLocation site, DateTime nowUtc) {
    final local = tz.TZDateTime.from(
      nowUtc,
      SolarEvents.timeZone(site.timeZone),
    );
    final calendar = DateTime.utc(local.year, local.month, local.day);
    return local.hour < 12
        ? calendar.subtract(const Duration(days: 1))
        : calendar;
  }

  Future<ObservationAlertCheckResult> _run() async {
    final state = await store.load();
    if (!state.enabled || !gateway.isSupported) {
      return const ObservationAlertCheckResult(
        sent: 0,
        alreadyDelivered: 0,
        unavailable: 0,
      );
    }
    final rules = state.rules.where((rule) => rule.enabled).toList();
    if (rules.isEmpty) {
      return const ObservationAlertCheckResult(
        sent: 0,
        alreadyDelivered: 0,
        unavailable: 0,
      );
    }
    final sites = {for (final site in await locations()) site.id: site};
    final now = _clock().toUtc();
    var sent = 0;
    var alreadyDelivered = 0;
    var unavailable = 0;
    for (final rule in rules) {
      final site = sites[rule.locationId];
      final target = site == null ? null : await targetById(rule.targetId);
      if (site == null || target == null) {
        unavailable++;
        continue;
      }
      final date = observingDate(site, now);
      for (final dayOffset in [0, 1]) {
        final activeState = await store.load();
        if (!activeState.enabled ||
            !activeState.rules.any(
              (entry) => entry.id == rule.id && entry.enabled,
            )) {
          break;
        }
        final nightDate = date.add(Duration(days: dayOffset));
        final nightStart = SolarEvents.calculateForLocalDate(
          location: site,
          localDate: nightDate,
        ).nightStartUtc;
        final key = ObservationAlertEvaluator.fingerprint(rule.id, nightStart);
        if (state.delivered.containsKey(key)) {
          alreadyDelivered++;
          continue;
        }
        try {
          final recommendations = await opportunities.recommend(
            rule: rule,
            site: site,
            target: target,
            localDate: nightDate,
            nowUtc: now,
          );
          final best = ObservationAlertEvaluator.bestEligible(
            rule: rule,
            recommendations: recommendations,
            nowUtc: now,
          );
          if (best == null) {
            continue;
          }
          // Another settings operation may have disabled or removed this rule
          // during forecast retrieval. Never notify using stale settings.
          final current = await store.load();
          if (!current.enabled ||
              !current.rules.any(
                (entry) => entry.id == rule.id && entry.enabled,
              ) ||
              current.delivered.containsKey(key)) {
            continue;
          }
          await gateway.notify(
            fingerprint: key,
            target: rule.targetName,
            location: site.name,
            timeZoneId: site.timeZone,
            startUtc: best.startUtc,
            score: best.score.score,
          );
          final history = {...current.delivered, key: now};
          // Bound historical size: no unlimited app_settings growth.
          history.removeWhere(
            (_, when) => now.difference(when) > const Duration(days: 30),
          );
          while (history.length > 1024) {
            final oldest = history.keys.first;
            history.remove(oldest);
          }
          await store.save(current.copyWith(delivered: history));
          sent++;
        } catch (_) {
          // A missing or failed weather source is not a favorable forecast.
          // Continue independently for other sites/targets.
          unavailable++;
        }
      }
    }
    return ObservationAlertCheckResult(
      sent: sent,
      alreadyDelivered: alreadyDelivered,
      unavailable: unavailable,
    );
  }
}

final observationAlertMonitorProvider = Provider<ObservationAlertMonitor>((
  ref,
) {
  return ObservationAlertMonitor(
    store: ref.watch(observationAlertStoreProvider),
    gateway: ref.watch(observationNotificationGatewayProvider),
    opportunities: ref.watch(observationOpportunitySourceProvider),
    locations: () => ref.read(observingLocationsProvider.future),
    targetById: (id) async {
      await ref.read(celestialCatalogProvider.future);
      return ref.read(celestialCatalogRepositoryProvider).findById(id);
    },
  );
});
