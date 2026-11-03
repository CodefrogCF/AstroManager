import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_text.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../locations/domain/models/observing_location.dart';
import '../../onboarding/presentation/onboarding_dialog.dart';
import '../../settings/application/app_preferences_controller.dart';
import '../application/dashboard_layout_controller.dart';
import '../domain/dashboard_layout.dart';
import 'dashboard_widget_registry.dart';
import 'widgets/dashboard_widget_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final layout = ref.watch(dashboardLayoutProvider);
    final locations = ref.watch(observingLocationsProvider);
    final registry = ref.watch(dashboardWidgetRegistryProvider);
    final needsSetup = prefs.value != null && !prefs.value!.onboardingCompleted;

    return ListView(
      key: const ValueKey('dashboard-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        if (needsSetup) ...[
          const _OnboardingPrompt(),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            AppText(
              'Observing dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            OutlinedButton.icon(
              key: const ValueKey('dashboard-manage'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => const _ManageWidgetsDialog(),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const AppText('Manage widgets'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LocationSelector(layout: layout.value, locations: locations),
        const SizedBox(height: 16),
        layout.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => _DashboardError(
            onRecover: () => _perform(
              context,
              () =>
                  ref.read(dashboardLayoutProvider.notifier).recoverDefaults(),
            ),
          ),
          data: (current) {
            final availableLocations = locations.value ?? <ObservingLocation>[];
            ObservingLocation? chosen;
            for (final location in availableLocations) {
              if (location.id == current.selectedLocationId) chosen = location;
            }
            if (chosen == null && availableLocations.isNotEmpty) {
              for (final location in availableLocations) {
                if (location.isDefault) chosen = location;
              }
              chosen ??= availableLocations.first;
            }
            final visible = current.widgets
                .where((widget) => widget.visible)
                .toList();
            if (visible.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: AppText(
                    'No dashboard widgets. Use Manage widgets to add one.',
                  ),
                ),
              );
            }
            return _DashboardGrid(
              widgets: visible,
              registry: registry,
              environment: DashboardWidgetEnvironment(location: chosen),
            );
          },
        ),
      ],
    );
  }
}

Future<bool> _perform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: AppText('Could not save dashboard changes: $error')),
      );
    }
    return false;
  }
}

class _OnboardingPrompt extends ConsumerWidget {
  const _OnboardingPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppText('No account required'),
          const SizedBox(height: 6),
          const AppText(
            'Your data stays on this device. No account or registration is required.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('start-onboarding'),
                onPressed: () => showAstroOnboarding(context),
                child: const AppText('Get started'),
              ),
              TextButton(
                key: const ValueKey('skip-onboarding'),
                onPressed: () => _perform(
                  context,
                  () => ref
                      .read(appPreferencesProvider.notifier)
                      .completeOnboarding(),
                ),
                child: const AppText('Set up later'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LocationSelector extends ConsumerWidget {
  const _LocationSelector({required this.layout, required this.locations});
  final DashboardLayout? layout;
  final AsyncValue<List<ObservingLocation>> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locations.isLoading && locations.value == null) {
      return const AppText('Loading observing locations…');
    }
    if (locations.hasError) {
      return const AppText('Observing locations unavailable.');
    }
    final sites = locations.value ?? <ObservingLocation>[];
    if (sites.isEmpty) {
      return const AppText(
        'Add an observing location in Settings to personalize the dashboard.',
      );
    }
    final selectedId = layout?.selectedLocationId;
    final selected = sites.any((site) => site.id == selectedId)
        ? selectedId
        : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: appTranslate(context, 'Dashboard observing location'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: const ValueKey('dashboard-location'),
            isDense: true,
            isExpanded: true,
            value: selected ?? '__default__',
            items: [
              DropdownMenuItem<String>(
                value: '__default__',
                child: AppText(
                  'Default observing location',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final site in sites)
                DropdownMenuItem<String>(
                  value: site.id,
                  child: Text(site.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: layout == null
                ? null
                : (value) => _perform(
                    context,
                    () => ref
                        .read(dashboardLayoutProvider.notifier)
                        .selectLocation(value == '__default__' ? null : value),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.widgets,
    required this.registry,
    required this.environment,
  });

  final List<DashboardWidgetInstance> widgets;
  final DashboardWidgetRegistry registry;
  final DashboardWidgetEnvironment environment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 1120
          ? 4
          : width >= 680
          ? 2
          : 1;
      const gap = 12.0;
      final cellWidth = (width - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final instance in widgets)
            SizedBox(
              key: ValueKey('dashboard-widget-${instance.id}'),
              width:
                  cellWidth * instance.size.columns.clamp(1, columns) +
                  (instance.size.columns.clamp(1, columns) - 1) * gap,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: instance.size.rows * 142.0,
                ),
                child: _DashboardWidgetCard(
                  instance: instance,
                  definition: registry.byType(instance.typeId),
                  environment: environment,
                ),
              ),
            ),
        ],
      );
    },
  );
}

enum _CardAction { configure, moveUp, moveDown, hide, remove }

class _DashboardWidgetCard extends ConsumerWidget {
  const _DashboardWidgetCard({
    required this.instance,
    required this.definition,
    required this.environment,
  });

  final DashboardWidgetInstance instance;
  final DashboardWidgetDefinition? definition;
  final DashboardWidgetEnvironment environment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = definition?.title ?? 'Unknown widget';
    final icon = definition?.icon ?? Icons.widgets_outlined;
    Widget body;
    final widgetDefinition = definition;
    if (widgetDefinition == null) {
      body = const DashboardWidgetStateView<Object>(
        state: DashboardLoadState.unavailable('This widget is not installed.'),
        dataBuilder: _unusedWidgetData,
      );
    } else {
      try {
        widgetDefinition.validateSettings(instance.settings);
        body = Builder(
          builder: (context) => Consumer(
            builder: (context, widgetRef, _) => widgetDefinition.builder(
              context,
              widgetRef,
              environment,
              instance,
            ),
          ),
        );
      } on FormatException {
        body = const DashboardWidgetStateView<Object>(
          state: DashboardLoadState.error('Invalid widget settings.'),
          dataBuilder: _unusedWidgetData,
        );
      }
    }
    return Semantics(
      container: true,
      label:
          '${appTranslate(context, 'Dashboard widget')}: ${appTranslate(context, title)}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: AppText(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<_CardAction>(
                    key: ValueKey('dashboard-actions-${instance.id}'),
                    tooltip: appTranslate(context, 'Widget options'),
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      final controller = ref.read(
                        dashboardLayoutProvider.notifier,
                      );
                      switch (action) {
                        case _CardAction.configure:
                          if (widgetDefinition != null) {
                            showDialog<void>(
                              context: context,
                              builder: (_) => _ConfigureWidgetDialog(
                                instance: instance,
                                definition: widgetDefinition,
                              ),
                            );
                          }
                          return;
                        case _CardAction.moveUp:
                          _perform(
                            context,
                            () => controller.moveWidget(instance.id, -1),
                          );
                          return;
                        case _CardAction.moveDown:
                          _perform(
                            context,
                            () => controller.moveWidget(instance.id, 1),
                          );
                          return;
                        case _CardAction.hide:
                          _perform(
                            context,
                            () => controller.setVisible(instance.id, false),
                          );
                          return;
                        case _CardAction.remove:
                          _perform(
                            context,
                            () => controller.removeWidget(instance.id),
                          );
                          return;
                      }
                    },
                    itemBuilder: (context) => [
                      if (widgetDefinition != null)
                        const PopupMenuItem(
                          value: _CardAction.configure,
                          child: AppText('Configure'),
                        ),
                      const PopupMenuItem(
                        value: _CardAction.moveUp,
                        child: AppText('Move earlier'),
                      ),
                      const PopupMenuItem(
                        value: _CardAction.moveDown,
                        child: AppText('Move later'),
                      ),
                      const PopupMenuItem(
                        value: _CardAction.hide,
                        child: AppText('Hide widget'),
                      ),
                      const PopupMenuItem(
                        value: _CardAction.remove,
                        child: AppText('Remove widget'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _unusedWidgetData(BuildContext context, Object value) =>
    const SizedBox.shrink();

class _ManageWidgetsDialog extends ConsumerWidget {
  const _ManageWidgetsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashboardLayoutProvider).value;
    final registry = ref.watch(dashboardWidgetRegistryProvider);
    return AlertDialog(
      title: const AppText('Manage widgets'),
      content: SizedBox(
        width: 460,
        height: 400,
        child: layout == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  for (final instance in layout.widgets)
                    SwitchListTile(
                      key: ValueKey('dashboard-toggle-${instance.id}'),
                      title: AppText(
                        registry.byType(instance.typeId)?.title ??
                            'Unknown widget',
                      ),
                      subtitle: AppText(
                        instance.visible ? 'Visible' : 'Hidden',
                      ),
                      value: instance.visible,
                      onChanged: (enabled) => _perform(
                        context,
                        () => ref
                            .read(dashboardLayoutProvider.notifier)
                            .setVisible(instance.id, enabled),
                      ),
                      secondary: Icon(
                        registry.byType(instance.typeId)?.icon ??
                            Icons.widgets_outlined,
                      ),
                    ),
                  const Divider(),
                  for (final definition in registry.entries)
                    if (definition.allowMultiple ||
                        !layout.widgets.any(
                          (widget) => widget.typeId == definition.typeId,
                        ))
                      ListTile(
                        key: ValueKey('dashboard-add-${definition.typeId}'),
                        leading: Icon(definition.icon),
                        title: AppText(definition.title),
                        subtitle: AppText(definition.description),
                        trailing: const Icon(Icons.add),
                        onTap: () => _perform(
                          context,
                          () => ref
                              .read(dashboardLayoutProvider.notifier)
                              .addWidget(
                                definition.typeId,
                                definition.defaultSize,
                                settings: definition.defaultSettings(),
                              ),
                        ),
                      ),
                ],
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('dashboard-reset'),
          onPressed: () => _perform(
            context,
            () => ref.read(dashboardLayoutProvider.notifier).reset(),
          ),
          child: const AppText('Restore default widgets'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('Close'),
        ),
      ],
    );
  }
}

class _ConfigureWidgetDialog extends ConsumerStatefulWidget {
  const _ConfigureWidgetDialog({
    required this.instance,
    required this.definition,
  });
  final DashboardWidgetInstance instance;
  final DashboardWidgetDefinition definition;

  @override
  ConsumerState<_ConfigureWidgetDialog> createState() =>
      _ConfigureWidgetDialogState();
}

class _ConfigureWidgetDialogState
    extends ConsumerState<_ConfigureWidgetDialog> {
  late DashboardWidgetSize _size;
  late Map<String, Object?> _settings;

  @override
  void initState() {
    super.initState();
    _size = widget.definition.supportedSizes.contains(widget.instance.size)
        ? widget.instance.size
        : widget.definition.defaultSize;
    _settings = {
      for (final setting in widget.definition.settings)
        setting.key: setting.isValid(widget.instance.settings[setting.key])
            ? widget.instance.settings[setting.key]
            : setting.defaultValue,
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText(widget.definition.title),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DashboardWidgetSize>(
              key: const ValueKey('dashboard-widget-size'),
              initialValue: _size,
              decoration: InputDecoration(
                labelText: appTranslate(context, 'Widget size'),
              ),
              items: [
                for (final size in widget.definition.supportedSizes)
                  DropdownMenuItem(
                    value: size,
                    child: Text('${size.columns} × ${size.rows}'),
                  ),
              ],
              onChanged: (size) {
                if (size != null) setState(() => _size = size);
              },
            ),
            for (final setting in widget.definition.settings)
              if (setting.type == DashboardSettingType.toggle)
                SwitchListTile(
                  title: AppText(setting.label),
                  value:
                      _settings[setting.key] as bool? ??
                      setting.defaultValue as bool,
                  onChanged: (checked) =>
                      setState(() => _settings[setting.key] = checked),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue:
                      _settings[setting.key] as String? ??
                      setting.defaultValue as String,
                  decoration: InputDecoration(
                    labelText: appTranslate(context, setting.label),
                  ),
                  items: [
                    for (final choice in setting.choices)
                      DropdownMenuItem(value: choice, child: Text(choice)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _settings[setting.key] = value);
                    }
                  },
                ),
            if (widget.definition.settings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: AppText('No additional settings.'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('dashboard-configure-save'),
        onPressed: () async {
          final saved = await _perform(
            context,
            () => ref
                .read(dashboardLayoutProvider.notifier)
                .configureWidget(
                  widget.instance.id,
                  size: _size,
                  settings: _settings,
                ),
          );
          if (saved && context.mounted) Navigator.pop(context);
        },
        child: const AppText('Save'),
      ),
    ],
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRecover});
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppText('Dashboard configuration could not be loaded.'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onRecover,
        icon: const Icon(Icons.restore),
        label: const AppText('Restore default widgets'),
      ),
    ],
  );
}
