import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/features/targets/application/target_providers.dart';
import 'package:astromanager/features/targets/domain/models/celestial_target.dart';
import 'package:astromanager/features/targets/domain/repositories/target_repository.dart';

class FakeTargetRepository implements TargetRepository {
  @override
  Future<List<CelestialTarget>> getFeaturedTargets() async {
    return const [CelestialTarget(id: 'M31', name: 'Andromeda Galaxy')];
  }
}

void main() {
  test('Target repository can be overridden', () async {
    final container = ProviderContainer.test(
      overrides: [
        targetRepositoryProvider.overrideWith((ref) => FakeTargetRepository()),
      ],
    );

    final targets = await container.read(featuredTargetsProvider.future);

    expect(targets, hasLength(1));
    expect(targets.first.id, 'M31');
    expect(targets.first.name, 'Andromeda Galaxy');
  });

  test('Default repository returns an empty list', () async {
    final container = ProviderContainer.test();

    final targets = await container.read(featuredTargetsProvider.future);

    expect(targets, isEmpty);
  });
}
