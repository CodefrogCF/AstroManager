import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/in_memory_target_repository.dart';
import '../domain/models/celestial_target.dart';
import '../domain/repositories/target_repository.dart';

final targetRepositoryProvider = Provider<TargetRepository>(
  (ref) => const InMemoryTargetRepository(),
);

final featuredTargetsProvider = FutureProvider<List<CelestialTarget>>((
  ref,
) async {
  final repository = ref.watch(targetRepositoryProvider);

  return repository.getFeaturedTargets();
});
