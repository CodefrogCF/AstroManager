import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app/router/app_router.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../l10n/app_text.dart';
import '../../../alerts/data/observation_alert_store.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../application/dashboard_plans_provider.dart';
import '../../domain/dashboard_plans_and_alerts.dart';
import 'dashboard_widget_state.dart';

String _localClock(DateTime instantUtc, String timeZone) {
  final local = tz.TZDateTime.from(
    instantUtc.toUtc(),
    SolarEvents.timeZone(timeZone),
  );
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)} ${local.timeZoneName}';
}

Widget _unused(BuildContext context, Object value) => const SizedBox.shrink();

/// Cached local night plans, shown only for the dashboard-selected site.
/// The widget contains no networking or duplicated planner calculations.
class DashboardUpcomingPlansWidget extends ConsumerWidget {
  const DashboardUpcomingPlansWidget({
    super.key,
    required this.location,
    this.limit = 5,
    this.horizonNights = 7,
    this.referenceUtc,
  });

  final ObservingLocation? location;
  final int limit;
  final int horizonNights;
  final DateTime? referenceUtc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty('No observing location selected.'),
        dataBuilder: _unused,
      );
    }
    final now = (referenceUtc ?? DateTime.now()).toUtc();
    final firstNight = DashboardUpcomingPlans.currentNight(site, now);
    final plans = ref.watch(
      dashboardUpcomingPlansProvider((
        locationId: site.id,
        firstNight: firstNight,
        nights: horizonNights,
      )),
    );
    return plans.when(
      loading: () => const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.loading(),
        dataBuilder: _unused,
      ),
      error: (_, _) => const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.error('Unable to load planned observations.'),
        dataBuilder: _unused,
      ),
      data: (blocks) {
        final upcoming = DashboardUpcomingPlans.aggregate(
          blocks: blocks,
          nowUtc: now,
        );
        if (upcoming.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('No upcoming observation blocks at this location.'),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('dashboard-plans-open'),
                onPressed: () => context.go(
                  AppRoutes.plannerForNight(
                    site.id,
                    DashboardUpcomingPlans.dateKey(firstNight),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const AppText('Open Night Planner'),
              ),
            ],
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 290;
            return Column(
              key: const ValueKey('dashboard-upcoming-plans'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in upcoming.take(limit))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Semantics(
                      button: true,
                      label:
                          '${item.block.targetName}, ${site.name}, '
                          '${_localClock(item.block.startUtc, site.timeZone)}'
                          '${item.hasConflict ? ', ${appTranslate(context, 'Overlapping observations')}' : ''}',
                      child: InkWell(
                        key: ValueKey('dashboard-plan-${item.block.id}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.go(
                          AppRoutes.plannerForNight(
                            item.block.locationId,
                            item.block.nightDate,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.block.targetName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  if (item.hasConflict)
                                    Tooltip(
                                      message: appTranslate(
                                        context,
                                        'Overlapping observations',
                                      ),
                                      child: Icon(
                                        Icons.warning_amber_outlined,
                                        key: ValueKey(
                                          'dashboard-plan-conflict-${item.block.id}',
                                        ),
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  const Icon(Icons.chevron_right, size: 18),
                                ],
                              ),
                              Text(
                                '${_localClock(item.block.startUtc, site.timeZone)}'
                                ' – ${_localClock(item.block.endUtc, site.timeZone)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                compact
                                    ? site.name
                                    : '${site.name} · ${item.block.projectName} · ${site.timeZone}',
                                style: Theme.of(context).textTheme.labelSmall,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.hasConflict)
                                AppText(
                                  'Overlapping observations',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                TextButton.icon(
                  key: const ValueKey('dashboard-plans-open'),
                  onPressed: () => context.go(
                    AppRoutes.plannerForNight(
                      site.id,
                      DashboardUpcomingPlans.dateKey(firstNight),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const AppText('Open Night Planner'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Reads persisted alert rules and *delivered* notification fingerprints.
/// Neither displaying this widget nor opening the dashboard polls weather or
/// evaluates rules. Checks happen only in the existing monitor lifecycle.
class DashboardObservationAlertsWidget extends ConsumerWidget {
  const DashboardObservationAlertsWidget({
    super.key,
    required this.location,
    this.limit = 3,
    this.showHistory = true,
    this.referenceUtc,
  });

  final ObservingLocation? location;
  final int limit;
  final bool showHistory;
  final DateTime? referenceUtc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty('No observing location selected.'),
        dataBuilder: _unused,
      );
    }
    return ref
        .watch(observationAlertStateProvider)
        .when(
          loading: () => const DashboardWidgetStateView<Object>(
            state: DashboardLoadState.loading(),
            dataBuilder: _unused,
          ),
          error: (_, _) => const DashboardWidgetStateView<Object>(
            state: DashboardLoadState.error(
              'Unable to load observation alerts.',
            ),
            dataBuilder: _unused,
          ),
          data: (state) {
            final overview = DashboardAlertOverview.fromState(
              state: state,
              locationId: site.id,
              nowUtc: (referenceUtc ?? DateTime.now()).toUtc(),
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 300;
                return Column(
                  key: const ValueKey('dashboard-observation-alerts'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!overview.notificationsEnabled)
                      const AppText('Opportunity notifications are disabled.'),
                    if (overview.rules.isEmpty)
                      const AppText(
                        'No alert rules for this observing location.',
                      ),
                    if (overview.rules.isNotEmpty &&
                        overview.notificationsEnabled &&
                        overview.monitoredRules.isEmpty)
                      const AppText('No enabled alert rules at this location.'),
                    if (overview.monitoredRules.isNotEmpty) ...[
                      AppText(
                        'Monitored targets',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final rule in overview.monitoredRules.take(limit))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rule.targetName,
                                  key: ValueKey(
                                    'dashboard-alert-rule-${rule.id}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!compact)
                                Text(
                                  '≥${rule.minimumScore.toStringAsFixed(0)} / 100',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                    ],
                    if (showHistory &&
                        overview.recentNotifications.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AppText(
                        'Recently notified opportunities',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final entry in overview.recentNotifications.take(
                        limit,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.rule.targetName,
                                key: ValueKey(
                                  'dashboard-alert-delivered-${entry.rule.id}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${appTranslate(context, 'Notified')}: '
                                '${_localClock(entry.notifiedAtUtc, site.timeZone)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (!compact)
                                Text(
                                  '${appTranslate(context, 'Observing night')}: '
                                  '${_localClock(entry.nightStartUtc, site.timeZone).split(' ').first}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    AppText(
                      'Checks run at app start, foreground or manually; no continuous background monitoring.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      key: const ValueKey('dashboard-alerts-manage'),
                      onPressed: () => context.go(AppRoutes.settings),
                      icon: const Icon(Icons.tune_outlined),
                      label: const AppText('Manage alerts in Settings'),
                    ),
                  ],
                );
              },
            );
          },
        );
  }
}
