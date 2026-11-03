import 'package:astromanager/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/astronomy/solar_events.dart';
import '../../light_pollution/application/light_pollution_providers.dart';
import '../../light_pollution/data/light_pollution_repository.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../projects/data/planned_projects_repository.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../terrain/application/terrain_providers.dart';
import '../../terrain/domain/terrain_horizon.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../../weather/domain/providers/weather_provider.dart';
import '../domain/observing_site_comparison.dart';

/// Project-linked catalog targets, resolved offline. No catalog or weather
/// loading occurs until the comparison panel is explicitly opened.
final siteComparisonTargetsProvider = FutureProvider<List<CelestialObject>>((
  ref,
) async {
  final projects = await ref.watch(plannedProjectsListProvider.future);
  final ids = projects.expand((project) => project.targetIds).toSet();
  if (ids.isEmpty) {
    return [];
  }
  await ref.watch(celestialCatalogProvider.future);
  final catalog = ref.watch(celestialCatalogRepositoryProvider);
  final targets = <CelestialObject>[];
  for (final id in ids) {
    final target = await catalog.findById(id);
    if (target != null) {
      targets.add(target);
    }
  }
  targets.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  return targets;
}, retry: (count, error) => null);

class ObservingSiteComparisonPanel extends ConsumerStatefulWidget {
  const ObservingSiteComparisonPanel({super.key, required this.sites});

  final List<ObservingLocation> sites;

  @override
  ConsumerState<ObservingSiteComparisonPanel> createState() =>
      _ObservingSiteComparisonPanelState();
}

class _ObservingSiteComparisonPanelState
    extends ConsumerState<ObservingSiteComparisonPanel> {
  bool _expanded = false;
  final Set<String> _siteIds = {};
  String? _targetId;
  DateTime _date = DateTime.now();
  bool _terrain = true;
  bool _nightLights = true;
  bool _busy = false;
  int _completed = 0;
  int _revision = 0;
  SiteComparisonReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _siteIds.addAll(widget.sites.take(2).map((site) => site.id));
  }

  @override
  void didUpdateWidget(covariant ObservingSiteComparisonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.sites.map((site) => site.id).toSet();
    _siteIds.removeWhere((id) => !currentIds.contains(id));
    if (_siteIds.isEmpty) {
      _siteIds.addAll(widget.sites.take(2).map((site) => site.id));
    }
    if (oldWidget.sites != widget.sites) {
      _revision++;
      _report = null;
    }
  }

  void _changed(VoidCallback mutation) {
    setState(() {
      mutation();
      _revision++;
      _report = null;
      _error = null;
    });
  }

  List<ObservingLocation> get _selectedSites {
    final chosen = widget.sites
        .where((site) => _siteIds.contains(site.id))
        .toList();
    return chosen;
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (mounted && value != null) {
      _changed(() => _date = value);
    }
  }

  String get _dateLabel =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  Future<SiteComparisonInput> _load(
    ObservingLocation site,
    bool terrainRequested,
    bool lightsRequested,
    DateTime selectedDate,
    DateTime now,
  ) async {
    final night = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: selectedDate,
    );
    final weatherPossible =
        night.nightEndUtc.isAfter(now) &&
        night.nightStartUtc.isBefore(now.add(const Duration(days: 14)));
    final forecastRequest = WeatherForecastRequest(
      latitudeDegrees: site.latitude,
      longitudeDegrees: site.longitude,
      startUtc: night.nightStartUtc,
      endUtc: night.nightEndUtc,
    );

    // Keep failures isolated per site and per source: one API failure must not
    // prevent comparison of all available astronomical and cached data.
    final weatherService = ref.read(weatherForecastServiceProvider);
    final terrainRepository = ref.read(terrainProfileRepositoryProvider);
    final lightsRepository = ref.read(lightPollutionRepositoryProvider);
    WeatherForecastSnapshot? weather;
    String? weatherError;
    if (weatherPossible) {
      try {
        weather = await weatherService.load(forecastRequest);
      } catch (error) {
        weatherError = error.toString();
      }
    } else {
      weatherError = 'No current forecast covers this date.';
    }

    TerrainHorizonProfile? horizon;
    String? terrainError;
    if (terrainRequested) {
      try {
        horizon = await terrainRepository.load(
          site,
          const TerrainHorizonOptions(
            azimuthStepDegrees: 15,
            maximumDistanceMeters: 15000,
            distanceStepMeters: 1500,
          ),
        );
      } catch (error) {
        terrainError = error.toString();
      }
    }

    LightPollutionSnapshot? lights;
    String? lightError;
    if (lightsRequested) {
      try {
        lights = await lightsRepository.load(
          latitude: site.latitude,
          longitude: site.longitude,
        );
      } catch (error) {
        lightError = error.toString();
      }
    }

    return SiteComparisonInput(
      site: site,
      weather: weather,
      weatherError: weatherError,
      terrain: horizon,
      terrainError: terrainError,
      lightPollution: lights,
      lightPollutionError: lightError,
    );
  }

  Future<void> _compare(CelestialObject target) async {
    if (_busy) {
      return;
    }
    final selected = _selectedSites;
    if (selected.length < 2) {
      return;
    }
    final date = _date;
    final includeTerrain = _terrain;
    final includeLights = _nightLights;
    final revision = ++_revision;
    final evaluatedAt = DateTime.now().toUtc();
    setState(() {
      _busy = true;
      _completed = 0;
      _error = null;
      _report = null;
    });
    try {
      final inputs = <SiteComparisonInput>[];
      // The public DEM endpoint is rate-limited; process selected sites one by
      // one instead of launching uncontrolled parallel elevation requests.
      for (final site in selected) {
        inputs.add(
          await _load(site, includeTerrain, includeLights, date, evaluatedAt),
        );
        if (!mounted || revision != _revision) {
          return;
        }
        setState(() => _completed++);
      }
      final report = ObservingSiteComparison.compare(
        target: target,
        localDate: date,
        evaluatedAtUtc: evaluatedAt,
        sites: inputs,
        options: SiteComparisonOptions(
          compareTerrain: includeTerrain,
          compareLightPollution: includeLights,
        ),
        weatherPolicy: ref.read(weatherCachePolicyProvider),
      );
      if (mounted && revision == _revision) {
        setState(() => _report = report);
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sites.length < 2) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const ValueKey('site-comparison-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    'Compare observing sites',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  key: const ValueKey('site-comparison-expand'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: AppText(_expanded ? 'Hide' : 'Compare'),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const AppText(
                'Choose at least two sites, one project target, and '
                'a common local calendar date. Weather and terrain data '
                'are requested only when you run the comparison.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final site in widget.sites)
                    FilterChip(
                      key: ValueKey('compare-site-${site.id}'),
                      label: AppText(site.name),
                      selected: _selectedSites.any(
                        (entry) => entry.id == site.id,
                      ),
                      onSelected: _busy
                          ? null
                          : (selected) => _changed(() {
                              if (selected) {
                                _siteIds.add(site.id);
                              } else {
                                _siteIds.remove(site.id);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _targetSelector(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('compare-date'),
                    onPressed: _busy ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: AppText(_dateLabel),
                  ),
                  FilterChip(
                    key: const ValueKey('compare-terrain'),
                    label: const AppText('Terrain horizon'),
                    selected: _terrain,
                    onSelected: _busy
                        ? null
                        : (value) => _changed(() => _terrain = value),
                  ),
                  FilterChip(
                    key: const ValueKey('compare-nightlights'),
                    label: const AppText('Satellite night lights'),
                    selected: _nightLights,
                    onSelected: _busy
                        ? null
                        : (value) => _changed(() => _nightLights = value),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
                AppText(
                  'Comparing $_completed / ${_selectedSites.length} locations...',
                ),
              ],
              if (_error != null)
                AppText(
                  'Comparison failed: $_error',
                  key: const ValueKey('site-comparison-error'),
                ),
              if (_report != null) _results(_report!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _targetSelector() {
    final asyncTargets = ref.watch(siteComparisonTargetsProvider);
    return asyncTargets.when(
      loading: () => const AppText('Loading project targets...'),
      error: (error, _) => AppText('Project targets unavailable: $error'),
      data: (targets) {
        if (targets.isEmpty) {
          return const AppText(
            'Create an imaging project with a catalog target '
            'before comparing sites.',
          );
        }
        final targetId = targets.any((item) => item.id == _targetId)
            ? _targetId!
            : targets.first.id;
        final target = targets.firstWhere((item) => item.id == targetId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('compare-target-$targetId'),
              initialValue: targetId,
              isExpanded: true,
              decoration: localizeDecoration(
                context,
                const InputDecoration(labelText: 'Project target'),
              ),
              items: [
                for (final value in targets)
                  DropdownMenuItem(
                    value: value.id,
                    child: AppText(
                      value.displayTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        _changed(() => _targetId = value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('compare-run'),
              onPressed: _busy || _selectedSites.length < 2
                  ? null
                  : () => _compare(target),
              icon: const Icon(Icons.query_stats),
              label: const AppText('Compare selected sites'),
            ),
            if (_selectedSites.length < 2)
              const AppText('Select at least two saved locations.'),
          ],
        );
      },
    );
  }

  Widget _results(SiteComparisonReport report) {
    final leader = report.leader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        AppText(
          'Comparison for ${report.target.displayTitle} · $_dateLabel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppText(
          'Leading estimate: ${leader.site.name} '
          '(${leader.score.toStringAsFixed(1)}/100). '
          '${leader.isProvisional ? 'Incomplete data; interpret cautiously.' : 'All requested data sources available.'}',
        ),
        const AppText(
          'Heuristic suitability, not a guarantee of visibility or image '
          'quality. Date refers to each site’s local observing night.',
        ),
        const SizedBox(height: 8),
        for (final result in report.rankedSites)
          Card(
            key: ValueKey('site-comparison-result-${result.site.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    '${result.site.name} · ${result.score.toStringAsFixed(1)}/100'
                    '${result.isProvisional ? ' (provisional)' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: result.score / 100),
                  const SizedBox(height: 8),
                  AppText(
                    'Darkness: ${result.astronomicalDarkness.inMinutes} min · '
                    'Visible target: ${result.visibleDuration.inMinutes} min · '
                    'Best altitude: ${result.bestAltitudeDegrees == null ? 'n/a' : '${result.bestAltitudeDegrees!.toStringAsFixed(1)}°'}',
                  ),
                  AppText(
                    'Geometric visibility: '
                    '${result.geometricVisibleDuration.inMinutes} min · '
                    'Terrain: ${result.terrainKnownFraction == null ? 'not available' : '${(result.terrainKnownFraction! * 100).toStringAsFixed(0)}% DEM bearings available'}',
                  ),
                  AppText(
                    'Weather: ${!result.weatherUsable ? 'unavailable or stale' : '${result.weather!.forecast.provider.name} forecast'}',
                  ),
                  if (result.lightPollution?.reading != null)
                    AppText(
                      'Night lights: ${result.lightPollution!.reading!.value.toStringAsFixed(2)} '
                      '${result.lightPollution!.reading!.unit} '
                      '(${result.lightPollution!.reading!.sourceName}, '
                      '${result.lightPollution!.reading!.datasetDate.year})',
                    ),
                  if (result.missingData.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText(
                      'Missing/uncertain: ${result.missingData.join(' · ')}',
                    ),
                  ],
                  ExpansionTile(
                    title: const AppText('Reasons and scoring details'),
                    children: [
                      for (final explanation in result.explanations)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppText('• $explanation'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
