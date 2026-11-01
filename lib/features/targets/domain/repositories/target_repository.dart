import '../models/celestial_target.dart';

abstract interface class TargetRepository {
  Future<List<CelestialTarget>> getFeaturedTargets();
}
