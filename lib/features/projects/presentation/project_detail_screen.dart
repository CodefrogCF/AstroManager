import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../equipment/application/equipment_controller.dart';
import '../../targets/application/celestial_catalog_controller.dart';
import '../../targets/domain/models/celestial_object.dart';
import '../data/planned_projects_repository.dart';
import '../domain/planned_imaging_project.dart';
import 'project_editor_dialog.dart';
import 'project_integration_progress.dart';
import 'observation_sessions_section.dart';
import '../../mosaic/presentation/project_mosaic_section.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final PlannedImagingProject project;

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late PlannedImagingProject _project;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Project operation failed: $error')));
  }

  Future<void> _update(PlannedImagingProject project) async {
    setState(() => _busy = true);
    try {
      await ref.read(plannedProjectsRepositoryProvider).save(project);
      if (!mounted) return;
      setState(() => _project = project);
      ref.invalidate(plannedProjectsListProvider);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final changed = await showDialog<PlannedImagingProject>(
      context: context,
      builder: (context) => ProjectEditorDialog(project: _project),
    );
    if (changed != null && mounted) await _update(changed);
  }

  Future<void> _toggleArchive() async {
    await _update(
      _project.copyWith(
        status: _project.status == ImagingProjectStatus.archived
            ? ImagingProjectStatus.planned
            : ImagingProjectStatus.archived,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'Permanently delete "${_project.title}" and its target associations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('project-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(plannedProjectsRepositoryProvider).remove(_project.id);
      if (!mounted) return;
      ref.invalidate(plannedProjectsListProvider);
      Navigator.pop(context);
    } catch (error) {
      _error(error);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<CelestialObject?> _findTarget(String id) async {
    await ref.read(celestialCatalogProvider.future);
    return ref.read(celestialCatalogRepositoryProvider).findById(id);
  }

  @override
  Widget build(BuildContext context) {
    final equipment = ref.watch(equipmentProvider);
    final profile = equipment.when(
      loading: () => null,
      error: (error, stack) => null,
      data: (inventory) {
        for (final candidate in inventory.profiles) {
          if (candidate.id == _project.opticalProfileId) return candidate.name;
        }
        return null;
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(_project.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text(_project.status.label)),
              OutlinedButton.icon(
                key: const ValueKey('project-edit'),
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('project-archive'),
                onPressed: _busy ? null : _toggleArchive,
                icon: Icon(
                  _project.status == ImagingProjectStatus.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(
                  _project.status == ImagingProjectStatus.archived
                      ? 'Restore'
                      : 'Archive',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('project-delete'),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          if (_project.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(_project.description),
            ),
          Text('Imaging plan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ProjectIntegrationProgress(project: _project),
          Text(
            'Imaging goal: ${_project.imagingGoal.isEmpty ? 'Not specified' : _project.imagingGoal}',
          ),
          Text('Observing date: ${_project.observingDate ?? 'Not scheduled'}'),
          Text('Location: ${_project.locationId ?? 'Not assigned'}'),
          Text(
            'Imaging setup: ${_project.opticalProfileId == null ? 'Not assigned' : profile ?? '${_project.opticalProfileId} (profile unavailable)'}',
          ),
          if (_project.windowStartUtc != null)
            Text(
              'Window: ${_project.windowStartUtc!.toLocal()} – '
              '${_project.windowEndUtc?.toLocal() ?? 'Not specified'}',
            ),
          const SizedBox(height: 18),
          Text(
            'Celestial targets',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_project.targetIds.isEmpty)
            const Text(
              'No targets assigned. Use Edit to add a catalog target.',
            ),
          for (final id in _project.targetIds)
            FutureBuilder<CelestialObject?>(
              future: _findTarget(id),
              builder: (context, snapshot) => ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(snapshot.data?.displayTitle ?? id),
                subtitle: snapshot.hasError
                    ? const Text(
                        'Catalog unavailable — saved identifier retained',
                      )
                    : snapshot.connectionState == ConnectionState.done &&
                          snapshot.data == null
                    ? const Text(
                        'Catalog object not found — reference retained',
                      )
                    : Text(id),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  AppRoutes.targetDetails(id),
                  extra: snapshot.data,
                ),
              ),
            ),
          const SizedBox(height: 18),
          ProjectMosaicSection(project: _project),
          const SizedBox(height: 18),
          ObservationSessionsSection(projectId: _project.id),
          const SizedBox(height: 18),
          Text('Notes', style: Theme.of(context).textTheme.titleLarge),
          Text(_project.notes.isEmpty ? 'No notes yet.' : _project.notes),
          const SizedBox(height: 18),
          Text('Created: ${_project.createdAtUtc.toLocal()}'),
          Text('Last updated: ${_project.updatedAtUtc.toLocal()}'),
        ],
      ),
    );
  }
}
