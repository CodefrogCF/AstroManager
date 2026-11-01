import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_providers.dart';

import '../data/repositories/drift_observing_location_repository.dart';
import '../data/services/device_location_service.dart';
import '../domain/models/observing_location.dart';
import '../domain/repositories/observing_location_repository.dart';

final observingLocationRepositoryProvider =
    Provider<ObservingLocationRepository>((ref) {
      final database = ref.watch(appDatabaseProvider);

      return DriftObservingLocationRepository(database);
    });

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return const GeolocatorDeviceLocationService();
});

final observingLocationsProvider =
    AsyncNotifierProvider<
      ObservingLocationsController,
      List<ObservingLocation>
    >(ObservingLocationsController.new, retry: (retryCount, error) => null);

class ObservingLocationsController
    extends AsyncNotifier<List<ObservingLocation>> {
  @override
  Future<List<ObservingLocation>> build() {
    return ref.watch(observingLocationRepositoryProvider).getAll();
  }

  Future<void> save(ObservingLocationInput input, {String? id}) async {
    input.validate();

    final existing = id == null ? null : _findLocation(state.value ?? [], id);

    final location = ObservingLocation(
      id: id ?? const Uuid().v4(),
      name: input.name.trim(),
      latitude: input.latitude,
      longitude: input.longitude,
      elevationMeters: input.elevationMeters,
      timeZone: input.timeZone.trim(),
      isDefault: existing?.isDefault ?? false,
    );

    await _mutate((repository) => repository.save(location));
  }

  Future<void> setDefault(String id) {
    return _mutate((repository) => repository.setDefault(id));
  }

  Future<void> delete(String id) {
    return _mutate((repository) => repository.delete(id));
  }

  Future<void> _mutate(
    Future<void> Function(ObservingLocationRepository) action,
  ) async {
    final previousState = state;
    final repository = ref.read(observingLocationRepositoryProvider);

    state = const AsyncLoading();

    try {
      await action(repository);
      final locations = await repository.getAll();

      if (ref.mounted) {
        state = AsyncData(locations);
      }
    } catch (_) {
      if (ref.mounted) {
        state = previousState;
      }

      rethrow;
    }
  }

  ObservingLocation? _findLocation(
    List<ObservingLocation> locations,
    String id,
  ) {
    for (final location in locations) {
      if (location.id == id) return location;
    }

    return null;
  }
}
