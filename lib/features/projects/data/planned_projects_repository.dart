import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/planned_imaging_project.dart';

abstract interface class PlannedProjectsRepository {
  Future<List<PlannedImagingProject>> load();
  Future<void> save(PlannedImagingProject project);
  Future<void> remove(String id);
}

/// Reuses the existing app_settings table: no Drift schema migration.
final class SettingsPlannedProjectsRepository
    implements PlannedProjectsRepository {
  const SettingsPlannedProjectsRepository(this._settings);

  final AppSettingsRepository _settings;
  static const storageKey = 'projects.planned.v1';

  @override
  Future<List<PlannedImagingProject>> load() async {
    final raw = await _settings.get(storageKey);
    if (raw == null) return const [];
    final json = jsonDecode(raw);
    if (json is! List) throw const FormatException('Invalid saved projects.');
    return List.unmodifiable(
      json.map(
        (entry) => PlannedImagingProject.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
      ),
    );
  }

  @override
  Future<void> save(PlannedImagingProject project) async {
    final projects = [...await load()];
    final index = projects.indexWhere((existing) => existing.id == project.id);
    if (index < 0) {
      projects.add(project);
    } else {
      projects[index] = project;
    }
    await _write(projects);
  }

  @override
  Future<void> remove(String id) async {
    final projects = [...await load()]
      ..removeWhere((project) => project.id == id);
    await _write(projects);
  }

  Future<void> _write(List<PlannedImagingProject> projects) async {
    projects.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    await _settings.put(
      storageKey,
      jsonEncode(projects.map((e) => e.toJson()).toList()),
    );
  }
}

final plannedProjectsRepositoryProvider = Provider<PlannedProjectsRepository>((
  ref,
) {
  return SettingsPlannedProjectsRepository(
    ref.watch(appSettingsRepositoryProvider),
  );
});

/// Creates a project that contains one target and its chosen observing plan.
PlannedImagingProject newPlannedProject({
  required String title,
  required String targetId,
  required DateTime localDate,
  required String? locationId,
  required String? profileId,
  DateTime? startUtc,
  DateTime? endUtc,
  DateTime? nowUtc,
}) {
  final date =
      '${localDate.year.toString().padLeft(4, '0')}-'
      '${localDate.month.toString().padLeft(2, '0')}-'
      '${localDate.day.toString().padLeft(2, '0')}';
  return PlannedImagingProject(
    id: const Uuid().v4(),
    title: title,
    targetIds: [targetId],
    createdAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
    observingDate: date,
    locationId: locationId,
    opticalProfileId: profileId,
    windowStartUtc: startUtc,
    windowEndUtc: endUtc,
  );
}

final plannedProjectsListProvider = FutureProvider<List<PlannedImagingProject>>(
  (ref) => ref.watch(plannedProjectsRepositoryProvider).load(),
  retry: (count, error) => null,
);
