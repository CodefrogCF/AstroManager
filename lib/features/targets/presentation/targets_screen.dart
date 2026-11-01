import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_message.dart';
import '../../discovery/presentation/target_discovery_panel.dart';

import '../application/celestial_catalog_controller.dart';
import '../domain/models/celestial_object.dart';
import 'target_coordinates_panel.dart';

class TargetsScreen extends ConsumerStatefulWidget {
  const TargetsScreen({super.key});

  @override
  ConsumerState<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends ConsumerState<TargetsScreen> {
  final _searchController = TextEditingController();

  bool _showDiscovery = false;
  String _query = '';
  CelestialCategory? _category;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    unawaited(
      ref
          .read(celestialCatalogProvider.notifier)
          .search(query: _query, category: _category),
    );
  }

  void _onQueryChanged(String query) {
    _query = query;
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  void _onCategoryChanged(String? value) {
    setState(() {
      _category = value == null || value == 'all'
          ? null
          : CelestialCategory.values.byName(value);
    });

    _debounce?.cancel();
    _search();
  }

  IconData _categoryIcon(CelestialCategory category) {
    return switch (category) {
      CelestialCategory.galaxy => Icons.blur_circular,
      CelestialCategory.nebula => Icons.auto_awesome,
      CelestialCategory.cluster => Icons.grain,
      CelestialCategory.star => Icons.star_outline,
      CelestialCategory.other => Icons.public,
    };
  }

  String _magnitudeText(CelestialObject object) {
    final magnitude = object.visualMagnitude;

    return magnitude == null
        ? 'V magnitude unknown'
        : 'V mag ${magnitude.toStringAsFixed(2)}';
  }

  void _showDetails(CelestialObject object) {
    final theme = Theme.of(context);

    Widget detail(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Expanded(child: SelectableText(value)),
          ],
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(object.displayTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (object.commonNames.isNotEmpty) ...[
                  Text(object.commonNames, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                ],

                detail('Object type', object.category.label),
                detail('Catalog type', object.sourceType),
                detail(
                  'Constellation',
                  object.constellation.isEmpty
                      ? 'Unknown'
                      : object.constellation,
                ),
                detail('RA (J2000)', object.rightAscensionText),
                detail('Dec (J2000)', object.declinationText),
                detail('RA degrees', object.raDegrees.toStringAsFixed(6)),
                detail('Dec degrees', object.decDegrees.toStringAsFixed(6)),
                detail('Magnitude', _magnitudeText(object)),
                detail(
                  'Major axis',
                  object.majorAxisArcmin == null
                      ? 'Unknown'
                      : '${object.majorAxisArcmin} arcmin',
                ),
                detail(
                  'Minor axis',
                  object.minorAxisArcmin == null
                      ? 'Unknown'
                      : '${object.minorAxisArcmin} arcmin',
                ),

                if (object.aliases.isNotEmpty)
                  detail('Identifiers', object.aliases),

                const Divider(),
                const SizedBox(height: 12),

                // Issue #11: Calculate the object's geometric
                // sky position for a saved location and time.
                TargetCoordinatesPanel(object: object),

                const SizedBox(height: 20),
                const Divider(),

                const Text(
                  'Catalog: OpenNGC v20260501\n'
                  'License: CC BY-SA 4.0\n'
                  'Source coordinates: J2000',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _objectCard(CelestialObject object) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('target-${object.id}'),
      child: ListTile(
        leading: Icon(
          _categoryIcon(object.category),
          color: theme.colorScheme.primary,
        ),
        title: Text(object.displayTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (object.commonNames.isNotEmpty)
              Text(
                object.commonNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              '${object.category.label} · '
              '${object.constellation.isEmpty ? "—" : object.constellation}',
            ),
            Text(
              '${object.rightAscensionText} · '
              '${object.declinationText}',
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showDetails(object),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(celestialCatalogProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Celestial Object Catalog',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                Text(
                  'Find suitable celestial targets.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Search Messier, NGC and IC objects, '
                  'common names and other identifiers.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('open-discovery'),
                      onPressed: () =>
                          setState(() => _showDiscovery = !_showDiscovery),
                      icon: Icon(
                        _showDiscovery ? Icons.list : Icons.auto_awesome,
                      ),
                      label: Text(
                        _showDiscovery
                            ? 'Browse catalog'
                            : 'Discover recommended targets',
                      ),
                    ),
                  ],
                ),
                if (_showDiscovery) ...[
                  const SizedBox(height: 20),
                  const TargetDiscoveryPanel(),
                ] else ...[
                  const SizedBox(height: 24),

                  TextField(
                    key: const ValueKey('catalog-search'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search celestial objects',
                      hintText: 'M31, NGC 224, Andromeda...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                _debounce?.cancel();
                                _search();
                              },
                            ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _onQueryChanged(value);
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'catalog-category-${_category?.name ?? "all"}',
                    ),
                    initialValue: _category?.name ?? 'all',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Object category',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All categories'),
                      ),
                      for (final category in CelestialCategory.values)
                        DropdownMenuItem(
                          value: category.name,
                          child: Text(category.label),
                        ),
                    ],
                    onChanged: _onCategoryChanged,
                  ),

                  const SizedBox(height: 24),

                  catalog.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Loading celestial catalog...'),
                          ],
                        ),
                      ),
                    ),

                    error: (error, stackTrace) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appErrorMessage(error),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.invalidate(celestialCatalogProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),

                    data: (view) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${view.totalObjects} catalog objects '
                          'available offline',
                          style: theme.textTheme.titleMedium,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          '${view.results.length} results shown '
                          '(maximum 80)',
                          style: theme.textTheme.bodySmall,
                        ),

                        const SizedBox(height: 16),

                        if (view.results.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No matching celestial objects. '
                                'Try another name or catalog number.',
                              ),
                            ),
                          ),

                        for (final object in view.results) _objectCard(object),

                        const SizedBox(height: 24),

                        Text(
                          'Source: OpenNGC · CC BY-SA 4.0\n'
                          'Equatorial coordinates: J2000\n'
                          'Magnitude: Johnson V, '
                          'where available',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
