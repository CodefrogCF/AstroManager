import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../equipment/application/equipment_controller.dart';
import '../../equipment/domain/models/equipment_models.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../domain/planned_imaging_project.dart';

/// Create / edit dialog that returns a validated project but leaves persistence
/// to the caller, allowing save failures to be shown in the originating view.
class ProjectEditorDialog extends ConsumerStatefulWidget {
  const ProjectEditorDialog({
    super.key,
    this.project,
    this.testEquipment,
    this.testTargets,
  });

  final PlannedImagingProject? project;
  final EquipmentInventory? testEquipment;
  final List<CelestialObject>? testTargets;

  @override
  ConsumerState<ProjectEditorDialog> createState() =>
      _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends ConsumerState<ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _goal;
  late final TextEditingController _integrationMinutes;
  late List<String> _targets;
  late ImagingProjectStatus _status;
  String? _profileId;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _title = TextEditingController(text: project?.title ?? '');
    _description = TextEditingController(text: project?.description ?? '');
    _notes = TextEditingController(text: project?.notes ?? '');
    _goal = TextEditingController(text: project?.imagingGoal ?? '');
    _integrationMinutes = TextEditingController(
      text: ((project?.plannedIntegrationSeconds ?? 0) ~/ 60).toString(),
    );
    _targets = [...?project?.targetIds];
    _profileId = project?.opticalProfileId;
    _status = project?.status ?? ImagingProjectStatus.planned;
    _date = project?.observingDate == null
        ? null
        : DateTime.tryParse(project!.observingDate!);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _notes.dispose();
    _goal.dispose();
    _integrationMinutes.dispose();
    super.dispose();
  }

  Future<void> _pickTarget() async {
    final search = TextEditingController();
    Future<List<CelestialObject>> load(String query) async {
      if (widget.testTargets != null) {
        return widget.testTargets!
            .where(
              (target) =>
                  target.designation.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  target.commonNames.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  target.aliases.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
      await ref.read(celestialCatalogProvider.future);
      return ref.read(celestialCatalogRepositoryProvider).search(query: query);
    }

    try {
      var matches = load('');
      final picked = await showDialog<CelestialObject>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, updateDialog) => AlertDialog(
            title: const Text('Add catalog target'),
            content: SizedBox(
              width: 460,
              height: 340,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('project-catalog-query'),
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Search Messier, NGC, IC or common name',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        updateDialog(() => matches = load(value)),
                  ),
                  Expanded(
                    child: FutureBuilder<List<CelestialObject>>(
                      future: matches,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Catalog unavailable: ${snapshot.error}',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final target = snapshot.data![index];
                            return ListTile(
                              title: Text(target.displayTitle),
                              subtitle: Text(target.commonNames),
                              onTap: () => Navigator.pop(dialogContext, target),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
      if (picked != null && mounted && !_targets.contains(picked.id)) {
        setState(() => _targets.add(picked.id));
      }
    } finally {
      // The dialog route is fully dismissed before disposing its controller.
      search.dispose();
    }
  }

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().toUtc();
    final original = widget.project;
    final formattedDate = _date == null
        ? null
        : '${_date!.year.toString().padLeft(4, '0')}-'
              '${_date!.month.toString().padLeft(2, '0')}-'
              '${_date!.day.toString().padLeft(2, '0')}';
    final dateChanged = formattedDate != original?.observingDate;
    final project = PlannedImagingProject(
      id: original?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      targetIds: _targets,
      createdAtUtc: original?.createdAtUtc ?? now,
      updatedAtUtc: now,
      description: _description.text.trim(),
      notes: _notes.text.trim(),
      imagingGoal: _goal.text.trim(),
      status: _status,
      plannedIntegrationSeconds:
          int.parse(_integrationMinutes.text.trim()) * 60,
      observingDate: formattedDate,
      locationId: original?.locationId,
      opticalProfileId: _profileId,
      windowStartUtc: dateChanged ? null : original?.windowStartUtc,
      windowEndUtc: dateChanged ? null : original?.windowEndUtc,
    );
    Navigator.of(context).pop(project);
  }

  @override
  Widget build(BuildContext context) {
    final equipment = widget.testEquipment;
    final remoteEquipment = equipment == null
        ? ref.watch(equipmentProvider)
        : null;
    final profiles =
        equipment?.profiles ??
        remoteEquipment?.when(
          data: (inventory) => inventory.profiles,
          loading: () => const <OpticalProfile>[],
          error: (error, stack) => const <OpticalProfile>[],
        ) ??
        const <OpticalProfile>[];
    final knownProfile = profiles.any((profile) => profile.id == _profileId);
    return AlertDialog(
      title: Text(
        widget.project == null ? 'New imaging project' : 'Edit project',
      ),
      content: SizedBox(
        width: 510,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const ValueKey('project-title'),
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Project title *',
                  ),
                  validator: (text) => (text?.trim().isEmpty ?? true)
                      ? 'Enter a project title.'
                      : null,
                ),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextFormField(
                  controller: _goal,
                  decoration: const InputDecoration(
                    labelText: 'Imaging goal',
                    hintText: 'e.g. LRGB mosaic',
                  ),
                ),
                TextFormField(
                  key: const ValueKey('project-integration'),
                  controller: _integrationMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Planned integration (minutes)',
                  ),
                  validator: (value) {
                    final minutes = int.tryParse(value?.trim() ?? '');
                    return minutes == null || minutes < 0 || minutes > 1000000
                        ? 'Enter a valid non-negative whole number.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ImagingProjectStatus>(
                  key: const ValueKey('project-status'),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in ImagingProjectStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (status) {
                    if (status != null) setState(() => _status = status);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'project-optic-${_profileId ?? 'none'}-$knownProfile',
                  ),
                  isExpanded: true,
                  initialValue: _profileId ?? '__none__',
                  decoration: const InputDecoration(labelText: 'Imaging setup'),
                  items: [
                    const DropdownMenuItem(
                      value: '__none__',
                      child: Text('No equipment selected'),
                    ),
                    if (_profileId != null && !knownProfile)
                      DropdownMenuItem(
                        value: _profileId,
                        child: Text(
                          'Unavailable profile ($_profileId)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    for (final profile in profiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(
                          profile.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    _profileId = id == '__none__' ? null : id;
                  }),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _date == null
                          ? 'No date selected'
                          : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}',
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: const Text('Plan date'),
                    ),
                    if (_date != null)
                      TextButton(
                        onPressed: () => setState(() => _date = null),
                        child: const Text('Clear date'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Catalog targets',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final target in _targets)
                      InputChip(
                        label: Text(target),
                        onDeleted: () =>
                            setState(() => _targets.remove(target)),
                      ),
                    ActionChip(
                      key: const ValueKey('project-add-target'),
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add target'),
                      onPressed: _pickTarget,
                    ),
                  ],
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('project-confirm-save'),
          onPressed: _submit,
          child: const Text('Save project'),
        ),
      ],
    );
  }
}
