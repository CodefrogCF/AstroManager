import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_choice.dart';
import '../../../app/theme/theme_controller.dart';
import '../../equipment/application/equipment_controller.dart';
import '../../locations/application/observing_locations_controller.dart';
import '../../planner/data/night_plans_repository.dart';
import '../../projects/data/observation_sessions_repository.dart';
import '../../projects/data/planned_projects_repository.dart';
import '../../settings/application/app_preferences_controller.dart';
import '../data/backup_service.dart';

class BackupSettingsSection extends ConsumerStatefulWidget {
  const BackupSettingsSection({super.key});

  @override
  ConsumerState<BackupSettingsSection> createState() =>
      _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends ConsumerState<BackupSettingsSection> {
  bool _busy = false;
  bool _includeImages = false;

  void _message(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ref
          .read(astroBackupServiceProvider)
          .export(
            includeImages: _includeImages,
            theme: ref.read(appThemeProvider).name,
          );
      // The .ambackup extension identifies our versioned ZIP container.
      // file_picker v13 exposes static methods and writes the supplied bytes.
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Export AstroManager backup',
        fileName:
            'AstroManager-${DateTime.now().toIso8601String().substring(0, 10)}.ambackup',
        mimeType: 'application/zip',
        bytes: data,
      );
      if (destination != null) {
        _message('Backup exported. Store it securely.');
      }
    } catch (error) {
      _message('Backup export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<BackupRestoreMode?> _chooseMode(BackupPreview preview) =>
      showDialog<BackupRestoreMode>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore AstroManager backup?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created: ${preview.createdAtUtc.toLocal()}'),
                Text(
                  '${preview.totalRows} records · '
                  '${preview.imageCount} images',
                ),
                if (!preview.includesImages)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'This backup does not include image attachments.',
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Merge retains existing records and rejects '
                  'duplicate identifiers. Replace removes all existing '
                  'user data before restoring the backup.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, BackupRestoreMode.merge),
              child: const Text('Merge (no overwrites)'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, BackupRestoreMode.replace),
              child: const Text('Replace all data…'),
            ),
          ],
        ),
      );

  Future<bool> _confirmReplace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all current AstroManager data?'),
        content: const Text(
          'This will replace existing locations, equipment, imaging '
          'projects, sessions, night plans and preferences. '
          'It cannot be undone. Export your current data first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep current data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete and restore'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['ambackup', 'zip'], // Accept older backups.
      );
      if (picked == null || !mounted) {
        return;
      }
      final size = picked.lengthSync() ?? await picked.length();
      if (size == null || size > 256 * 1024 * 1024) {
        throw const FormatException('Backup file is too large or unreadable.');
      }
      final Uint8List bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }
      final backup = ref.read(astroBackupServiceProvider);
      final preview = backup.inspect(bytes);
      final mode = await _chooseMode(preview);
      if (mode == null || !mounted) {
        return;
      }
      if (mode == BackupRestoreMode.replace && !await _confirmReplace()) {
        return;
      }
      if (!mounted) {
        return;
      }
      await backup.restore(
        bytes,
        mode: mode,
        confirmedReplace: mode == BackupRestoreMode.replace,
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(observingLocationsProvider);
      ref.invalidate(equipmentProvider);
      ref.invalidate(appPreferencesProvider);
      ref.invalidate(plannedProjectsListProvider);
      ref.invalidate(observationSessionsForProjectProvider);
      ref.invalidate(observationSessionImagesProvider);
      ref.invalidate(nightPlansProvider);
      if (preview.theme != null) {
        try {
          await ref
              .read(appThemeProvider.notifier)
              .select(AppThemeChoice.values.byName(preview.theme!));
        } catch (_) {
          _message(
            'Data restored. Appearance preference could not be applied.',
          );
          return;
        }
      }
      _message('Backup restored successfully.');
    } catch (error) {
      _message(
        'Restore cancelled or failed; existing database preserved: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Backup & restore',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Portable .ambackup files contain a ZIP archive and work '
        'offline. Backups are not encrypted; store them securely. '
        'Older .zip backups can also be restored. '
        'The bundled celestial catalog is not included.',
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        key: const ValueKey('backup-include-images'),
        title: const Text('Include session images'),
        subtitle: const Text('Larger file; attachments stay outside SQLite.'),
        value: _includeImages,
        onChanged: _busy
            ? null
            : (value) => setState(() => _includeImages = value ?? false),
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            key: const ValueKey('backup-export'),
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Export backup'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('backup-restore'),
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Restore backup'),
          ),
        ],
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
    ],
  );
}
