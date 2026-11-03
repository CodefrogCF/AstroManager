import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../locations/domain/models/observing_location.dart';
import '../domain/tonight_conditions.dart';

typedef TonightConditionsQuery = ({
  ObservingLocation location,
  DateTime localDate,
});

/// Cached by site and local observing night while the widget is visible.
/// No network access, database migration or background polling is required.
final tonightConditionsProvider = FutureProvider.autoDispose
    .family<TonightConditions, TonightConditionsQuery>((ref, query) async {
      // Yield one frame so each widget can show an isolated loading state.
      await Future<void>.delayed(Duration.zero);
      return TonightConditionsCalculator.calculate(
        location: query.location,
        localDate: query.localDate,
      );
    }, retry: (count, error) => null);
