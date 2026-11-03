import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/dashboard_layout.dart';

abstract interface class DashboardLayoutRepository {
  Future<DashboardLayout> load();
  Future<void> save(DashboardLayout layout);
}

/// Stored in app_settings, so the normal .ambackup export includes layouts.
final class SettingsDashboardLayoutRepository
    implements DashboardLayoutRepository {
  const SettingsDashboardLayoutRepository(this._settings);

  static const storageKey = 'dashboard.layout.v1';
  final AppSettingsRepository _settings;

  @override
  Future<DashboardLayout> load() async {
    final raw = await _settings.get(storageKey);
    if (raw == null) return DashboardLayout.defaults;
    try {
      return DashboardLayout.fromJson(jsonDecode(raw));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Saved dashboard configuration is invalid.');
    }
  }

  @override
  Future<void> save(DashboardLayout layout) async {
    layout.validate();
    await _settings.put(storageKey, jsonEncode(layout.toJson()));
  }
}

/// Test double for isolated widget and persistence tests.
final class MemoryDashboardLayoutRepository
    implements DashboardLayoutRepository {
  MemoryDashboardLayoutRepository([this.layout = DashboardLayout.defaults]);

  DashboardLayout layout;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<DashboardLayout> load() async {
    loadCount++;
    return layout;
  }

  @override
  Future<void> save(DashboardLayout value) async {
    value.validate();
    layout = DashboardLayout.fromJson(jsonDecode(jsonEncode(value.toJson())));
    saveCount++;
  }
}

final dashboardLayoutRepositoryProvider = Provider<DashboardLayoutRepository>((
  ref,
) {
  return SettingsDashboardLayoutRepository(
    ref.watch(appSettingsRepositoryProvider),
  );
});
