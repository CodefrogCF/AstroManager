import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/data/night_plans_repository.dart';
import '../../planner/domain/night_observation_block.dart';
import '../domain/dashboard_plans_and_alerts.dart';

/// Uses the planner's existing family cache. Changes made by the Night Planner
/// invalidate the same per-night provider and refresh this dashboard widget.
final dashboardUpcomingPlansProvider = FutureProvider.autoDispose
    .family<
      List<NightObservationBlock>,
      ({String locationId, DateTime firstNight, int nights})
    >((ref, request) async {
      final keys = DashboardUpcomingPlans.keys(
        locationId: request.locationId,
        firstNight: request.firstNight,
        nights: request.nights,
      );
      final perNight = await Future.wait([
        for (final key in keys) ref.watch(nightPlansProvider(key).future),
      ]);
      return List<NightObservationBlock>.unmodifiable(
        perNight.expand((blocks) => blocks),
      );
    }, retry: (count, error) => null);
