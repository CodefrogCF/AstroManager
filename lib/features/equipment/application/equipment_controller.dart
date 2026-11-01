import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers/database_providers.dart';

import '../data/repositories/drift_equipment_repository.dart';
import '../domain/models/equipment_models.dart';
import '../domain/repositories/equipment_repository.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return DriftEquipmentRepository(database);
});

final equipmentProvider =
    AsyncNotifierProvider<EquipmentController, EquipmentInventory>(
      EquipmentController.new,
      retry: (retryCount, error) => null,
    );

class EquipmentController extends AsyncNotifier<EquipmentInventory> {
  bool _busy = false;

  @override
  Future<EquipmentInventory> build() {
    return ref.watch(equipmentRepositoryProvider).load();
  }

  Future<void> saveItem(EquipmentItem item) {
    return _write((repository) => repository.saveItem(item));
  }

  Future<void> deleteItem(String id) {
    return _write((repository) => repository.deleteItem(id));
  }

  Future<void> saveProfile(OpticalProfile profile) {
    return _write((repository) => repository.saveProfile(profile));
  }

  Future<void> deleteProfile(String id) {
    return _write((repository) => repository.deleteProfile(id));
  }

  Future<void> _write(Future<void> Function(EquipmentRepository) action) async {
    if (_busy || state.isLoading) {
      throw const ValidationFailure(
        'An equipment operation is already running.',
      );
    }

    _busy = true;
    final previousState = state;

    state = const AsyncLoading();

    try {
      final repository = ref.read(equipmentRepositoryProvider);

      await action(repository);

      final updated = await repository.load();

      if (ref.mounted) {
        state = AsyncData(updated);
      }
    } catch (_) {
      if (ref.mounted) {
        state = previousState;
      }

      rethrow;
    } finally {
      _busy = false;
    }
  }
}
