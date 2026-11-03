import 'dart:async';
import 'dart:math' as math;

import 'package:astromanager/l10n/app_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/router/app_router.dart';
import '../../../core/astronomy/solar_events.dart';
import '../../../core/astronomy/target_visibility.dart';
import '../../equipment/application/equipment_controller.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../intelligence/domain/models/suitability_score.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../projects/data/planned_projects_repository.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/models/weather_cache.dart';
import '../../weather/domain/providers/weather_provider.dart';
import '../application/celestial_catalog_controller.dart';
import '../domain/models/celestial_object.dart';
import '../domain/services/target_detail_analysis.dart';

/// The catalog record is the local source of truth. [initialObject] avoids
/// re-querying the database when opening from local search or recommendations.
class TargetDetailsScreen extends ConsumerStatefulWidget {
  const TargetDetailsScreen({
    super.key,
    required this.targetId,
    this.initialObject,
    this.initialLocalDate,
    this.testLocations,
    this.testEquipment,
    this.weatherLoader,
  });

  final String targetId;
  final CelestialObject? initialObject;
  final DateTime? initialLocalDate;
  final List<ObservingLocation>? testLocations;
  final EquipmentInventory? testEquipment;
  final Future<WeatherForecastSnapshot?> Function(WeatherForecastRequest)?
  weatherLoader;

  @override
  ConsumerState<TargetDetailsScreen> createState() =>
      _TargetDetailsScreenState();
}

class _TargetDetailsScreenState extends ConsumerState<TargetDetailsScreen> {
  CelestialObject? _object;
  List<ObservingLocation> _locations = const [];
  EquipmentInventory? _equipment;
  TargetDetailAnalysisResult? _analysis;
  WeatherForecastSnapshot? _weather;
  String? _weatherError;
  String? _error;
  bool _busy = true;
  int _generation = 0;
  String? _locationId;
  String? _profileId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _object = widget.initialObject;
    if (widget.initialLocalDate != null) _date = widget.initialLocalDate!;
    unawaited(_initialize());
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }

  ObservingLocation? get _site {
    for (final site in _locations) {
      if (site.id == _locationId) return site;
    }
    return null;
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var object = _object;
      if (object == null) {
        await ref.read(celestialCatalogProvider.future);
        object = await ref
            .read(celestialCatalogRepositoryProvider)
            .findById(widget.targetId);
      }
      if (object == null) {
        if (mounted && generation == _generation) {
          setState(() {
            _error = 'Target not found in the local catalog.';
            _busy = false;
          });
        }
        return;
      }
      final locations =
          widget.testLocations ??
          (await ref.read(observingLocationsProvider.future)) ??
          <ObservingLocation>[];
      final equipment =
          widget.testEquipment ?? await ref.read(equipmentProvider.future);
      if (!mounted || generation != _generation) return;
      final selected = locations.isEmpty
          ? null
          : locations.firstWhere(
              (site) => site.isDefault,
              orElse: () => locations.first,
            );
      setState(() {
        _object = object;
        _locations = locations;
        _equipment = equipment;
        _locationId = selected?.id;
        _profileId = equipment == null || equipment.profiles.isEmpty
            ? null
            : equipment.profiles.first.id;
        if (selected != null && widget.initialLocalDate == null) {
          final local = tz.TZDateTime.from(
            DateTime.now().toUtc(),
            SolarEvents.timeZone(selected.timeZone),
          );
          _date = DateTime(local.year, local.month, local.day);
        }
      });
      await _recalculate(generation: generation);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = 'Could not load target details: $error';
        _busy = false;
      });
    }
  }

  Future<void> _recalculate({int? generation}) async {
    final current = generation ?? ++_generation;
    final object = _object;
    final site = _site;
    setState(() {
      _busy = true;
      _error = null;
      _analysis = null;
      _weatherError = null;
    });
    if (object == null || site == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      final solar = SolarEvents.calculateForLocalDate(
        location: site,
        localDate: _date,
      );
      final request = WeatherForecastRequest(
        latitudeDegrees: site.latitude,
        longitudeDegrees: site.longitude,
        startUtc: solar.nightStartUtc,
        endUtc: solar.nightEndUtc,
      );
      WeatherForecastSnapshot? weather;
      String? weatherError;
      try {
        weather = widget.weatherLoader == null
            ? await ref.read(weatherForecastSnapshotProvider(request).future)
            : await widget.weatherLoader!(request);
      } catch (error) {
        weatherError = error.toString();
      }
      if (!mounted || current != _generation) return;
      // Yield once before the CPU-only astronomy calculations on Flutter Web.
      await Future<void>.delayed(Duration.zero);
      if (!mounted || current != _generation) return;
      final result = TargetDetailAnalysis.calculate(
        object: object,
        location: site,
        localDate: _date,
        evaluatedAtUtc: DateTime.now().toUtc(),
        weather: weather,
        inventory: _equipment,
        selectedProfileId: _profileId,
      );
      if (!mounted || current != _generation) return;
      setState(() {
        _weather = weather;
        _weatherError = weatherError;
        _analysis = result;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || current != _generation) return;
      setState(() {
        _error = 'Unable to calculate observing conditions: $error';
        _busy = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(
      () => _date = DateTime(selected.year, selected.month, selected.day),
    );
    await _recalculate();
  }

  String _local(DateTime instant) {
    final site = _site;
    if (site == null) return instant.toUtc().toIso8601String();
    return SolarEvents.formatLocal(
      tz.TZDateTime.from(instant, SolarEvents.timeZone(site.timeZone)),
      includeDate: true,
    );
  }

  Future<void> _saveProject() async {
    final object = _object;
    if (object == null) return;
    final repository = ref.read(plannedProjectsRepositoryProvider);
    try {
      final projects = await repository.load();
      if (!mounted) return;
      // Null = cancelled; empty string = new project; otherwise attach to ID.
      final selection = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                key: const ValueKey('target-new-project'),
                leading: const Icon(Icons.add),
                title: const AppText('Create a new planned project'),
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final project in projects)
                ListTile(
                  key: ValueKey('target-project-${project.id}'),
                  title: AppText(project.title),
                  subtitle: AppText(
                    project.targetIds.contains(object.id)
                        ? 'Already associated'
                        : 'Add this target to the project',
                  ),
                  onTap: () => Navigator.pop(context, project.id),
                ),
            ],
          ),
        ),
      );
      if (selection == null || !mounted) return;
      if (selection.isEmpty) {
        final best = _analysis?.bestWindow;
        await repository.save(
          newPlannedProject(
            title: object.displayTitle,
            targetId: object.id,
            localDate: _date,
            locationId: _locationId,
            profileId: _profileId,
            startUtc: best?.startUtc,
            endUtc: best?.endUtc,
          ),
        );
      } else {
        final existing = projects.firstWhere((p) => p.id == selection);
        await repository.save(existing.withTarget(object.id));
      }
      if (!mounted) return;
      ref.invalidate(plannedProjectsListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Target saved to planned projects.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('Unable to save project: $error')),
      );
    }
  }

  Widget _section(String title, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );

  Widget _catalog(CelestialObject object) => Wrap(
    spacing: 18,
    runSpacing: 8,
    children: [
      AppText('Type: ${object.category.label} (${object.sourceType})'),
      AppText(
        'Constellation: ${object.constellation.isEmpty ? 'Unknown' : object.constellation}',
      ),
      AppText('RA J2000: ${object.rightAscensionText}'),
      AppText('Dec J2000: ${object.declinationText}'),
      AppText(
        'V magnitude: ${object.visualMagnitude?.toStringAsFixed(2) ?? 'Unknown'}',
      ),
      AppText(
        'Major axis: ${object.majorAxisArcmin == null ? 'Unknown' : '${object.majorAxisArcmin}′'}',
      ),
      AppText(
        'Minor axis: ${object.minorAxisArcmin == null ? 'Unknown' : '${object.minorAxisArcmin}′'}',
      ),
      if (object.aliases.isNotEmpty) AppText('Identifiers: ${object.aliases}'),
    ],
  );

  Widget _graph(TargetDetailAnalysisResult analysis) {
    final visibility = analysis.visibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Geometric altitude over the observing night; shaded periods have astronomical darkness.',
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: const ValueKey('target-altitude-graph'),
          height: 220,
          width: double.infinity,
          child: CustomPaint(
            painter: _AltitudePainter(
              visibility,
              Theme.of(context).colorScheme,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppText(
          '${_local(visibility.periodStartUtc)} → ${_local(visibility.periodEndUtc)}',
        ),
        AppText(
          'Usable above 30°: ${visibility.totalVisibleDuration.inMinutes} minutes',
        ),
        if (visibility.bestTimeUtc != null)
          AppText(
            'Highest usable altitude: ${visibility.bestAltitudeDegrees!.toStringAsFixed(1)}° at ${_local(visibility.bestTimeUtc!)}',
          ),
      ],
    );
  }

  Widget _moonInfo(TargetDetailAnalysisResult analysis) {
    final moon = analysis.moon;
    final position = moon.moon;
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        AppText('Phase: ${position.phase.label}'),
        AppText(
          'Illuminated: ${(position.illuminationFraction * 100).toStringAsFixed(0)}%',
        ),
        AppText(
          'Altitude: ${position.horizontal.altitudeDegrees.toStringAsFixed(1)}°',
        ),
        AppText(
          'Azimuth: ${position.horizontal.azimuthDegrees?.toStringAsFixed(1) ?? 'Undefined'}°',
        ),
        AppText(
          'Moon–target separation: ${moon.targetSeparationDegrees.toStringAsFixed(1)}°',
        ),
        AppText('Evaluated at ${_local(position.utc)}'),
      ],
    );
  }

  Widget _weatherInfo(TargetDetailAnalysisResult analysis) {
    final snapshot = _weather;
    if (snapshot == null) {
      return AppText(
        _weatherError == null
            ? 'No weather forecast available. Any suitability score is provisional.'
            : 'Weather unavailable / offline: $_weatherError. Scores are provisional.',
      );
    }
    final stale =
        snapshot.isStale ||
        snapshot.isStaleAt(
          DateTime.now().toUtc(),
          ref.read(weatherCachePolicyProvider),
        );
    final center =
        analysis.bestWindow?.startUtc ?? analysis.solar.nightStartUtc;
    final hour = TargetDetailAnalysis.nearestWeatherHour(snapshot, center);
    final cloud = hour?.totalCloudCoverPercent.value;
    final precipitation = hour?.precipitationMillimeters.value;
    final wind = hour?.windSpeedMetersPerSecond.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '${snapshot.forecast.provider.name} · ${stale ? 'STALE, not current' : snapshot.origin.name}',
        ),
        AppText(
          'Retrieved: ${_local(snapshot.forecast.fetchedAtUtc)} · '
          'Issue time: ${_local(snapshot.forecast.issuedAtUtc)}'
          '${snapshot.forecast.issuedAtIsEstimated ? ' (estimated)' : ''}',
        ),
        if (hour == null)
          const AppText(
            'No forecast hour covers the selected observing period.',
          ),
        if (hour != null) ...[
          AppText('Forecast hour: ${_local(hour.timeUtc)}'),
          AppText(
            'Cloud: ${cloud == null ? 'Unknown' : '${cloud.toStringAsFixed(0)}%'} · '
            'Precipitation: ${precipitation == null ? 'Unknown' : '${precipitation.toStringAsFixed(1)} mm/h'} · '
            'Wind: ${wind == null ? 'Unknown' : '${wind.toStringAsFixed(1)} m/s'}',
          ),
        ],
        if (snapshot.refreshError != null)
          AppText('Last refresh failed: ${snapshot.refreshError}'),
        if (stale)
          const AppText(
            'Outdated forecasts are not treated as favorable conditions.',
          ),
      ],
    );
  }

  Widget _scoreInfo(TargetDetailAnalysisResult analysis) {
    final windows = analysis.recommendations.rankedWindows;
    if (windows.isEmpty) {
      return AppText(
        analysis.recommendations.excludedTargets[_object!.id] ??
            'No qualifying dark visibility window for this location and date.',
      );
    }
    final best = windows.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '${best.score.score.toStringAsFixed(0)}/100'
          '${best.isProvisional ? ' · Provisional (incomplete inputs)' : ''}',
          key: const ValueKey('target-suitability-score'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        AppText(
          'Recommended: ${_local(best.startUtc)} – ${_local(best.endUtc)} '
          '(${best.duration.inMinutes} min)',
        ),
        AppText(
          'Weather coverage: ${best.weatherStatus.name} · '
          '${(best.weatherTimeCoverage * 100).toStringAsFixed(0)}% time',
        ),
        for (final factor in SuitabilityFactor.values)
          if (best.score.factors.containsKey(factor))
            ListTile(
              dense: true,
              title: AppText(
                '${factor.label}: '
                '${best.score.factors[factor]!.rawScore?.toStringAsFixed(0) ?? 'Unknown'}/100',
              ),
              subtitle: AppText(best.score.factors[factor]!.explanation),
              trailing: AppText(
                '+${best.score.factors[factor]!.contribution.toStringAsFixed(1)}',
              ),
            ),
        for (final constraint in best.score.constraints) AppText(constraint),
        AppText(best.explanation),
      ],
    );
  }

  Widget _equipmentInfo(TargetDetailAnalysisResult analysis) {
    if (analysis.equipment.isEmpty) {
      return const AppText(
        'No valid camera + optic profiles. Add an imaging setup in Equipment.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final suggestion in analysis.equipment.take(8))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: AppText(suggestion.profile.name),
            subtitle: AppText(
              '${suggestion.metrics.horizontalFovDegrees.toStringAsFixed(2)}° × '
              '${suggestion.metrics.verticalFovDegrees.toStringAsFixed(2)}° · '
              '${suggestion.description}',
            ),
            trailing: suggestion.profile.id == _profileId
                ? const Icon(Icons.check_circle_outline)
                : null,
            onTap: () {
              setState(() => _profileId = suggestion.profile.id);
              unawaited(_recalculate());
            },
          ),
        const AppText(
          'FoV fit is a conservative 0° orientation estimate; check rotation in Sky Atlas.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final object = _object;
    final analysis = _analysis;
    return Scaffold(
      appBar: AppBar(title: AppText(object?.displayTitle ?? 'Target details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (object != null) ...[
            AppText(
              object.displayTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (object.commonNames.isNotEmpty) AppText(object.commonNames),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('details-open-atlas'),
                  icon: const Icon(Icons.public),
                  label: const AppText('View in sky atlas'),
                  onPressed: () => context.push(AppRoutes.atlas, extra: object),
                ),
                FilledButton.icon(
                  key: const ValueKey('details-save-project'),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const AppText('Save as project'),
                  onPressed: _saveProject,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section('Catalog data', _catalog(object)),
            _section(
              'Observation setup',
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('details-location'),
                      isExpanded: true,
                      initialValue: _locationId,
                      decoration: localizeDecoration(
                        context,
                        const InputDecoration(labelText: 'Observing location'),
                      ),
                      items: [
                        for (final location in _locations)
                          DropdownMenuItem(
                            value: location.id,
                            child: AppText(
                              location.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        setState(() => _locationId = id);
                        unawaited(_recalculate());
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('details-date'),
                    icon: const Icon(Icons.calendar_month),
                    label: AppText(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
                      '${_date.day.toString().padLeft(2, '0')}',
                    ),
                    onPressed: _pickDate,
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('details-optics'),
                      isExpanded: true,
                      initialValue: _profileId ?? 'none',
                      decoration: localizeDecoration(
                        context,
                        const InputDecoration(labelText: 'Imaging setup'),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'none',
                          child: AppText('No setup selected'),
                        ),
                        for (final profile
                            in _equipment?.profiles ?? <OpticalProfile>[])
                          DropdownMenuItem(
                            value: profile.id,
                            child: AppText(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        setState(() => _profileId = id == 'none' ? null : id);
                        unawaited(_recalculate());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            AppText(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            OutlinedButton(
              onPressed: _initialize,
              child: const AppText('Retry'),
            ),
          ],
          if (object != null && _locations.isEmpty && !_busy)
            const AppText(
              'Add an observing location in Settings to calculate visibility and weather.',
            ),
          if (analysis != null && !_busy) ...[
            _section('Target altitude and visibility', _graph(analysis)),
            _section(
              'Astronomical darkness and Moon',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    '${analysis.solar.astronomicalDarkness.length} astronomical darkness interval(s)',
                  ),
                  for (final interval in analysis.solar.astronomicalDarkness)
                    AppText(
                      '${_local(interval.startUtc)} – ${_local(interval.endUtc)}',
                    ),
                  const SizedBox(height: 10),
                  _moonInfo(analysis),
                ],
              ),
            ),
            _section('Weather forecast', _weatherInfo(analysis)),
            _section(
              'Suitability score and recommended window',
              _scoreInfo(analysis),
            ),
            _section('Recommended imaging setups', _equipmentInfo(analysis)),
          ],
          if (object != null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: AppText(
                'Source: OpenNGC (CC BY-SA 4.0). Positions are geometric planning estimates;'
                ' local terrain and atmospheric refraction are not modeled.',
              ),
            ),
        ],
      ),
    );
  }
}

/// Fixed-angle chart. The horizontal axis uses elapsed UTC time, avoiding
/// distortions when an observing night crosses daylight-saving transitions.
final class _AltitudePainter extends CustomPainter {
  const _AltitudePainter(this.visibility, this.scheme);
  final TargetVisibilityResult visibility;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(
      36,
      12,
      math.max(1, size.width - 48),
      math.max(1, size.height - 32),
    );
    final duration = visibility.periodEndUtc
        .difference(visibility.periodStartUtc)
        .inMicroseconds;
    if (duration <= 0) return;
    double x(DateTime instant) =>
        area.left +
        (instant.difference(visibility.periodStartUtc).inMicroseconds /
                    duration)
                .clamp(0.0, 1.0)
                .toDouble() *
            area.width;
    double y(double altitude) =>
        area.bottom -
        ((altitude + 30) / 120).clamp(0.0, 1.0).toDouble() * area.height;
    final shading = Paint()..color = scheme.primary.withValues(alpha: 0.11);
    for (final interval in visibility.allowedIntervals) {
      canvas.drawRect(
        Rect.fromLTRB(
          x(interval.startUtc),
          area.top,
          x(interval.endUtc),
          area.bottom,
        ),
        shading,
      );
    }
    final grid = Paint()
      ..color = scheme.outline.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (final altitude in [-30.0, 0.0, 30.0, 60.0, 90.0]) {
      canvas.drawLine(
        Offset(area.left, y(altitude)),
        Offset(area.right, y(altitude)),
        grid,
      );
    }
    final samples = visibility.samples;
    if (samples.isEmpty) return;
    final path = Path()
      ..moveTo(
        x(samples.first.utc),
        y(samples.first.horizontal.altitudeDegrees),
      );
    for (final sample in samples.skip(1)) {
      path.lineTo(x(sample.utc), y(sample.horizontal.altitudeDegrees));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = scheme.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    final target = visibility.bestVisiblePosition;
    if (target != null) {
      canvas.drawCircle(
        Offset(x(target.utc), y(target.horizontal.altitudeDegrees)),
        4,
        Paint()..color = scheme.tertiary,
      );
    }
    for (final altitude in [0.0, 30.0, 60.0, 90.0]) {
      final painter = TextPainter(
        text: TextSpan(
          text: '$altitude°',
          style: TextStyle(color: scheme.onSurface, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(0, y(altitude) - 7));
    }
  }

  @override
  bool shouldRepaint(covariant _AltitudePainter oldDelegate) =>
      !identical(visibility, oldDelegate.visibility) ||
      scheme != oldDelegate.scheme;
}
