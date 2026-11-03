import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/app_text.dart';
import '../../locations/domain/models/observing_location.dart';
import '../domain/dashboard_layout.dart';
import 'widgets/dashboard_widget_state.dart';
import 'widgets/seven_night_weather_widget.dart';
import 'widgets/top_targets_widget.dart';
import 'widgets/dashboard_project_widgets.dart';
import 'widgets/dashboard_quick_actions_widget.dart';
import 'widgets/tonight_conditions_widget.dart';

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
      settings: const [
        DashboardWidgetSetting(
          key: 'candidateSource',
          label: 'Candidate targets',
          type: DashboardSettingType.choice,
          defaultValue: 'combined',
          choices: ['combined', 'catalog', 'projects', 'favorites'],
        ),
        DashboardWidgetSetting(
          key: 'minimumDurationMinutes',
          label: 'Minimum session duration (minutes)',
          type: DashboardSettingType.choice,
          defaultValue: '60',
          choices: ['30', '60', '90', '120', '180'],
        ),
      ],
      builder: (_, ref, environment, instance) =>
          TopTargetsWidget(location: environment.location, instance: instance),
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
          TonightConditionsWidget(location: environment.location),
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
        DashboardWidgetSetting(
          key: 'showAtlas',
          label: 'Show Sky Atlas',
          type: DashboardSettingType.toggle,
          defaultValue: true,
        ),
        DashboardWidgetSetting(
          key: 'showPlanner',
          label: 'Show Night Planner',
          type: DashboardSettingType.toggle,
          defaultValue: true,
        ),
        DashboardWidgetSetting(
          key: 'showProjects',
          label: 'Show Projects',
          type: DashboardSettingType.toggle,
          defaultValue: true,
        ),
        DashboardWidgetSetting(
          key: 'showSessions',
          label: 'Show Session Logging',
          type: DashboardSettingType.toggle,
          defaultValue: true,
        ),
        DashboardWidgetSetting(
          key: 'showTargets',
          label: 'Show Targets',
          type: DashboardSettingType.toggle,
          defaultValue: false,
        ),
        DashboardWidgetSetting(
          key: 'showEquipment',
          label: 'Show Equipment',
          type: DashboardSettingType.toggle,
          defaultValue: false,
        ),
      ],
      builder: (_, ref, environment, instance) =>
          DashboardQuickActionsWidget(instance: instance),
    ),
    DashboardWidgetDefinition(
      typeId: 'active-projects',
      title: 'Active Imaging Projects',
      description: 'Accepted integration time and imaging goal progress',
      icon: Icons.insights_outlined,
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
          key: 'limit',
          label: 'Number of projects',
          type: DashboardSettingType.choice,
          defaultValue: '3',
          choices: ['1', '2', '3', '4', '5'],
        ),
      ],
      builder: (_, ref, environment, instance) => DashboardActiveProjectsWidget(
        limit: int.tryParse(instance.settings['limit'] as String? ?? '3') ?? 3,
      ),
    ),
    DashboardWidgetDefinition(
      typeId: 'recent-sessions',
      title: 'Recent Observation Sessions',
      description: 'Recent imaging activity and accepted exposure time',
      icon: Icons.history_outlined,
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
          key: 'limit',
          label: 'Number of sessions',
          type: DashboardSettingType.choice,
          defaultValue: '4',
          choices: ['1', '2', '3', '4', '5'],
        ),
      ],
      builder: (_, ref, environment, instance) => DashboardRecentSessionsWidget(
        limit: int.tryParse(instance.settings['limit'] as String? ?? '4') ?? 4,
      ),
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
