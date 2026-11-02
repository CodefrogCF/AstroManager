import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';

abstract interface class ObservationNotificationGateway {
  bool get isSupported;

  /// Only invoke following a deliberate user gesture (not on startup).
  Future<bool> requestPermission();
  Future<void> notify({
    required String fingerprint,
    required String target,
    required String location,
    required String timeZoneId,
    required DateTime startUtc,
    required double score,
  });
}

/// Android and iOS only. Notifications are shown when an evaluation is run;
/// this adapter does not schedule future forecast refreshes or exact alarms.
final class LocalObservationNotificationGateway
    implements ObservationNotificationGateway {
  LocalObservationNotificationGateway();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;

  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _initialize() => _initializing ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    if (!isSupported) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    await _initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    return false;
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
    if (!isSupported) {
      throw UnsupportedError('Notifications unavailable.');
    }
    await _initialize();
    // Stable 31-bit ID: safe on Android. The persistent duplicate ledger,
    // not the platform notification ID, is responsible for deduplication.
    var id = 0;
    for (final unit in fingerprint.codeUnits) {
      id = ((id * 31) + unit) & 0x7fffffff;
    }
    final local = tz.TZDateTime.from(
      startUtc,
      SolarEvents.timeZone(timeZoneId),
    );
    final displayTime =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} $timeZoneId';
    await _plugin.show(
      id: id,
      title: 'Imaging opportunity: $target',
      body:
          '$location · $displayTime · '
          'suitability ${score.toStringAsFixed(0)}/100',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'astromanager_observing_opportunities',
          'Observation opportunities',
          channelDescription: 'Forecast-based astrophotography opportunities',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: fingerprint,
    );
  }
}

final observationNotificationGatewayProvider =
    Provider<ObservationNotificationGateway>((ref) {
      return LocalObservationNotificationGateway();
    });
