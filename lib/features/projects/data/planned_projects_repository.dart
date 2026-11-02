import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/app_settings_repository.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/planned_imaging_project.dart';
import 'attachments/attachment_store.dart';

abstract interface class PlannedProjectsRepository {
  Future<List<PlannedImagingProject>> load();
  Future<void> save(PlannedImagingProject project);
  Future<void> remove(String id);
}

/// Normalized SQLite storage. Both project metadata and the many-to-many
/// target links are updated atomically. Equipment references are intentionally
/// not foreign keys, so deleting an optical profile cannot delete a project.
final class DriftPlannedProjectsRepository
    implements PlannedProjectsRepository {
  DriftPlannedProjectsRepository(this._database, this._settings);

  final AppDatabase _database;
  final AppSettingsRepository _settings;
  bool _legacyChecked = false;

  /// One-time, lossless import of records created by Issue #25.
  /// The legacy key is deleted only after all project inserts succeed.
  Future<void> _importLegacyIfNeeded() async {
    if (_legacyChecked) return;
    final raw = await _settings.get(
      SettingsPlannedProjectsRepository.storageKey,
    );
    if (raw == null) {
      _legacyChecked = true;
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Invalid legacy imaging projects.');
    }
    final projects = decoded
        .map(
          (value) => PlannedImagingProject.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
    await _database.transaction(() async {
      for (final project in projects) {
        // Existing native projects take precedence if an earlier import was
        // interrupted before the old key could be cleared.
        final existing = await _database
            .customSelect(
              'SELECT id FROM imaging_projects WHERE id = ?',
              variables: [Variable<String>(project.id)],
            )
            .get();
        if (existing.isEmpty) await _saveRows(project);
      }
      await _settings.delete(SettingsPlannedProjectsRepository.storageKey);
    });
    _legacyChecked = true;
  }

  @override
  Future<List<PlannedImagingProject>> load() async {
    await _importLegacyIfNeeded();
    final rows = await _database.customSelect('''
      SELECT id, title, description, notes, imaging_goal, status,
             created_at_utc, updated_at_utc, planned_integration_seconds,
             observing_date, location_id, optical_profile_id,
             window_start_utc, window_end_utc
      FROM imaging_projects
      ORDER BY CASE status WHEN 'archived' THEN 1 ELSE 0 END,
               updated_at_utc DESC, id
    ''').get();
    final links = await _database.customSelect('''
      SELECT project_id, target_id FROM imaging_project_targets
      ORDER BY rowid
    ''').get();
    final targets = <String, List<String>>{};
    for (final row in links) {
      targets
          .putIfAbsent(row.read<String>('project_id'), () => [])
          .add(row.read<String>('target_id'));
    }
    return List.unmodifiable(
      rows.map(
        (row) => PlannedImagingProject(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          targetIds: targets[row.read<String>('id')] ?? const [],
          createdAtUtc: DateTime.parse(row.read<String>('created_at_utc'))
              .toUtc(),
          updatedAtUtc: DateTime.parse(row.read<String>('updated_at_utc'))
              .toUtc(),
          description: row.read<String>('description'),
          notes: row.read<String>('notes'),
          imagingGoal: row.read<String>('imaging_goal'),
          status: ImagingProjectStatus.values.byName(
            row.read<String>('status'),
          ),
          plannedIntegrationSeconds: row.read<int>(
            'planned_integration_seconds',
          ),
          observingDate: row.readNullable<String>('observing_date'),
          locationId: row.readNullable<String>('location_id'),
          opticalProfileId: row.readNullable<String>('optical_profile_id'),
          windowStartUtc: _readUtc(
            row.readNullable<String>('window_start_utc'),
          ),
          windowEndUtc: _readUtc(row.readNullable<String>('window_end_utc')),
        ),
      ),
    );
  }

  DateTime? _readUtc(String? value) =>
      value == null ? null : DateTime.parse(value).toUtc();

  @override
  Future<void> save(PlannedImagingProject project) async {
    project.validate();
    await _importLegacyIfNeeded();
    await _database.transaction(() => _saveRows(project));
  }

  Future<void> _saveRows(PlannedImagingProject project) async {
    await _database.customStatement(
      '''
      INSERT INTO imaging_projects (
        id, title, description, notes, imaging_goal, status, created_at_utc,
        updated_at_utc, planned_integration_seconds, observing_date,
        location_id, optical_profile_id, window_start_utc, window_end_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        description = excluded.description,
        notes = excluded.notes,
        imaging_goal = excluded.imaging_goal,
        status = excluded.status,
        updated_at_utc = excluded.updated_at_utc,
        planned_integration_seconds = excluded.planned_integration_seconds,
        observing_date = excluded.observing_date,
        location_id = excluded.location_id,
        optical_profile_id = excluded.optical_profile_id,
        window_start_utc = excluded.window_start_utc,
        window_end_utc = excluded.window_end_utc
    ''',
      [
        project.id,
        project.title,
        project.description,
        project.notes,
        project.imagingGoal,
        project.status.name,
        project.createdAtUtc.toIso8601String(),
        project.updatedAtUtc.toIso8601String(),
        project.plannedIntegrationSeconds,
        project.observingDate,
        project.locationId,
        project.opticalProfileId,
        project.windowStartUtc?.toIso8601String(),
        project.windowEndUtc?.toIso8601String(),
      ],
    );
    await _database.customStatement(
      'DELETE FROM imaging_project_targets WHERE project_id = ?',
      [project.id],
    );
    for (final id in project.targetIds) {
      await _database.customStatement(
        '''
        INSERT INTO imaging_project_targets (project_id, target_id)
        VALUES (?, ?)
      ''',
        [project.id, id],
      );
    }
  }

  @override
  Future<void> remove(String id) async {
    await _importLegacyIfNeeded();
    // Project deletion cascades session and image metadata. Remove detached
    // image files as well to avoid leaving orphaned local attachments.
    final imageRows = await _database
        .customSelect(
          '''
      SELECT storage_key FROM observation_session_images WHERE session_id IN
        (SELECT id FROM observation_sessions WHERE project_id = ?)
    ''',
          variables: [Variable<String>(id)],
        )
        .get();
    await _database.transaction(() async {
      await _settings.delete('projects.mosaic.v1.${Uri.encodeComponent(id)}');
      await _database.customStatement(
        'DELETE FROM imaging_projects WHERE id = ?',
        [id],
      );
    });
    final storage = createSessionAttachmentStore();
    for (final row in imageRows) {
      await storage.remove(row.read<String>('storage_key'));
    }
  }
}

/// Kept for compatibility with older imported backups and legacy tests.
/// New writes in the running application use DriftPlannedProjectsRepository.
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
  final db = ref.watch(appDatabaseProvider);
  return DriftPlannedProjectsRepository(db, AppSettingsRepository(db));
});

/// Creates a new project (also used by the target detail screen).
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
