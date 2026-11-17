import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_text.dart';
import '../../locations/domain/models/observing_location.dart';
import '../application/terrain_providers.dart';
import '../data/terrain_profile_repository.dart';
import '../domain/terrain_horizon.dart';
import 'terrain_horizon_chart.dart';

class TerrainLocationPanel extends ConsumerStatefulWidget {
  const TerrainLocationPanel({super.key, required this.site});

  final ObservingLocation site;

  @override
  ConsumerState<TerrainLocationPanel> createState() =>
      _TerrainLocationPanelState();
}

class _TerrainLocationPanelState extends ConsumerState<TerrainLocationPanel> {
  bool _fetching = false;
  String? _failure;

  Future<void> _fetch(TerrainHorizonOptions options) async {
    setState(() {
      _fetching = true;
      _failure = null;
    });
    String? failure;
    try {
      await ref
          .read(terrainProfileRepositoryProvider)
          .load(widget.site, options, forceRefresh: true);
    } on TerrainCoverageUnavailable {
      failure = 'No usable elevation data for this site and search radius.';
    } catch (_) {
      failure = 'Could not load elevation data. Check your connection or try again later.';
    } finally {
      if (mounted) {
        setState(() {
          _fetching = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final cached = ref.watch(cachedTerrainProfileProvider(site));
    final profile = cached.value?.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppText(
                'Terrain horizon',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              OutlinedButton(
                key: ValueKey('location-terrain-fetch-${site.id}'),
                onPressed: _fetching || cached.isLoading
                    ? null
                    : () => _fetch(
                        profile?.options ?? const TerrainHorizonOptions(),
                      ),
                child: AppText(
                  profile == null
                      ? 'Load terrain profile'
                      : 'Refresh terrain profile',
                ),
              ),
            ],
          ),
          if (_fetching || cached.isLoading) const LinearProgressIndicator(),
          if (_fetching)
            const AppText(
              'Calculating terrain horizon (online fetch or local cache)…',
            ),
          if (_failure case final failure?)
            Semantics(liveRegion: true, child: AppText(failure))
          else if (cached.hasError)
            const AppText('Unable to read the saved terrain profile.')
          else if (profile == null && !cached.isLoading && !_fetching)
            const AppText('No terrain profile saved for this site.'),
          if (profile != null) ...[
            if (cached.value!.isStale) const AppText('Outdated cached data'),
            TerrainHorizonChart(profile: profile),
            Text(
              '${appTranslate(context, 'Known bearings')}: ${profile.knownBearings}/${profile.bearings.length}',
            ),
            if (profile.sourceId.startsWith('opentopodata:'))
              const Text('EU-DEM (Copernicus) · OpenTopoData'),
          ],
        ],
      ),
    );
  }
}
