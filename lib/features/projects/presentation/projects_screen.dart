import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/planned_projects_repository.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(plannedProjectsListProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Planned imaging projects',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh projects',
              onPressed: () => ref.invalidate(plannedProjectsListProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        projects.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text('Unable to load projects: $error'),
          data: (items) => items.isEmpty
              ? const Text(
                  'No projects yet. Open a celestial target and choose Save as project.',
                )
              : Column(
                  children: [
                    for (final project in items)
                      Card(
                        child: ListTile(
                          title: Text(project.title),
                          subtitle: Text(
                            '${project.targetIds.join(', ')} · '
                            '${project.observingDate ?? 'Date not selected'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete project',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(plannedProjectsRepositoryProvider)
                                    .remove(project.id);
                                if (context.mounted) {
                                  ref.invalidate(plannedProjectsListProvider);
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to delete project: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
