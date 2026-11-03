import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../locations/domain/models/observing_location.dart';
import '../application/light_pollution_providers.dart';
import '../data/light_pollution_repository.dart';
import '../domain/light_pollution.dart';

/// Lazy load: never send a network request for every saved location just
/// because Settings > Observing Locations was opened.
class LightPollutionLocationPanel extends ConsumerStatefulWidget {
  const LightPollutionLocationPanel({super.key, required this.site});
  final ObservingLocation site;

  @override
  ConsumerState<LightPollutionLocationPanel> createState() =>
      _LightPollutionLocationPanelState();
}

class _LightPollutionLocationPanelState
    extends ConsumerState<LightPollutionLocationPanel> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    final request = lightPollutionRequest(widget.site);
    final display = _enabled
        ? ref.watch(lightPollutionSnapshotProvider(request))
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Light pollution',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!_enabled)
                OutlinedButton(
                  key: ValueKey('night-lights-${widget.site.id}'),
                  onPressed: () => setState(() => _enabled = true),
                  child: const AppText('Check satellite data'),
                )
              else
                IconButton(
                  tooltip: appTranslate(context, 'Refresh satellite data'),
                  onPressed: () async {
                    try {
                      await ref
                          .read(lightPollutionRepositoryProvider)
                          .load(
                            latitude: request.latitude,
                            longitude: request.longitude,
                            forceRefresh: true,
                          );
                      if (mounted) {
                        ref.invalidate(lightPollutionSnapshotProvider(request));
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: AppText('Refresh unavailable: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          if (display != null)
            display.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => AppText(
                'Night-light data unavailable: $error',
                key: const ValueKey('light-pollution-error'),
              ),
              data: (snapshot) => _details(snapshot),
            ),
        ],
      ),
    );
  }

  Widget _details(LightPollutionSnapshot snapshot) {
    final reading = snapshot.reading;
    if (reading == null) {
      return const AppText(
        'No valid night-light data at this location. '
        'No darkness classification is inferred.',
      );
    }
    final score = SatelliteRadianceIndicator.relativeDarknessScore(reading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '${reading.kindLabel}: ${reading.value.toStringAsFixed(2)} ${reading.unit}',
          key: const ValueKey('light-pollution-value'),
        ),
        AppText(
          'Dataset: ${reading.datasetDate.year}-${reading.datasetDate.month.toString().padLeft(2, '0')} '
          '· ${reading.sourceName}',
        ),
        if (reading.sourceCatalogUpdatedAt != null)
          AppText(
            'Source catalogue updated: '
            '${reading.sourceCatalogUpdatedAt!.year}-'
            '${reading.sourceCatalogUpdatedAt!.month.toString().padLeft(2, '0')}-'
            '${reading.sourceCatalogUpdatedAt!.day.toString().padLeft(2, '0')} '
            '(not the acquisition date)',
          ),
        AppText(reading.description),
        if (score != null)
          AppText(
            'Relative night-light indicator: ${score.toStringAsFixed(0)}/100 '
            '(higher = less upward radiance; not SQM/Bortle)',
          ),
        if (snapshot.fromCache)
          AppText(
            snapshot.isStale
                ? 'Old cached reading — source refresh failed.'
                : 'Locally cached result.',
          ),
        if (snapshot.refreshError != null)
          const AppText('Online refresh failed; showing a cached reading.'),
        const AppText(
          'Upward radiance is not a sky brightness measurement. '
          'Nearby lights, terrain, cloud, snow and atmospheric scattering '
          'can change actual observing conditions.',
        ),
        if (reading.sourceUrl != null)
          SelectableText('Source: ${reading.sourceUrl}'),
      ],
    );
  }
}
