import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../l10n/app_text.dart';
import '../../../light_pollution/domain/light_pollution.dart';
import '../../../locations/domain/models/observing_location.dart';
import '../../../terrain/presentation/terrain_horizon_chart.dart';
import '../../application/observing_site_conditions_provider.dart';
import '../../domain/observing_site_conditions.dart';
import 'dashboard_widget_state.dart';

/// Enhances the original 'observing-site' tile without changing its type ID or
/// stored layout. All environmental data comes from offline caches only.
class ObservingSiteConditionsWidget extends ConsumerStatefulWidget {
  const ObservingSiteConditionsWidget({
    super.key,
    required this.location,
    this.showCoordinates = true,
    this.showDetailsInitially = false,
  });

  final ObservingLocation? location;
  final bool showCoordinates;
  final bool showDetailsInitially;

  @override
  ConsumerState<ObservingSiteConditionsWidget> createState() =>
      _ObservingSiteConditionsWidgetState();
}

class _ObservingSiteConditionsWidgetState
    extends ConsumerState<ObservingSiteConditionsWidget> {
  late bool _showDetails;

  @override
  void initState() {
    super.initState();
    _showDetails = widget.showDetailsInitially;
  }

  @override
  void didUpdateWidget(covariant ObservingSiteConditionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showDetailsInitially != oldWidget.showDetailsInitially) {
      _showDetails = widget.showDetailsInitially;
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty('No observing location selected.'),
        dataBuilder: _empty,
      );
    }

    final result = ref.watch(observingSiteConditionsProvider(site));
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 310;
        final expanded = !narrow || _showDetails;

        // The site identity and actions must remain usable even if reading the
        // optional terrain/night-light caches is slow or fails. They are not
        // conditional on a successful snapshot.
        return SingleChildScrollView(
          primary: false,
          child: Column(
            key: const ValueKey('dashboard-observing-site-conditions'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      site.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('dashboard-site-refresh-cache'),
                    tooltip: appTranslate(context, 'Refresh cached site data'),
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () =>
                        ref.invalidate(observingSiteConditionsProvider(site)),
                  ),
                ],
              ),
              Text(site.timeZone, style: Theme.of(context).textTheme.bodySmall),
              if (widget.showCoordinates)
                Text(
                  '${site.latitude.toStringAsFixed(3)}°, '
                  '${site.longitude.toStringAsFixed(3)}°',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              const SizedBox(height: 6),
              result.when(
                loading: () => const DashboardWidgetStateView<Object>(
                  state: DashboardLoadState.loading(),
                  dataBuilder: _empty,
                ),
                error: (_, _) => const DashboardWidgetStateView<Object>(
                  state: DashboardLoadState.error(
                    'Unable to read cached site conditions.',
                  ),
                  dataBuilder: _empty,
                ),
                data: (snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CachedSummary(snapshot: snapshot),
                    const SizedBox(height: 4),
                    const AppText(
                      'Cache only · no automatic data requests',
                      style: TextStyle(fontSize: 11),
                    ),
                    if (narrow)
                      TextButton.icon(
                        key: const ValueKey('dashboard-site-details-toggle'),
                        onPressed: () =>
                            setState(() => _showDetails = !_showDetails),
                        icon: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                        label: AppText(
                          expanded ? 'Hide details' : 'Show details',
                        ),
                      ),
                    if (expanded) ...[
                      const Divider(height: 14),
                      _CachedDetails(
                        snapshot: snapshot,
                        showChart: constraints.maxWidth >= 340,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  TextButton.icon(
                    key: const ValueKey('dashboard-site-manage-data'),
                    onPressed: () => context.go(AppRoutes.locations),
                    icon: const Icon(Icons.place_outlined, size: 17),
                    label: const AppText('Manage site data'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('dashboard-site-compare'),
                    onPressed: () => context.go(AppRoutes.locationsComparison),
                    icon: const Icon(Icons.compare_arrows, size: 17),
                    label: const AppText('Compare observing sites'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _empty(BuildContext context, Object data) =>
      const SizedBox.shrink();
}

class _CachedSummary extends StatelessWidget {
  const _CachedSummary({required this.snapshot});
  final ObservingSiteConditions snapshot;

  @override
  Widget build(BuildContext context) {
    final terrain = snapshot.terrain;
    final lights = snapshot.nightLightReading;
    final theme = Theme.of(context);
    final staleLabel = appTranslate(context, 'Outdated cached data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.terrain,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Terrain horizon',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (terrain == null)
                    const AppText('Not available')
                  else
                    Text(
                      '${snapshot.knownTerrainBearings}/${terrain.bearings.length} '
                      '${appTranslate(context, 'Known bearings')}'
                      '${snapshot.terrainStale ? ' · $staleLabel' : ''}',
                      key: const ValueKey('dashboard-site-terrain-summary'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.nightlight_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    lights != null &&
                            lights.kind != NightLightKind.satelliteRadiance
                        ? _kindLabel(lights.kind)
                        : 'Night-light radiance',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (lights == null)
                    const AppText('Not available')
                  else
                    Text(
                      '${lights.value.toStringAsFixed(2)} ${lights.unit}'
                      '${snapshot.nightLights?.isStale == true ? ' · $staleLabel' : ''}',
                      key: const ValueKey('dashboard-site-light-summary'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _kindLabel(NightLightKind kind) => switch (kind) {
  NightLightKind.satelliteRadiance => 'Satellite upward radiance',
  NightLightKind.measuredSkyBrightness => 'Measured zenith sky brightness',
  NightLightKind.modeledSkyBrightness => 'Modeled zenith sky brightness',
};

class _CachedDetails extends StatelessWidget {
  const _CachedDetails({required this.snapshot, required this.showChart});
  final ObservingSiteConditions snapshot;
  final bool showChart;

  String _date(DateTime utc) =>
      '${utc.year}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final terrain = snapshot.terrain;
    final lights = snapshot.nightLightReading;
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Column(
      key: const ValueKey('dashboard-site-details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (terrain == null)
          const AppText(
            'No cached terrain profile. Check the site details to load one.',
          )
        else ...[
          Text(
            '${appTranslate(context, 'Profile generated')}: ${_date(terrain.createdAtUtc)}',
            style: textStyle,
          ),
          Text(
            '${appTranslate(context, 'Source')}: ${terrain.sourceId}',
            style: textStyle,
          ),
          if (terrain.sourceId.startsWith('opentopodata:'))
            SelectableText(
              'EU-DEM (Copernicus) · OpenTopoData · https://www.opentopodata.org/api/',
              style: textStyle,
            ),
          const AppText(
            'Modeled terrain horizon is not surveyed line of sight. Unknown bearings remain unknown.',
            style: TextStyle(fontSize: 11),
          ),
          if (showChart && terrain.knownBearings > 0)
            TerrainHorizonChart(profile: terrain),
        ],
        const SizedBox(height: 9),
        if (lights == null)
          const AppText(
            'No cached night-light data. Check the site details to load a sample.',
          )
        else ...[
          AppText(_kindLabel(lights.kind)),
          Text(
            '${appTranslate(context, 'Dataset month')}: '
            '${lights.datasetDate.year}-${lights.datasetDate.month.toString().padLeft(2, '0')}',
            style: textStyle,
          ),
          if (snapshot.nightLights?.checkedAtUtc case final DateTime checked)
            Text(
              '${appTranslate(context, 'Retrieved')}: ${_date(checked)} UTC',
              style: textStyle,
            ),
          Text(
            '${appTranslate(context, 'Source')}: ${lights.sourceName}',
            style: textStyle,
          ),
          if (lights.sourceCatalogUpdatedAt case final DateTime updated)
            Text(
              '${appTranslate(context, 'Source catalogue updated')}: ${_date(updated)}',
              style: textStyle,
            ),
          Text(lights.description, style: textStyle),
          if (lights.license case final String license)
            Text(license, style: textStyle),
          if (lights.sourceUrl case final String source)
            SelectableText(source, style: textStyle),
          if (lights.kind == NightLightKind.satelliteRadiance)
            const AppText(
              'Satellite radiance is not measured sky brightness or a Bortle class.',
              style: TextStyle(fontSize: 11),
            ),
        ],
      ],
    );
  }
}
