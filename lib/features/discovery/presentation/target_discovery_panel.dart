import 'dart:async';

import 'package:astromanager/l10n/app_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

import 'package:timezone/timezone.dart' as tz;

import '../../../core/astronomy/solar_events.dart';
import '../../equipment/application/equipment_controller.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../intelligence/domain/models/observation_window.dart';
import '../../intelligence/domain/models/suitability_score.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../../weather/domain/providers/weather_provider.dart';
import '../application/discovery_evaluator.dart';
import '../data/discovery_repositories.dart';
import '../domain/discovery_results.dart';

/// Interactive discovery; the catalog is seeded and queried locally. No
/// weather failure may prevent astronomy-only provisional recommendations.
class TargetDiscoveryPanel extends ConsumerStatefulWidget {
  const TargetDiscoveryPanel({super.key});

  @override
  ConsumerState<TargetDiscoveryPanel> createState() =>
      _TargetDiscoveryPanelState();
}

class _TargetDiscoveryPanelState extends ConsumerState<TargetDiscoveryPanel> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<ObservingLocation> _locations = const [];
  EquipmentInventory? _equipment;
  Set<String> _favorites = {};
  String? _locationId;
  String? _profileId;
  CelestialCategory? _category;
  DateTime _date = DateTime.now();
  int _durationMinutes = 60;
  double _minimumAltitude = 30;
  bool _favoritesOnly = false;
  bool _initializing = true;
  bool _loading = false;
  String? _initialError;
  String? _searchError;
  String? _weatherError;
  WeatherForecastSnapshot? _weather;
  int _candidatesConsidered = 0;
  int _generation = 0;
  List<RankedDiscoveryTarget> _ranked = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  ObservingLocation? get _site {
    for (final site in _locations) {
      if (site.id == _locationId) return site;
    }
    return _locations.isEmpty ? null : _locations.first;
  }

  OpticalMetrics? _opticalMetrics() {
    final inventory = _equipment;
    if (_profileId == null || inventory == null) return null;
    for (final profile in inventory.profiles) {
      if (profile.id == _profileId) {
        return inventory.metricsFor(profile);
      }
    }
    return null;
  }

  Future<void> _initialize() async {
    ++_generation;
    setState(() {
      _initializing = true;
      _initialError = null;
    });
    try {
      // The catalog controller imports the bundled OpenNGC snapshot once.
      await ref.read(celestialCatalogProvider.future);
      final locations = await ref.read(observingLocationsProvider.future);
      final equipment = await ref.read(equipmentProvider.future);
      final favorites = await ref.read(targetFavoritesStoreProvider).load();
      if (!mounted) return;
      final defaultSite = locations.isEmpty
          ? null
          : locations.firstWhere(
              (site) => site.isDefault,
              orElse: () => locations.first,
            );
      final nowAtSite = defaultSite == null
          ? DateTime.now()
          : tz.TZDateTime.from(
              DateTime.now().toUtc(),
              SolarEvents.timeZone(defaultSite.timeZone),
            );
      setState(() {
        _locations = locations;
        _equipment = equipment;
        _favorites = favorites;
        _locationId = defaultSite?.id;
        _profileId = equipment.profiles.isEmpty
            ? null
            : equipment.profiles.first.id;
        _date = DateTime(nowAtSite.year, nowAtSite.month, nowAtSite.day);
        _initializing = false;
      });
      await _recompute();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initialError = error.toString();
      });
    }
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    // Discard pending computations immediately rather than show an old result.
    ++_generation;
    _debounce = Timer(const Duration(milliseconds: 350), _recompute);
  }

  Future<void> _recompute() async {
    _debounce?.cancel();
    final site = _site;
    final revision = ++_generation;
    bool current() => mounted && revision == _generation;
    if (site == null) {
      if (mounted) {
        setState(() {
          _ranked = const [];
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _searchError = null;
      _weatherError = null;
      _weather = null;
      _ranked = const [];
      _candidatesConsidered = 0;
    });
    try {
      final candidates = await ref
          .read(discoveryCandidateSourceProvider)
          .load(
            query: _search.text.trim(),
            category: _category,
            favoriteIds: _favorites,
            favoritesOnly: _favoritesOnly,
          );
      if (!current()) return;
      final night = SolarEvents.calculateForLocalDate(
        location: site,
        localDate: _date,
      );
      WeatherForecastSnapshot? weather;
      String? weatherError;
      try {
        weather = await ref.read(
          weatherForecastSnapshotProvider(
            WeatherForecastRequest(
              latitudeDegrees: site.latitude,
              longitudeDegrees: site.longitude,
              startUtc: night.nightStartUtc,
              endUtc: night.nightEndUtc,
            ),
          ).future,
        );
      } catch (error) {
        // Offline without a cached forecast is a valid partial discovery mode.
        weatherError = error.toString();
      }
      if (!current()) return;
      OpticalMetrics? optics;
      String? opticalError;
      try {
        optics = _opticalMetrics();
      } catch (error) {
        opticalError = 'Selected optical setup is invalid: $error';
      }
      final now = DateTime.now().toUtc();
      final ranked = await ref
          .read(discoveryEvaluatorProvider)
          .evaluate(
            targets: candidates,
            location: site,
            localDate: _date,
            evaluatedAtUtc: now,
            minimumDurationMinutes: _durationMinutes,
            minimumAltitudeDegrees: _minimumAltitude,
            weather: weather,
            optics: optics,
            isCurrent: current,
          );
      if (!current()) return;
      setState(() {
        _ranked = ranked;
        _weather = weather;
        _weatherError = weatherError ?? opticalError;
        _candidatesConsidered = candidates.length;
        _loading = false;
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        _loading = false;
        _searchError = error.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || value == null) return;
    setState(() => _date = DateTime(value.year, value.month, value.day));
    await _recompute();
  }

  Future<void> _toggleFavorite(String id) async {
    final before = Set<String>.from(_favorites);
    final updated = Set<String>.from(before);
    if (!updated.add(id)) updated.remove(id);
    setState(() => _favorites = updated);
    try {
      await ref.read(targetFavoritesStoreProvider).save(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _favorites = before);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('Could not save favorite: $error')),
      );
      return;
    }
    if (mounted && _favoritesOnly) await _recompute();
  }

  String _time(DateTime utc, ObservingLocation site) {
    final local = tz.TZDateTime.from(utc, SolarEvents.timeZone(site.timeZone));
    return SolarEvents.formatLocal(local, includeDate: true);
  }

  String _dateText() =>
      '${_date.day.toString().padLeft(2, '0')}.'
      '${_date.month.toString().padLeft(2, '0')}.${_date.year}';

  Widget _control({required String title, required Widget child}) {
    return SizedBox(
      width: 235,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [AppText(title), const SizedBox(height: 5), child],
      ),
    );
  }

  String _forecastLabel(WeatherForecastSnapshot? snapshot, String? failure) {
    if (snapshot == null) {
      return failure == null
          ? 'Weather not available. Scores are provisional.'
          : 'Weather unavailable / offline. Scores are provisional.';
    }
    if (snapshot.isStale ||
        snapshot.isStaleAt(
          DateTime.now().toUtc(),
          ref.read(weatherCachePolicyProvider),
        ) ||
        snapshot.origin == WeatherForecastOrigin.staleFallback ||
        snapshot.origin == WeatherForecastOrigin.staleCache) {
      return 'STALE weather cache · not used as current forecast.';
    }
    return snapshot.isFromCache
        ? 'Forecast from fresh cache · ${snapshot.forecast.provider.name}'
        : 'Forecast from network · ${snapshot.forecast.provider.name}';
  }

  Widget _recommendationCard(
    RankedDiscoveryTarget item,
    ObservingLocation site,
  ) {
    final window = item.window;
    final object = item.object;
    final warnings = switch (window.weatherStatus) {
      WindowWeatherStatus.complete => 'Weather complete',
      WindowWeatherStatus.partial => 'Weather partial',
      WindowWeatherStatus.missing => 'Weather unavailable',
      WindowWeatherStatus.stale => 'Weather STALE',
    };
    return Card(
      key: ValueKey('recommendation-${object.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: AppText(window.score.score.round().toString()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        object.displayTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (object.commonNames.isNotEmpty)
                        AppText(
                          object.commonNames,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      AppText(
                        '${object.category.label} · ${object.constellation} · '
                        '${object.visualMagnitude == null ? 'V mag unknown' : 'V mag ${object.visualMagnitude!.toStringAsFixed(1)}'}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('favorite-${object.id}'),
                  tooltip: _favorites.contains(object.id)
                      ? 'Remove favorite'
                      : 'Add favorite',
                  icon: Icon(
                    _favorites.contains(object.id)
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  onPressed: () => unawaited(_toggleFavorite(object.id)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              '${_time(window.startUtc, site)} – ${_time(window.endUtc, site)}',
              key: ValueKey('window-time-${object.id}'),
            ),
            AppText(
              '${window.duration.inMinutes} min · '
              'Best altitude ${window.bestAltitudeDegrees?.toStringAsFixed(1) ?? 'unknown'}° · '
              '$warnings',
            ),
            if (window.isProvisional)
              const AppText('Provisional recommendation · incomplete inputs'),
            OutlinedButton.icon(
              key: ValueKey('details-recommendation-${object.id}'),
              onPressed: () => context.push(
                AppRoutes.targetDetails(object.id),
                extra: object,
              ),
              icon: const Icon(Icons.info_outline),
              label: const AppText('Target details'),
            ),
            OutlinedButton.icon(
              key: ValueKey('atlas-recommendation-${object.id}'),
              onPressed: () => context.push(AppRoutes.atlas, extra: object),
              icon: const Icon(Icons.public),
              label: const AppText('View in sky atlas'),
            ),
            ExpansionTile(
              key: ValueKey('score-details-${object.id}'),
              tilePadding: EdgeInsets.zero,
              title: AppText(
                'Why ${window.score.score.toStringAsFixed(0)}/100?',
              ),
              children: [
                for (final factor in SuitabilityFactor.values)
                  if (window.score.factors.containsKey(factor))
                    ListTile(
                      dense: true,
                      title: AppText(
                        '${factor.label}: '
                        '${window.score.factors[factor]!.rawScore?.toStringAsFixed(0) ?? 'unknown'}/100',
                      ),
                      subtitle: AppText(
                        window.score.factors[factor]!.explanation,
                      ),
                      trailing: AppText(
                        '+${window.score.factors[factor]!.contribution.toStringAsFixed(1)}',
                      ),
                    ),
                if (window.score.constraints.isNotEmpty)
                  for (final reason in window.score.constraints)
                    ListTile(dense: true, title: AppText(reason)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppText(window.explanation),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_initialError != null) {
      return Column(
        children: [
          AppText('Could not initialize discovery: $_initialError'),
          OutlinedButton(onPressed: _initialize, child: const AppText('Retry')),
        ],
      );
    }
    if (_locations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: AppText(
            'No observing location. Add one in Settings to discover targets.',
          ),
        ),
      );
    }
    final site = _site!;
    final profiles = _equipment?.profiles ?? const <OpticalProfile>[];
    return Column(
      key: const ValueKey('target-discovery-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Recommended astrophotography targets',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const AppText(
          'Ranked for your observing night. Only continuous dark, '
          'visible windows meeting the minimum duration are recommended.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _control(
              title: 'Observing location',
              child: DropdownButtonFormField<String>(
                key: const ValueKey('discovery-location'),
                isExpanded: true,
                initialValue: _locationId,
                items: [
                  for (final value in _locations)
                    DropdownMenuItem(
                      value: value.id,
                      child: AppText(value.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _locationId = value);
                  unawaited(_recompute());
                },
              ),
            ),
            _control(
              title: 'Observing date (${site.timeZone})',
              child: OutlinedButton.icon(
                key: const ValueKey('discovery-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: AppText(_dateText()),
              ),
            ),
            _control(
              title: 'Optical setup',
              child: DropdownButtonFormField<String>(
                key: const ValueKey('discovery-equipment'),
                isExpanded: true,
                initialValue: _profileId ?? 'none',
                items: [
                  const DropdownMenuItem(
                    value: 'none',
                    child: AppText('No setup selected'),
                  ),
                  for (final profile in profiles)
                    DropdownMenuItem(
                      value: profile.id,
                      child: AppText(profile.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _profileId = value == 'none' ? null : value);
                  unawaited(_recompute());
                },
              ),
            ),
            _control(
              title: 'Object category',
              child: DropdownButtonFormField<String>(
                key: const ValueKey('discovery-category'),
                isExpanded: true,
                initialValue: _category?.name ?? 'all',
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: AppText('All categories'),
                  ),
                  for (final category in CelestialCategory.values)
                    DropdownMenuItem(
                      value: category.name,
                      child: AppText(category.label),
                    ),
                ],
                onChanged: (value) {
                  setState(
                    () => _category = value == 'all' || value == null
                        ? null
                        : CelestialCategory.values.byName(value),
                  );
                  unawaited(_recompute());
                },
              ),
            ),
            _control(
              title: 'Minimum session duration',
              child: DropdownButtonFormField<int>(
                key: const ValueKey('discovery-duration'),
                initialValue: _durationMinutes,
                items: [
                  for (final minutes in [30, 60, 90, 120, 180])
                    DropdownMenuItem(
                      value: minutes,
                      child: AppText('$minutes minutes'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _durationMinutes = value);
                  unawaited(_recompute());
                },
              ),
            ),
            _control(
              title: 'Minimum target altitude',
              child: Column(
                children: [
                  AppText('${_minimumAltitude.toStringAsFixed(0)}°'),
                  Slider(
                    key: const ValueKey('discovery-altitude'),
                    min: 0,
                    max: 60,
                    divisions: 12,
                    value: _minimumAltitude,
                    onChanged: (value) =>
                        setState(() => _minimumAltitude = value),
                    onChangeEnd: (_) => unawaited(_recompute()),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('discovery-search'),
          controller: _search,
          decoration: localizeDecoration(
            context,
            const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Find targets by name or catalog identifier',
            ),
          ),
          onChanged: _scheduleSearch,
        ),
        Row(
          children: [
            Switch(
              key: const ValueKey('discovery-favorites-only'),
              value: _favoritesOnly,
              onChanged: (value) {
                setState(() => _favoritesOnly = value);
                unawaited(_recompute());
              },
            ),
            const AppText('Favorites only'),
            const Spacer(),
            IconButton(
              tooltip: appTranslate(
                context,
                'Recalculate recommendations (weather cache policy applies)',
              ),
              onPressed: _loading
                  ? null
                  : () {
                      // The existing cache policy still decides whether to fetch again.
                      unawaited(_recompute());
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppText(
          _forecastLabel(_weather, _weatherError),
          key: const ValueKey('discovery-weather-status'),
        ),
        if (_weatherError != null)
          AppText(
            'Forecast detail: $_weatherError',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 10),
        if (_loading)
          const LinearProgressIndicator(key: ValueKey('discovery-loading')),
        if (_searchError != null) ...[
          AppText('Recommendation error: $_searchError'),
          OutlinedButton(onPressed: _recompute, child: const AppText('Retry')),
        ],
        if (!_loading && _searchError == null) ...[
          AppText(
            '${_ranked.length} ranked targets · '
            '$_candidatesConsidered catalog candidates evaluated',
            key: const ValueKey('discovery-results-count'),
          ),
          if (_ranked.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppText(
                  'No matching observable windows. Try another date, '
                  'a lower altitude, a shorter session or another target.',
                ),
              ),
            ),
          for (final item in _ranked) _recommendationCard(item, site),
        ],
        const SizedBox(height: 8),
        AppText(
          'Catalog: OpenNGC · Weather: Open-Meteo where available. '
          'Scores are heuristic, not guaranteed imaging outcomes. '
          'A maximum of 24 candidates is evaluated per search.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
