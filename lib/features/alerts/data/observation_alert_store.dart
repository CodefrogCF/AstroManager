import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/observation_alert.dart';

abstract interface class ObservationAlertStore {
  Future<ObservationAlertState> load();
  Future<void> save(ObservationAlertState state);
}

/// Stored in app_settings, automatically included in versioned .ambackup files.
/// Nothing is sent to a remote server.
final class SettingsObservationAlertStore implements ObservationAlertStore {
  const SettingsObservationAlertStore(this.settings);
  final AppSettingsRepository settings;
  static const key = 'observation.alerts.v1';

  @override
  Future<ObservationAlertState> load() async {
    final raw = await settings.get(key);
    if (raw == null) {
      return ObservationAlertState();
    }
    return ObservationAlertState.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  @override
  Future<void> save(ObservationAlertState state) async {
    state.validate();
    await settings.put(key, jsonEncode(state.toJson()));
  }
}

final observationAlertStoreProvider = Provider<ObservationAlertStore>((ref) {
  return SettingsObservationAlertStore(
    ref.watch(appSettingsRepositoryProvider),
  );
});

final class MemoryObservationAlertStore implements ObservationAlertStore {
  ObservationAlertState state = ObservationAlertState();

  @override
  Future<ObservationAlertState> load() async => state;

  @override
  Future<void> save(ObservationAlertState value) async {
    value.validate();
    state = value;
  }
}
