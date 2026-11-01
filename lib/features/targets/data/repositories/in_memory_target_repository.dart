import '../../domain/models/celestial_target.dart';
import '../../domain/repositories/target_repository.dart';

final class InMemoryTargetRepository implements TargetRepository {
  const InMemoryTargetRepository();

  @override
  Future<List<CelestialTarget>> getFeaturedTargets() async {
    return const [];
  }
}
