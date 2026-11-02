import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/planned_projects_repository.dart';
import '../domain/planned_imaging_project.dart';
import 'project_detail_screen.dart';
import 'project_editor_dialog.dart';
import 'project_integration_progress.dart';

/// Offline project hub. All operations use the same repository as target details.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  ImagingProjectStatus? _filter;
  bool _saving = false;

  Future<void> _create() async {
    final project = await showDialog<PlannedImagingProject>(
      context: context,
      builder: (context) => const ProjectEditorDialog(),
    );
    if (project == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(plannedProjectsRepositoryProvider).save(project);
      if (!mounted) return;
      ref.invalidate(plannedProjectsListProvider);
      await _open(project);
    } catch (error) {
      _report(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(PlannedImagingProject project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailScreen(project: project),
      ),
    );
    if (mounted) ref.invalidate(plannedProjectsListProvider);
  }

  void _report(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to manage projects: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(plannedProjectsListProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          children: [
            Text(
              'Astrophotography projects',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Refresh projects',
                  onPressed: () => ref.invalidate(plannedProjectsListProvider),
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.icon(
                  key: const ValueKey('project-create'),
                  onPressed: _saving ? null : _create,
                  icon: const Icon(Icons.add),
                  label: const Text('New project'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            FilterChip(
              key: const ValueKey('project-filter-active'),
              label: const Text('Active'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final status in ImagingProjectStatus.values)
              FilterChip(
                key: ValueKey('project-filter-${status.name}'),
                label: Text(status.label),
                selected: _filter == status,
                onSelected: (_) => setState(() => _filter = status),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_saving) const LinearProgressIndicator(),
        projects.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unable to load projects: $error'),
              TextButton(
                onPressed: () => ref.invalidate(plannedProjectsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (items) {
            final visible = items
                .where(
                  (project) => _filter == null
                      ? project.status != ImagingProjectStatus.archived
                      : project.status == _filter,
                )
                .toList();
            if (visible.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No matching projects. Create one or change the status filter.',
                ),
              );
            }
            return Column(
              children: [
                for (final project in visible)
                  Card(
                    child: ListTile(
                      key: ValueKey('project-${project.id}'),
                      title: Text(project.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${project.status.label} · '
                            '${project.targetIds.length} target(s) · '
                            '${project.observingDate ?? 'Unscheduled'}',
                          ),
                          ProjectIntegrationListSummary(project: project),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(project),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
