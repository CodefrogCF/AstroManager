import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
import '../../locations/domain/models/observing_location.dart';
import '../domain/dashboard_layout.dart';
import 'widgets/dashboard_widget_state.dart';
import 'widgets/seven_night_weather_widget.dart';

/// Metadata and rendering are registered together, independent of the grid.
/// A widget's Consumer subtree is constructed only while its instance is visible.
typedef DashboardWidgetBuilder = Widget Function(
  BuildContext context,
  WidgetRef ref,
  DashboardWidgetEnvironment environment,
  DashboardWidgetInstance instance,
);

enum DashboardSettingType { toggle, choice }

final class DashboardWidgetSetting {
  const DashboardWidgetSetting({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    this.choices = const [],
  });

  final String key;
  final String label;
  final DashboardSettingType type;
  final Object defaultValue;
  final List<String> choices;

  bool isValid(Object? value) => switch (type) {
    DashboardSettingType.toggle => value is bool,
    DashboardSettingType.choice => value is String && choices.contains(value),
  };
}

final class DashboardWidgetDefinition {
  const DashboardWidgetDefinition({
    required this.typeId,
    required this.title,
    required this.description,
    required this.icon,
    required this.defaultSize,
    required this.supportedSizes,
    required this.builder,
    this.settings = const [],
    this.allowMultiple = false,
  });

  final String typeId;
  final String title;
  final String description;
  final IconData icon;
  final DashboardWidgetSize defaultSize;
  final List<DashboardWidgetSize> supportedSizes;
  final List<DashboardWidgetSetting> settings;
  final DashboardWidgetBuilder builder;
  final bool allowMultiple;

  Map<String, Object?> defaultSettings() => {
    for (final setting in settings) setting.key: setting.defaultValue,
  };

  void validateSettings(Map<String, Object?> values) {
    for (final entry in values.entries) {
      final matching = settings.where((setting) => setting.key == entry.key);
      if (matching.isEmpty || !matching.first.isValid(entry.value)) {
        throw const FormatException('Invalid dashboard widget configuration.');
      }
    }
  }
}

final class DashboardWidgetEnvironment {
  const DashboardWidgetEnvironment({required this.location});

  final ObservingLocation? location;
}

final class DashboardWidgetRegistry {
  DashboardWidgetRegistry(Iterable<DashboardWidgetDefinition> definitions)
    : entries = List.unmodifiable(definitions) {
    final ids = <String>{};
    for (final definition in entries) {
      if (!ids.add(definition.typeId) ||
          definition.supportedSizes.isEmpty ||
          !definition.supportedSizes.contains(definition.defaultSize)) {
        throw ArgumentError(
          'Invalid or duplicate dashboard widget registration.',
        );
      }
      final settingKeys = <String>{};
      for (final setting in definition.settings) {
        if (!settingKeys.add(setting.key) ||
            !setting.isValid(setting.defaultValue)) {
          throw ArgumentError('Invalid dashboard widget setting metadata.');
        }
      }
    }
  }

  final List<DashboardWidgetDefinition> entries;

  DashboardWidgetDefinition? byType(String id) {
    for (final entry in entries) {
      if (entry.typeId == id) return entry;
    }
    return null;
  }
}

final dashboardWidgetRegistryProvider = Provider<DashboardWidgetRegistry>((
  ref,
) {
  return DashboardWidgetRegistry([
    DashboardWidgetDefinition(
      typeId: 'seven-night-weather',
      title: '7-Night Forecast',
      description: 'Weather outlook for the next seven observing nights',
      icon: Icons.cloud_outlined,
      defaultSize: const DashboardWidgetSize(2, 1),
      supportedSizes: const [
        DashboardWidgetSize(1, 1),
        DashboardWidgetSize(1, 2),
        DashboardWidgetSize(2, 1),
        DashboardWidgetSize(2, 2),
        DashboardWidgetSize(3, 1),
        DashboardWidgetSize(3, 2),
        DashboardWidgetSize(4, 1),
        DashboardWidgetSize(4, 2),
      ],
      settings: const [
        DashboardWidgetSetting(
          key: 'maxCloudPercent',
          label: 'Maximum cloud cover (%)',
          type: DashboardSettingType.choice,
          defaultValue: '30',
          choices: ['10', '20', '30', '40', '50', '60', '70', '80'],
        ),
        DashboardWidgetSetting(
          key: 'minClearHours',
          label: 'Minimum clear duration (hours)',
          type: DashboardSettingType.choice,
          defaultValue: '2',
          choices: ['1', '2', '3', '4'],
        ),
      ],
      builder: (_, ref, environment, instance) => SevenNightWeatherWidget(
        location: environment.location,
        instance: instance,
      ),
    ),
    DashboardWidgetDefinition(
      typeId: 'top-targets',
      title: 'Top 3 Targets Tonight',
      description: 'Recommended objects for the current observing night',
      icon: Icons.auto_awesome_outlined,
      defaultSize: const DashboardWidgetSize(2, 1),
      supportedSizes: const [
        DashboardWidgetSize(1, 1),
        DashboardWidgetSize(1, 2),
        DashboardWidgetSize(2, 1),
        DashboardWidgetSize(2, 2),
        DashboardWidgetSize(3, 1),
        DashboardWidgetSize(3, 2),
        DashboardWidgetSize(4, 1),
        DashboardWidgetSize(4, 2),
      ],
      builder: (_, ref, environment, instance) =>
          const DashboardWidgetStateView<Object>(
            state: DashboardLoadState.unavailable(
              'Tonight’s target recommendations are not yet available.',
            ),
            dataBuilder: _unusedData,
          ),
    ),
    DashboardWidgetDefinition(
      typeId: 'tonight',
      title: 'Tonight at a Glance',
      description: 'Astronomical darkness and lunar conditions',
      icon: Icons.nightlight_outlined,
      defaultSize: const DashboardWidgetSize(1, 1),
      supportedSizes: const [
        DashboardWidgetSize(1, 1),
        DashboardWidgetSize(1, 2),
        DashboardWidgetSize(2, 1),
        DashboardWidgetSize(2, 2),
        DashboardWidgetSize(3, 1),
        DashboardWidgetSize(3, 2),
        DashboardWidgetSize(4, 1),
        DashboardWidgetSize(4, 2),
      ],
      builder: (_, ref, environment, instance) =>
          const DashboardWidgetStateView<Object>(
            state: DashboardLoadState.unavailable(
              'Astronomical night summary is not yet available.',
            ),
            dataBuilder: _unusedData,
          ),
    ),
    DashboardWidgetDefinition(
      typeId: 'quick-actions',
      title: 'Quick Actions',
      description: 'Open frequently used AstroManager screens',
      icon: Icons.bolt_outlined,
      defaultSize: const DashboardWidgetSize(1, 1),
      supportedSizes: const [
        DashboardWidgetSize(1, 1),
        DashboardWidgetSize(1, 2),
        DashboardWidgetSize(2, 1),
        DashboardWidgetSize(2, 2),
        DashboardWidgetSize(3, 1),
        DashboardWidgetSize(3, 2),
        DashboardWidgetSize(4, 1),
        DashboardWidgetSize(4, 2),
      ],
      settings: const [
        DashboardWidgetSetting(
          key: 'compact',
          label: 'Compact actions',
          type: DashboardSettingType.toggle,
          defaultValue: false,
        ),
      ],
      builder: (_, ref, environment, instance) =>
          _QuickActions(compact: instance.settings['compact'] == true),
    ),
    DashboardWidgetDefinition(
      typeId: 'observing-site',
      title: 'Observing Site',
      description: 'Current observing location and coordinates',
      icon: Icons.place_outlined,
      defaultSize: const DashboardWidgetSize(1, 1),
      supportedSizes: const [
        DashboardWidgetSize(1, 1),
        DashboardWidgetSize(1, 2),
        DashboardWidgetSize(2, 1),
        DashboardWidgetSize(2, 2),
        DashboardWidgetSize(3, 1),
        DashboardWidgetSize(3, 2),
        DashboardWidgetSize(4, 1),
        DashboardWidgetSize(4, 2),
      ],
      settings: const [
        DashboardWidgetSetting(
          key: 'showCoordinates',
          label: 'Show coordinates',
          type: DashboardSettingType.toggle,
          defaultValue: true,
        ),
      ],
      builder: (_, ref, environment, instance) => _SiteSummary(
        location: environment.location,
        showCoordinates: instance.settings['showCoordinates'] != false,
      ),
    ),
  ]);
});

Widget _unusedData(BuildContext context, Object data) =>
    const SizedBox.shrink();

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _action(
        context,
        'Night Planner',
        AppRoutes.planner,
        Icons.calendar_month_outlined,
      ),
      _action(
        context,
        'Targets',
        AppRoutes.targets,
        Icons.travel_explore_outlined,
      ),
      _action(context, 'Projects', AppRoutes.projects, Icons.folder_outlined),
      _action(
        context,
        'Equipment',
        AppRoutes.equipment,
        Icons.camera_alt_outlined,
      ),
    ],
  );

  Widget _action(
    BuildContext context,
    String title,
    String route,
    IconData icon,
  ) => compact
      ? IconButton.outlined(
          tooltip: appTranslate(context, title),
          onPressed: () => context.go(route),
          icon: Icon(icon),
        )
      : OutlinedButton.icon(
          onPressed: () => context.go(route),
          icon: Icon(icon, size: 18),
          label: AppText(title),
        );
}

class _SiteSummary extends StatelessWidget {
  const _SiteSummary({required this.location, required this.showCoordinates});

  final ObservingLocation? location;
  final bool showCoordinates;

  @override
  Widget build(BuildContext context) {
    final site = location;
    if (site == null) {
      return const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.empty('No observing location selected.'),
        dataBuilder: _unusedData,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(site.name, style: Theme.of(context).textTheme.titleMedium),
        Text(site.timeZone),
        if (showCoordinates)
          Text(
            '${site.latitude.toStringAsFixed(3)}°, '
            '${site.longitude.toStringAsFixed(3)}°',
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.locations),
          icon: const Icon(Icons.place_outlined),
          label: const AppText('Manage locations'),
        ),
      ],
    );
  }
}
