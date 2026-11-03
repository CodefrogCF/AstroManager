import 'dart:async';

import 'package:astromanager/l10n/app_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../application/observation_alert_monitor.dart';
import '../data/observation_alert_store.dart';
import '../data/observation_notification_gateway.dart';
import '../domain/observation_alert.dart';

class ObservationAlertsSection extends ConsumerStatefulWidget {
  const ObservationAlertsSection({super.key});

  @override
  ConsumerState<ObservationAlertsSection> createState() =>
      _ObservationAlertsSectionState();
}

class _ObservationAlertsSectionState
    extends ConsumerState<ObservationAlertsSection> {
  final _search = TextEditingController();
  ObservationAlertState? _state;
  List<ObservingLocation> _sites = const [];
  List<CelestialObject> _targets = const [];
  String? _targetId;
  String? _locationId;
  double _minimumScore = 70;
  int _duration = 60;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = await ref.read(observationAlertStoreProvider).load();
      final sites = await ref.read(observingLocationsProvider.future);
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _sites = sites;
        _locationId = sites.isEmpty
            ? null
            : sites
                  .firstWhere(
                    (site) => site.isDefault,
                    orElse: () => sites.first,
                  )
                  .id;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Unable to load alerts: $error');
      }
    }
  }

  Future<void> _searchTargets() async {
    try {
      await ref.read(celestialCatalogProvider.future);
      final results = await ref
          .read(celestialCatalogRepositoryProvider)
          .search(query: _search.text.trim(), limit: 60);
      if (mounted) {
        setState(() {
          _targets = results;
          _targetId = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Search failed: $error');
      }
    }
  }

  Future<void> _update(
    ObservationAlertState Function(ObservationAlertState) change,
  ) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final store = ref.read(observationAlertStoreProvider);
      final latest = await store.load();
      final next = change(latest);
      await store.save(next);
      if (mounted) {
        ref.invalidate(observationAlertStateProvider);
      }
      if (mounted) {
        setState(() {
          _state = next;
          _status = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Unable to save alerts: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled) {
      if (!ref.read(observationNotificationGatewayProvider).isSupported) {
        setState(
          () => _status =
              'System notifications are only available on Android and iOS.',
        );
        return;
      }
      setState(() => _busy = true);
      bool granted = false;
      try {
        granted = await ref
            .read(observationNotificationGatewayProvider)
            .requestPermission();
      } catch (error) {
        if (mounted) {
          setState(() => _status = 'Permission request failed: $error');
        }
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
      if (!mounted) {
        return;
      }
      if (!granted) {
        setState(() => _status = 'Notification permission was not granted.');
        return;
      }
    }
    await _update((state) => state.copyWith(enabled: enabled));
  }

  Future<void> _add() async {
    final selectedId = _targetId;
    final locationId = _locationId;
    if (selectedId == null || locationId == null) {
      setState(
        () => _status = 'Select a catalog target and observing location.',
      );
      return;
    }
    final object = _targets.firstWhere((target) => target.id == selectedId);
    await _update((state) {
      if (state.rules.any(
        (rule) => rule.targetId == selectedId && rule.locationId == locationId,
      )) {
        throw const FormatException(
          'An alert already monitors this target at this location.',
        );
      }
      return state.copyWith(
        rules: [
          ...state.rules,
          ObservationAlertRule(
            id: const Uuid().v4(),
            targetId: selectedId,
            targetName: object.displayTitle,
            locationId: locationId,
            minimumScore: _minimumScore,
            minimumDurationMinutes: _duration,
          ),
        ],
      );
    });
  }

  Future<void> _editRule(ObservationAlertRule rule) async {
    var score = rule.minimumScore;
    var duration = rule.minimumDurationMinutes;
    final edited = await showDialog<ObservationAlertRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText('Edit alert: ${rule.targetName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText('Minimum suitability: ${score.toStringAsFixed(0)}/100'),
              Slider(
                key: const ValueKey('alert-edit-score'),
                min: 0,
                max: 100,
                divisions: 20,
                value: score,
                onChanged: (value) => setDialogState(() => score = value),
              ),
              DropdownButtonFormField<int>(
                key: const ValueKey('alert-edit-duration'),
                initialValue: duration,
                decoration: localizeDecoration(
                  context,
                  const InputDecoration(labelText: 'Minimum duration'),
                ),
                items: [
                  for (final minutes in [15, 30, 60, 90, 120, 180, 240])
                    DropdownMenuItem(
                      value: minutes,
                      child: AppText('$minutes minutes'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => duration = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                ObservationAlertRule(
                  id: rule.id,
                  targetId: rule.targetId,
                  targetName: rule.targetName,
                  locationId: rule.locationId,
                  minimumScore: score,
                  minimumDurationMinutes: duration,
                  enabled: rule.enabled,
                ),
              ),
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    await _update(
      (current) => current.copyWith(
        rules: [
          for (final entry in current.rules)
            entry.id == rule.id ? edited : entry,
        ],
      ),
    );
  }

  Future<void> _check() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final outcome = await ref
          .read(observationAlertMonitorProvider)
          .checkNow();
      if (mounted) {
        ref.invalidate(observationAlertStateProvider);
      }
      if (mounted) {
        setState(() {
          _status =
              'Check complete: ${outcome.sent} notifications, '
              '${outcome.alreadyDelivered} previously notified nights, '
              '${outcome.unavailable} unavailable forecast/targets.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Check failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final theme = Theme.of(context);
    final supported = ref
        .watch(observationNotificationGatewayProvider)
        .isSupported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Observation opportunity alerts',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const AppText(
          'Optional forecast-based alerts. Checks run when the app starts, '
          'returns to the foreground or when you tap Check now. '
          'No continuous background monitoring is provided.',
        ),
        if (!supported)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: AppText(
              'System notifications are unavailable on this platform. '
              'Alert rules remain editable for Android/iOS.',
            ),
          ),
        const SizedBox(height: 8),
        if (state == null)
          const LinearProgressIndicator()
        else ...[
          SwitchListTile(
            key: const ValueKey('alerts-master-enabled'),
            title: const AppText('Enable opportunity notifications'),
            subtitle: const AppText(
              'Permission is requested only when enabling.',
            ),
            value: state.enabled,
            onChanged: _busy ? null : _setEnabled,
          ),
          for (final rule in state.rules)
            Card(
              child: ListTile(
                key: ValueKey('alert-rule-${rule.id}'),
                title: AppText(rule.targetName),
                subtitle: AppText(
                  '${_sites.where((site) => site.id == rule.locationId).map((site) => site.name).firstOrNull ?? '(missing location)'} · '
                  'score ≥ ${rule.minimumScore.toStringAsFixed(0)} · '
                  '${rule.minimumDurationMinutes} min',
                ),
                onTap: _busy ? null : () => _editRule(rule),
                leading: Switch(
                  value: rule.enabled,
                  onChanged: _busy
                      ? null
                      : (value) => _update(
                          (current) => current.copyWith(
                            rules: [
                              for (final entry in current.rules)
                                entry.id == rule.id
                                    ? entry.copyWith(enabled: value)
                                    : entry,
                            ],
                          ),
                        ),
                ),
                trailing: IconButton(
                  tooltip: appTranslate(context, 'Delete alert'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy
                      ? null
                      : () => _update(
                          (current) => current.copyWith(
                            rules: current.rules
                                .where((entry) => entry.id != rule.id)
                                .toList(),
                          ),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          AppText('New target alert', style: theme.textTheme.titleMedium),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('alert-target-search'),
                  controller: _search,
                  decoration: localizeDecoration(
                    context,
                    const InputDecoration(
                      labelText: 'Find target (e.g. M31 or NGC 224)',
                    ),
                  ),
                  onSubmitted: (_) => _searchTargets(),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _searchTargets,
                tooltip: appTranslate(context, 'Search catalog'),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('alert-target-$_targetId'),
            initialValue: _targetId,
            isExpanded: true,
            decoration: localizeDecoration(
              context,
              const InputDecoration(labelText: 'Celestial target'),
            ),
            items: [
              for (final target in _targets)
                DropdownMenuItem(
                  value: target.id,
                  child: AppText(
                    target.displayTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _targetId = value),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('alert-location-$_locationId'),
            initialValue: _locationId,
            isExpanded: true,
            decoration: localizeDecoration(
              context,
              const InputDecoration(labelText: 'Observing location'),
            ),
            items: [
              for (final site in _sites)
                DropdownMenuItem(value: site.id, child: AppText(site.name)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _locationId = value),
          ),
          const SizedBox(height: 8),
          AppText(
            'Minimum suitability: ${_minimumScore.toStringAsFixed(0)}/100',
          ),
          Slider(
            key: const ValueKey('alert-min-score'),
            min: 0,
            max: 100,
            divisions: 20,
            value: _minimumScore,
            onChanged: _busy
                ? null
                : (value) => setState(() => _minimumScore = value),
          ),
          DropdownButtonFormField<int>(
            key: const ValueKey('alert-min-duration'),
            initialValue: _duration,
            decoration: localizeDecoration(
              context,
              const InputDecoration(labelText: 'Minimum observation duration'),
            ),
            items: [
              for (final minutes in [15, 30, 60, 90, 120, 180, 240])
                DropdownMenuItem(
                  value: minutes,
                  child: AppText('$minutes minutes'),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _duration = value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('alert-add'),
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_alert_outlined),
                label: const AppText('Add alert'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('alert-check-now'),
                onPressed: _busy || !supported || !state.enabled
                    ? null
                    : _check,
                icon: const Icon(Icons.refresh),
                label: const AppText('Check now'),
              ),
            ],
          ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppText(_status!),
          ),
      ],
    );
  }
}
