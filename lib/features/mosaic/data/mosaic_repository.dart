import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/mosaic_plan.dart';

abstract interface class MosaicPlansRepository {
  Future<MosaicPlan?> load(String projectId);
  Future<void> save(MosaicPlan plan);
  Future<void> delete(String projectId);
}

/// Stored under a project-specific app_settings key: backed up by the existing
/// v1 .ambackup exporter (including offline merge/replace restoration).
final class SettingsMosaicPlansRepository implements MosaicPlansRepository {
  const SettingsMosaicPlansRepository(this.settings);
  final AppSettingsRepository settings;
  static const prefix = 'projects.mosaic.v1.';

  static String key(String projectId) {
    if (projectId.trim().isEmpty || projectId.length > 120) {
      throw const FormatException('Invalid mosaic project id.');
    }
    return '$prefix${Uri.encodeComponent(projectId)}';
  }

  @override
  Future<MosaicPlan?> load(String projectId) async {
    final raw = await settings.get(key(projectId));
    if (raw == null) {
      return null;
    }
    final plan = MosaicPlan.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    if (plan.projectId != projectId) {
      throw const FormatException('Mosaic belongs to a different project.');
    }
    return plan;
  }

  @override
  Future<void> save(MosaicPlan plan) async {
    await settings.put(key(plan.projectId), jsonEncode(plan.toJson()));
  }

  @override
  Future<void> delete(String projectId) => settings.delete(key(projectId));
}

final mosaicPlansRepositoryProvider = Provider<MosaicPlansRepository>(
  (ref) => SettingsMosaicPlansRepository(
    AppSettingsRepository(ref.watch(appDatabaseProvider)),
  ),
);

/// Small in-memory substitute for unit/widget tests.
final class MemoryMosaicPlansRepository implements MosaicPlansRepository {
  final Map<String, MosaicPlan> records = {};
  @override
  Future<MosaicPlan?> load(String projectId) async => records[projectId];
  @override
  Future<void> save(MosaicPlan plan) async {
    plan.validate();
    records[plan.projectId] = plan;
  }

  @override
  Future<void> delete(String projectId) async {
    records.remove(projectId);
  }
}
