import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/night_observation_block.dart';

abstract interface class NightPlansRepository {
  Future<List<NightObservationBlock>> forNight(NightPlanKey key);
  Future<void> save(NightObservationBlock block);
  Future<void> remove(NightPlanKey key, String id);
}

/// Offline SQLite AppSettings storage. One record per site/local-night pair.
/// No migration or generated Drift classes are required for issue #30.
final class SettingsNightPlansRepository implements NightPlansRepository {
  const SettingsNightPlansRepository(this._settings);
  final AppSettingsRepository _settings;

  static String storageKey(NightPlanKey key) =>
      'planner.night.v1.${key.locationId}.${key.nightDate}';

  @override
  Future<List<NightObservationBlock>> forNight(NightPlanKey key) async {
    final raw = await _settings.get(storageKey(key));
    if (raw == null) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Invalid saved night plan.');
    }
    final blocks = decoded
        .map(
          (item) => NightObservationBlock.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    if (blocks.any(
      (block) =>
          block.locationId != key.locationId ||
          block.nightDate != key.nightDate,
    )) {
      throw const FormatException(
        'Night plan has mismatched location or date.',
      );
    }
    blocks.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return List.unmodifiable(blocks);
  }

  @override
  Future<void> save(NightObservationBlock block) async {
    block.validate();
    final key = NightPlanKey(block.locationId, block.nightDate);
    await _settings.transaction(() async {
      final blocks = [...await forNight(key)];
      final oldIndex = blocks.indexWhere((item) => item.id == block.id);
      if (oldIndex == -1) {
        blocks.add(block);
      } else {
        blocks[oldIndex] = block;
      }
      await _settings.put(
        storageKey(key),
        jsonEncode(blocks.map((item) => item.toJson()).toList()),
      );
    });
  }

  @override
  Future<void> remove(NightPlanKey key, String id) =>
      _settings.transaction(() async {
        final blocks = [...await forNight(key)]
          ..removeWhere((item) => item.id == id);
        if (blocks.isEmpty) {
          await _settings.delete(storageKey(key));
        } else {
          await _settings.put(
            storageKey(key),
            jsonEncode(blocks.map((item) => item.toJson()).toList()),
          );
        }
      });
}

final nightPlansRepositoryProvider = Provider<NightPlansRepository>(
  (ref) => SettingsNightPlansRepository(
    AppSettingsRepository(ref.watch(appDatabaseProvider)),
  ),
);

final nightPlansProvider =
    FutureProvider.family<List<NightObservationBlock>, NightPlanKey>(
      (ref, key) => ref.watch(nightPlansRepositoryProvider).forNight(key),
      retry: (count, error) => null,
    );
