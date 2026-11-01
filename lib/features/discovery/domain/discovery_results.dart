import '../../intelligence/domain/models/observation_window.dart';
import '../../targets/domain/models/celestial_object.dart';

final class RankedDiscoveryTarget {
  const RankedDiscoveryTarget({required this.object, required this.window});

  final CelestialObject object;
  final ObservationWindow window;

  double get score => window.score.score;
  bool get provisional => window.isProvisional;
}

/// Stable order across equal scores and identical inputs.
List<RankedDiscoveryTarget> rankDiscoveryTargets(
  Iterable<RankedDiscoveryTarget> targets,
) {
  final sorted = [...targets];
  sorted.sort((a, b) {
    var order = b.score.compareTo(a.score);
    if (order != 0) return order;
    order = a.provisional == b.provisional ? 0 : (a.provisional ? 1 : -1);
    if (order != 0) return order;
    order = b.window.duration.compareTo(a.window.duration);
    if (order != 0) return order;
    order = a.window.startUtc.compareTo(b.window.startUtc);
    return order != 0 ? order : a.object.id.compareTo(b.object.id);
  });
  return List.unmodifiable(sorted);
}
