import '../models/observing_location.dart';

abstract interface class ObservingLocationRepository {
  Future<List<ObservingLocation>> getAll();

  Future<void> save(ObservingLocation location);

  Future<void> delete(String id);

  Future<void> setDefault(String id);
}
