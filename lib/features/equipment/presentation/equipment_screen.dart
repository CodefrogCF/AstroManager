import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_message.dart';

import '../application/equipment_controller.dart';
import '../domain/models/equipment_models.dart';
import 'equipment_dialogs.dart';

class EquipmentScreen extends ConsumerWidget {
  const EquipmentScreen({super.key});

  IconData _icon(EquipmentKind kind) {
    return switch (kind) {
      EquipmentKind.camera => Icons.camera_alt_outlined,
      EquipmentKind.lens => Icons.camera_outdoor_outlined,
      EquipmentKind.telescope => Icons.travel_explore_outlined,
      EquipmentKind.mount => Icons.settings_input_component,
    };
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm deletion'),
            content: Text('Delete "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref, {
    required EquipmentKind kind,
    EquipmentItem? item,
  }) async {
    final result = await showDialog<EquipmentItem>(
      context: context,
      builder: (_) => EquipmentEditorDialog(kind: kind, item: item),
    );

    if (result == null || !context.mounted) return;

    await _runAction(
      context,
      () => ref.read(equipmentProvider.notifier).saveItem(result),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    EquipmentInventory inventory, {
    OpticalProfile? profile,
  }) async {
    final result = await showDialog<OpticalProfile>(
      context: context,
      builder: (_) =>
          OpticalProfileEditorDialog(inventory: inventory, profile: profile),
    );

    if (result == null || !context.mounted) return;

    await _runAction(
      context,
      () => ref.read(equipmentProvider.notifier).saveProfile(result),
    );
  }

  String _specifications(EquipmentItem item) {
    switch (item.kind) {
      case EquipmentKind.camera:
        return '${item.sensorWidthMm} × '
            '${item.sensorHeightMm} mm sensor\n'
            '${item.resolutionX} × ${item.resolutionY} px\n'
            '${item.pixelSizeXMicrons!.toStringAsFixed(2)} µm '
            'horizontal pixel pitch';

      case EquipmentKind.lens:
      case EquipmentKind.telescope:
        return '${item.focalLengthMm} mm focal length • '
            '${item.apertureMm} mm aperture\n'
            'f/${item.focalRatio!.toStringAsFixed(2)}';

      case EquipmentKind.mount:
        return '${item.payloadCapacityKg} kg '
            'manufacturer payload capacity';
    }
  }

  Widget _equipmentCard(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem item,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(_icon(item.kind)),
        title: Text(item.name),
        subtitle: Text('${item.kind.label}\n${_specifications(item)}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Equipment actions',
          onSelected: (action) async {
            if (action == 'edit') {
              await _editItem(context, ref, kind: item.kind, item: item);

              // The edit action is complete.
              // Do not continue into the deletion branch.
              return;
            }

            if (action == 'delete') {
              // Always verify the BuildContext before
              // using it following a possible async gap.
              if (!context.mounted) return;

              final confirmed = await _confirmDelete(context, item.name);

              if (!confirmed || !context.mounted) {
                return;
              }

              await _runAction(
                context,
                () => ref.read(equipmentProvider.notifier).deleteItem(item.id),
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    WidgetRef ref,
    EquipmentInventory inventory,
    OpticalProfile profile,
  ) {
    final camera = inventory.itemById(profile.cameraId);
    final optic = inventory.itemById(profile.opticId);

    final mount = profile.mountId == null
        ? null
        : inventory.itemById(profile.mountId!);

    final metrics = inventory.metricsFor(profile);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.center_focus_strong),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Profile actions',
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editProfile(
                        context,
                        ref,
                        inventory,
                        profile: profile,
                      );

                      // Editing and deleting are mutually
                      // exclusive actions.
                      return;
                    }

                    if (action == 'delete') {
                      if (!context.mounted) return;

                      final confirmed = await _confirmDelete(
                        context,
                        profile.name,
                      );

                      if (!confirmed || !context.mounted) {
                        return;
                      }

                      await _runAction(
                        context,
                        () => ref
                            .read(equipmentProvider.notifier)
                            .deleteProfile(profile.id),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),

            Text(
              '${camera?.name ?? "Unknown camera"} + '
              '${optic?.name ?? "Unknown optic"}',
            ),

            if (mount != null) Text('Mount: ${mount.name}'),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _metric(
                  'Effective focal length',
                  '${metrics.effectiveFocalLengthMm.toStringAsFixed(1)} mm',
                ),
                _metric(
                  'Focal ratio',
                  'f/${metrics.effectiveFocalRatio.toStringAsFixed(2)}',
                ),
                _metric(
                  'Horizontal FOV',
                  '${metrics.horizontalFovDegrees.toStringAsFixed(3)}°',
                ),
                _metric(
                  'Vertical FOV',
                  '${metrics.verticalFovDegrees.toStringAsFixed(3)}°',
                ),
                _metric(
                  'Pixel scale X',
                  '${metrics.pixelScaleXArcsec.toStringAsFixed(3)} ″/px',
                ),
                _metric(
                  'Pixel scale Y',
                  '${metrics.pixelScaleYArcsec.toStringAsFixed(3)} ″/px',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(equipmentProvider);
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
                  'Equipment Inventory',
                  style: theme.textTheme.headlineMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  'Manage your imaging equipment and '
                  'create reusable optical setups.',
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 24),

                state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  error: (error, stack) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appErrorMessage(error)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          ref.invalidate(equipmentProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),

                  data: (inventory) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final kind in EquipmentKind.values)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _editItem(context, ref, kind: kind),
                              icon: Icon(_icon(kind)),
                              label: Text('Add ${kind.label}'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      if (inventory.items.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No equipment yet. Add a camera, '
                              'lens, telescope or mount.',
                            ),
                          ),
                        ),

                      for (final kind in EquipmentKind.values)
                        if (inventory.items.any(
                          (item) => item.kind == kind,
                        )) ...[
                          const SizedBox(height: 12),

                          Text(
                            '${kind.label}s',
                            style: theme.textTheme.titleLarge,
                          ),

                          const SizedBox(height: 8),

                          for (final item in inventory.items)
                            if (item.kind == kind)
                              _equipmentCard(context, ref, item),
                        ],

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 20),

                      Text(
                        'Optical Profiles',
                        style: theme.textTheme.headlineSmall,
                      ),

                      const SizedBox(height: 12),

                      FilledButton.icon(
                        onPressed:
                            inventory.cameras.isEmpty ||
                                inventory.optics.isEmpty
                            ? null
                            : () => _editProfile(context, ref, inventory),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Optical Profile'),
                      ),

                      if (inventory.cameras.isEmpty || inventory.optics.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Add at least one camera and one '
                            'lens or telescope to create a profile.',
                          ),
                        ),

                      const SizedBox(height: 16),

                      for (final profile in inventory.profiles)
                        _profileCard(context, ref, inventory, profile),

                      if (inventory.profiles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No optical profiles created yet.'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
