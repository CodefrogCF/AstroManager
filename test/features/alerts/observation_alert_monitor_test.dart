import 'dart:async';

import 'package:astromanager/core/astronomy/solar_events.dart';
import 'package:astromanager/features/alerts/application/observation_alert_monitor.dart';
import 'package:astromanager/features/alerts/data/observation_alert_store.dart';
import 'package:astromanager/features/alerts/data/observation_notification_gateway.dart';
import 'package:astromanager/features/alerts/domain/observation_alert.dart';
import 'package:astromanager/features/alerts/domain/observation_alert_evaluator.dart';
import 'package:astromanager/features/intelligence/domain/models/observation_window.dart';
import 'package:astromanager/features/intelligence/domain/models/suitability_score.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:flutter_test/flutter_test.dart';

const site = ObservingLocation(
  id: 'site',
  name: 'Zurich',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 450,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);
const target = CelestialObject(
  id: 'target',
  designation: 'Target',
  category: CelestialCategory.nebula,
  sourceType: 'test',
  raDegrees: 25,
  decDegrees: 40,
  constellation: 'And',
  commonNames: '',
  aliases: '',
);
const rule = ObservationAlertRule(
  id: 'id',
  targetId: 'target',
  targetName: 'Target',
  locationId: 'site',
  minimumScore: 70,
  minimumDurationMinutes: 60,
);
final now = DateTime.utc(2026, 11, 2, 15);

ObservationWindowRecommendations recommended({
  required DateTime startUtc,
  double score = 85,
  WindowWeatherStatus weather = WindowWeatherStatus.complete,
  Duration duration = const Duration(hours: 2),
}) {
  final endUtc = startUtc.add(duration);
  return ObservationWindowRecommendations(
    periodStartUtc: startUtc.subtract(const Duration(hours: 1)),
    periodEndUtc: endUtc.add(const Duration(hours: 1)),
    minimumAltitudeDegrees: 30,
    astronomicalDarkness: const [],
    excludedTargets: const {},
    rankedWindows: [
      ObservationWindow(
        targetId: 'target',
        targetDesignation: 'Target',
        startUtc: startUtc,
        endUtc: endUtc,
        bestAltitudeDegrees: 65,
        bestAltitudeAtUtc: startUtc,
        score: TargetSuitabilityScore(
          targetId: 'target',
          startUtc: startUtc,
          endUtc: endUtc,
          score: score,
          dataCoverage: 1,
          isProvisional: false,
          visibleDuration: duration,
          astronomicalDarkDuration: duration,
          usableDuration: duration,
          bestUsableAltitudeDegrees: 65,
          factors: const {},
          constraints: const [],
        ),
        weatherStatus: weather,
        weatherTimeCoverage: 1,
        weatherParameterCoverage: 1,
        explanation: 'Synthetic recommendation',
      ),
    ],
  );
}

final class FakeGateway implements ObservationNotificationGateway {
  @override
  bool isSupported = true;
  bool permissionGranted = true;
  int permissionRequests = 0;
  final delivered = <String>[];
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> notify({
    required String fingerprint,
    required String target,
    required String location,
    required String timeZoneId,
    required DateTime startUtc,
    required double score,
  }) async {
    delivered.add(fingerprint);
  }
}

final class FakeRecommendations implements ObservationOpportunitySource {
  int calls = 0;
  double score = 85;
  WindowWeatherStatus weather = WindowWeatherStatus.complete;
  @override
  Future<ObservationWindowRecommendations> recommend({
    required ObservationAlertRule rule,
    required ObservingLocation site,
    required CelestialObject target,
    required DateTime localDate,
    required DateTime nowUtc,
  }) async {
    calls++;
    final shift = localDate.day == 2 ? 2 : 26;
    return recommended(
      startUtc: now.add(Duration(hours: shift)),
      score: score,
      weather: weather,
    );
  }
}

final class DelayedRecommendations implements ObservationOpportunitySource {
  final started = Completer<void>();
  final proceed = Completer<void>();
  @override
  Future<ObservationWindowRecommendations> recommend({
    required ObservationAlertRule rule,
    required ObservingLocation site,
    required CelestialObject target,
    required DateTime localDate,
    required DateTime nowUtc,
  }) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await proceed.future;
    return recommended(startUtc: now.add(const Duration(hours: 1)));
  }
}

ObservationAlertMonitor monitor(
  MemoryObservationAlertStore store,
  FakeGateway gateway,
  FakeRecommendations source,
) => ObservationAlertMonitor(
  store: store,
  gateway: gateway,
  opportunities: source,
  locations: () async => [site],
  targetById: (id) async => id == target.id ? target : null,
  clock: () => now,
);

void main() {
  test(
    'actual ranked window must satisfy target, duration, score and weather',
    () {
      expect(
        ObservationAlertEvaluator.bestEligible(
          rule: rule,
          recommendations: recommended(
            startUtc: now.add(const Duration(hours: 1)),
          ),
          nowUtc: now,
        ),
        isNotNull,
      );
      expect(
        ObservationAlertEvaluator.bestEligible(
          rule: rule,
          recommendations: recommended(
            startUtc: now.add(const Duration(hours: 1)),
            score: 69,
          ),
          nowUtc: now,
        ),
        isNull,
      );
      expect(
        ObservationAlertEvaluator.bestEligible(
          rule: rule,
          recommendations: recommended(
            startUtc: now.add(const Duration(hours: 1)),
            weather: WindowWeatherStatus.stale,
          ),
          nowUtc: now,
        ),
        isNull,
      );
      expect(
        ObservationAlertEvaluator.bestEligible(
          rule: rule,
          recommendations: recommended(
            startUtc: now.add(const Duration(hours: 1)),
            duration: const Duration(minutes: 30),
          ),
          nowUtc: now,
        ),
        isNull,
      );
    },
  );

  test('disabled alerts perform no network work or notifications', () async {
    final store = MemoryObservationAlertStore();
    await store.save(ObservationAlertState(enabled: false, rules: [rule]));
    final gateway = FakeGateway();
    final source = FakeRecommendations();
    await monitor(store, gateway, source).checkNow();
    expect(source.calls, 0);
    expect(gateway.delivered, isEmpty);
  });

  test('notifies once per observing night even on repeated checks', () async {
    final store = MemoryObservationAlertStore();
    await store.save(ObservationAlertState(enabled: true, rules: [rule]));
    final gateway = FakeGateway();
    final source = FakeRecommendations();
    final service = monitor(store, gateway, source);
    final first = await service.checkNow();
    expect(first.sent, 2);
    expect(gateway.delivered.length, 2);
    final second = await service.checkNow();
    expect(second.sent, 0);
    expect(gateway.delivered.length, 2);
    expect(source.calls, 2);
    expect(gateway.permissionRequests, 0); // User gesture only.
  });

  test(
    'thresholds, missing forecast and disabled rule prevent alerts',
    () async {
      final store = MemoryObservationAlertStore();
      await store.save(ObservationAlertState(enabled: true, rules: [rule]));
      final gateway = FakeGateway();
      final source = FakeRecommendations()
        ..weather = WindowWeatherStatus.missing;
      await monitor(store, gateway, source).checkNow();
      expect(gateway.delivered, isEmpty);
      await store.save(
        ObservationAlertState(
          enabled: true,
          rules: [rule.copyWith(enabled: false)],
        ),
      );
      await monitor(store, gateway, source).checkNow();
      expect(gateway.delivered, isEmpty);
    },
  );

  test('disabling a rule while a forecast loads blocks delivery', () async {
    final store = MemoryObservationAlertStore();
    await store.save(ObservationAlertState(enabled: true, rules: [rule]));
    final gateway = FakeGateway();
    final source = DelayedRecommendations();
    final monitor = ObservationAlertMonitor(
      store: store,
      gateway: gateway,
      opportunities: source,
      locations: () async => [site],
      targetById: (id) async => target,
      clock: () => now,
    );
    final pending = monitor.checkNow();
    await source.started.future;
    await store.save(ObservationAlertState(enabled: false, rules: [rule]));
    source.proceed.complete();
    expect((await pending).sent, 0);
    expect(gateway.delivered, isEmpty);
  });

  test('timezone calendar night uses previous day before local noon', () {
    final time = DateTime.utc(2026, 3, 29, 6); // 08:00 in Zurich (DST)
    final day = ObservationAlertMonitor.observingDate(site, time);
    expect(day, DateTime.utc(2026, 3, 28));
    final night = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: day,
    );
    expect(night.nightStartUtc.isUtc, isTrue);
    final key = ObservationAlertEvaluator.fingerprint(
      rule.id,
      night.nightStartUtc,
    );
    expect(key, contains('2026-03-28'));
  });
}
