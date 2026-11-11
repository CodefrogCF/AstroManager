import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/astronomy/solar_events.dart';
import '../../../../l10n/app_text.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../../weather/application/weather_providers.dart';
import '../../../weather/domain/providers/weather_provider.dart';
import '../../domain/dashboard_layout.dart';
import '../../domain/seven_night_weather.dart';
import 'dashboard_widget_state.dart';

/// Loads forecast data only while the widget is mounted and visible.
/// Its request reuses the existing weather service, cache and deduplication.
class SevenNightWeatherWidget extends StatelessWidget {
  const SevenNightWeatherWidget({
    required this.location,
    required this.instance,
    super.key,
  });

  final ObservingLocation? location;
  final DashboardWidgetInstance instance;

  @override
  Widget build(BuildContext context) {
    final site = location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty(
          'Add an observing location in Settings to personalize the dashboard.',
        ),
        dataBuilder: _empty,
      );
    }

    final maxCloud =
        int.tryParse(instance.settings['maxCloudPercent'] as String? ?? '30') ??
        30;
    final minHours =
        int.tryParse(instance.settings['minClearHours'] as String? ?? '2') ?? 2;
    final options = SevenNightWeatherOptions(
      maximumCloudPercent: maxCloud,
      minimumClearDuration: Duration(hours: minHours),
    );
    final now = DateTime.now().toUtc();
    final nights = SevenNightWeatherAggregator.upcomingNights(
      location: site,
      nowUtc: now,
    );
    final start = DateTime.utc(now.year, now.month, now.day, now.hour);
    final request = WeatherForecastRequest(
      latitudeDegrees: site.latitude,
      longitudeDegrees: site.longitude,
      startUtc: start,
      endUtc: nights.last.nightEndUtc,
    );
    // Keep the displayed request window stable as its refresh state changes.
    return Consumer(
      builder: (context, ref, _) =>
          _buildForecast(context, ref, request, nights, options),
    );
  }

  Widget _buildForecast(
    BuildContext context,
    WidgetRef ref,
    WeatherForecastRequest request,
    List<SolarDayEvents> nights,
    SevenNightWeatherOptions options,
  ) {
    final provider = weatherForecastSnapshotProvider(request);
    final forecast = ref.watch(provider);
    final policy = ref.watch(weatherCachePolicyProvider);
    final refreshLabel = appTranslate(context, 'Refresh forecast');
    Future<void> refresh() => ref.read(provider.notifier).refreshForecast();
    return forecast.when(
      skipLoadingOnReload: forecast.hasValue,
      skipLoadingOnRefresh: forecast.hasValue,
      skipError: true,
      loading: () => const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.loading(),
        dataBuilder: _empty,
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Weather forecast unavailable. Check your connection.'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: forecast.isLoading ? null : refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(refreshLabel),
          ),
        ],
      ),
      data: (snapshot) {
        final now = DateTime.now().toUtc();
        final updating = forecast.isLoading || snapshot.refreshInProgress;
        final refreshFailed =
            forecast.hasError || snapshot.refreshError != null;
        final summaries = SevenNightWeatherAggregator.calculate(
          nights: nights,
          forecast: snapshot.forecast,
          nowUtc: now,
          options: options,
        );
        final stale = snapshot.isStaleAt(now, policy);
        final age = now.difference(snapshot.forecast.fetchedAtUtc);
        final hours = math.max(0, age.inHours);
        final minutes = math.max(0, age.inMinutes);
        final ageLabel = hours > 0 ? '${hours}h' : '${minutes}m';
        final labelStyle = Theme.of(context).textTheme.labelSmall;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 480;
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            // In dashboard cards the parent already scrolls vertically and
            // gives this widget unbounded height. Standalone and widget-test
            // hosts can instead provide a fixed height: allow the complete
            // forecast (including attribution) to scroll at large text sizes
            // rather than overflowing its vertical Column.
            final content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 7,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                stale
                                    ? Icons.cloud_off_outlined
                                    : Icons.cloud_outlined,
                                size: 15,
                                color: stale
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              AppText(
                                snapshot.forecast.provider.name,
                                style: labelStyle,
                              ),
                              Text('· $ageLabel', style: labelStyle),
                              if (stale) const AppText('Stale forecast'),
                              if (snapshot.isOfflineFallback)
                                const AppText('Offline cache'),
                              if (updating)
                                Semantics(
                                  liveRegion: true,
                                  child: const AppText('Updating'),
                                ),
                            ],
                          ),
                          Text(
                            '${appTranslate(context, 'Cloud limit')}: ${options.maximumCloudPercent}% · '
                            '${appTranslate(context, 'Minimum clear')}: ${options.minimumClearDuration.inHours}h',
                            style: labelStyle,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: refreshLabel,
                      onPressed: updating ? null : refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (!updating && refreshFailed)
                  Semantics(
                    liveRegion: true,
                    child: const AppText(
                      'Could not refresh. Showing the last forecast.',
                    ),
                  ),
                const SizedBox(height: 7),
                SizedBox(
                  height: (wide ? 128.0 : 120.0) * math.max(1, textScale),
                  child: ListView.separated(
                    key: const ValueKey('dashboard-seven-nights'),
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    itemCount: summaries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (context, index) => _NightTile(
                      summary: summaries[index],
                      options: options,
                      expanded: wide,
                      onTap: () => _showNightDetails(context, summaries[index]),
                    ),
                  ),
                ),
                if (snapshot.forecast.provider.attribution
                    case final attribution?) ...[
                  const SizedBox(height: 5),
                  AppText(attribution, style: labelStyle),
                ],
              ],
            );
            if (!constraints.hasBoundedHeight) {
              return content;
            }
            return SingleChildScrollView(
              primary: false,
              scrollDirection: Axis.vertical,
              child: content,
            );
          },
        );
      },
    );
  }

  static Widget _empty(BuildContext context, Object data) =>
      const SizedBox.shrink();
}

class _NightTile extends StatelessWidget {
  const _NightTile({
    required this.summary,
    required this.options,
    required this.expanded,
    required this.onTap,
  });

  final NightWeatherSummary summary;
  final SevenNightWeatherOptions options;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasData = summary.hasForecast;
    final clear = summary.qualifies(options);
    final color = !hasData
        ? colorScheme.onSurfaceVariant
        : clear
        ? colorScheme.primary
        : colorScheme.secondary;
    final date = MaterialLocalizations.of(context)
        .formatShortDate(summary.localDate);
    final cloud = summary.averageCloudPercent;
    final coverage = summary.remainingDarkness.inMinutes > 0
        ? (100 *
                  summary.forecastCoverage.inMinutes /
                  summary.remainingDarkness.inMinutes)
              .clamp(0, 100)
              .round()
        : 0;
    final title = !summary.hasDarkness
        ? appTranslate(context, 'No astronomical darkness')
        : !hasData
        ? appTranslate(context, 'No forecast coverage')
        : '${_duration(summary.clearDuration)} ${appTranslate(context, 'clear')}'
              ' · $coverage% ${appTranslate(context, 'covered')}';
    return Semantics(
      button: true,
      label: '$date, $title',
      child: InkWell(
        key: ValueKey(
          'dashboard-night-${summary.localDate.toIso8601String().substring(0, 10)}',
        ),
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: expanded ? 145 : 116,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          // Keep compact night cards usable in small dashboard grid cells.
          // Date and weather icons share a row instead of consuming a second
          // full line. At larger accessibility text sizes, the card content
          // can scroll rather than overflowing its fixed-height viewport.
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Icon(
                      !hasData
                          ? Icons.help_outline
                          : clear
                          ? Icons.nights_stay_outlined
                          : Icons.cloud_outlined,
                      size: 18,
                      color: color,
                    ),
                    if (hasData)
                      Tooltip(
                        message: appTranslate(context, summary.trend.name),
                        child: Icon(
                          switch (summary.trend) {
                            NightCloudTrend.improving => Icons.trending_down,
                            NightCloudTrend.stable => Icons.trending_flat,
                            NightCloudTrend.worsening => Icons.trending_up,
                            NightCloudTrend.unknown => Icons.help_outline,
                          },
                          size: 18,
                          color: color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  !hasData
                      ? '—'
                      : '${_duration(summary.clearDuration)} ${appTranslate(context, 'clear')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  cloud == null
                      ? '${appTranslate(context, 'Cloud cover')}: —'
                      : '${appTranslate(context, 'Cloud cover')}: ${cloud.round()}%',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '$coverage% ${appTranslate(context, 'covered')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _duration(Duration value) {
  final hours = value.inMinutes ~/ 60;
  final minutes = value.inMinutes % 60;
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

void _showNightDetails(BuildContext context, NightWeatherSummary night) {
  final date = MaterialLocalizations.of(context)
      .formatMediumDate(night.localDate);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                '${appTranslate(sheetContext, 'Astronomical darkness')}: ${_duration(night.darkness)}',
              ),
              Text(
                '${appTranslate(sheetContext, 'Forecast coverage')}: ${_duration(night.forecastCoverage)}'
                ' / ${_duration(night.remainingDarkness)} ${appTranslate(sheetContext, 'remaining')}',
              ),
              Text(
                '${appTranslate(sheetContext, 'Qualifying clear hours')}: ${_duration(night.clearDuration)}',
              ),
              Text(
                '${appTranslate(sheetContext, 'Longest clear period')}: ${_duration(night.longestClearInterval)}',
              ),
              Text(
                '${appTranslate(sheetContext, 'Average cloud cover')}: '
                '${night.averageCloudPercent == null ? '—' : '${night.averageCloudPercent!.round()}%'}',
              ),
              Text(
                '${appTranslate(sheetContext, 'Cloud trend')}: '
                '${appTranslate(sheetContext, night.trend.name)}',
              ),
              if (!night.isComplete)
                const AppText(
                  'Forecast incomplete: uncovered hours are unknown, not clear.',
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.go(AppRoutes.planner);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const AppText('Open Night Planner'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
