import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../../projects/data/attachments/attachment_store.dart';
import '../../planner/domain/night_observation_block.dart';
import '../../mosaic/domain/mosaic_plan.dart';
import '../../settings/domain/models/app_preferences.dart';

/// Portable AstroManager backup format v1; application schema v6.
/// These are user-owned tables only. The bundled OpenNGC catalog can be
/// regenerated from application assets and is intentionally not exported.
const backupTables = <String>[
  'app_settings',
  'observing_locations',
  'equipment_items',
  'optical_profiles',
  'imaging_projects',
  'imaging_project_targets',
  'observation_sessions',
  'observation_session_images',
];

const _deleteOrder = <String>[
  'observation_session_images',
  'observation_sessions',
  'imaging_project_targets',
  'imaging_projects',
  'optical_profiles',
  'equipment_items',
  'observing_locations',
  'app_settings',
];

const _maxBackupBytes = 256 * 1024 * 1024;
const _maxImageBytes = 20 * 1024 * 1024;

enum BackupRestoreMode { merge, replace }

final class BackupPreview {
  const BackupPreview({
    required this.createdAtUtc,
    required this.counts,
    required this.includesImages,
    required this.imageCount,
    this.theme,
  });

  final DateTime createdAtUtc;
  final Map<String, int> counts;
  final bool includesImages;
  final int imageCount;
  final String? theme;

  int get totalRows => counts.values.fold(0, (total, count) => total + count);
}

final class _ParsedBackup {
  const _ParsedBackup(this.preview, this.tables, this.images);
  final BackupPreview preview;
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, Uint8List> images;
}

/// Database imports are transactional. Binary attachments are staged under
/// fresh keys before commit, avoiding overwriting any existing image. Failed
/// imports remove staged files; replaced images are cleaned up after commit.
final class AstroBackupService {
  AstroBackupService(this._db, {SessionAttachmentStore? attachments})
    : _attachments = attachments ?? createSessionAttachmentStore();

  final AppDatabase _db;
  final SessionAttachmentStore _attachments;

  String _hash(List<int> bytes) => sha256.convert(bytes).toString();

  Future<Map<String, List<Map<String, Object?>>>> _readTables({
    required bool includeImages,
  }) async {
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in backupTables) {
      if (table == 'observation_session_images' && !includeImages) {
        result[table] = [];
        continue;
      }
      final rows = await _db.customSelect('SELECT * FROM $table').get();
      result[table] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList(growable: false);
    }
    return result;
  }

  Future<Uint8List> export({bool includeImages = false, String? theme}) async {
    // Do not mix reads from different points in time.
    final tables = await _db.transaction(
      () => _readTables(includeImages: includeImages),
    );
    final imageEntries = <Map<String, Object?>>[];
    final archive = Archive();
    var totalSize = 0;
    if (includeImages) {
      for (final row in tables['observation_session_images']!) {
        final id = row['id'] as String;
        if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
          throw const FormatException('Invalid image attachment identifier.');
        }
        final bytes = await _attachments.read(row['storage_key'] as String);
        if (bytes.isEmpty ||
            bytes.length > _maxImageBytes ||
            bytes.length != row['byte_length']) {
          throw FormatException('Missing or damaged image: $id');
        }
        totalSize += bytes.length;
        if (totalSize > _maxBackupBytes) {
          throw const FormatException(
            'Attachments exceed the 256 MB backup limit.',
          );
        }
        final path = 'images/$id.bin';
        archive.addFile(ArchiveFile.bytes(path, bytes));
        imageEntries.add({
          'id': id,
          'path': path,
          'size': bytes.length,
          'sha256': _hash(bytes),
        });
      }
    }

    final data = Uint8List.fromList(utf8.encode(jsonEncode(tables)));
    if (totalSize + data.length > _maxBackupBytes) {
      throw const FormatException('Backup exceeds the 256 MB limit.');
    }
    final manifest = <String, Object?>{
      'format': 'astromanager-backup',
      'formatVersion': 1,
      'databaseSchemaVersion': 6,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'includesImages': includeImages,
      'theme': theme,
      'dataSha256': _hash(data),
      'counts': {
        for (final table in backupTables) table: tables[table]!.length,
      },
      'images': imageEntries,
    };
    archive.addFile(ArchiveFile.bytes('data.json', data));
    archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    final encoded = ZipEncoder().encodeBytes(archive);
    if (encoded.length > _maxBackupBytes) {
      throw const FormatException('Compressed backup exceeds 256 MB.');
    }
    return encoded;
  }

  /// Full validation occurs before any database or file writes.
  BackupPreview inspect(Uint8List bytes) => _parse(bytes).preview;

  _ParsedBackup _parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxBackupBytes) {
      throw const FormatException('Invalid backup size (maximum 256 MB).');
    }
    late final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const FormatException('Corrupt or unsupported ZIP archive.');
    }
    final entries = <String, Uint8List>{};
    var totalSize = 0;
    for (final file in zip) {
      if (!file.isFile ||
          file.isSymbolicLink ||
          file.isHardLink ||
          file.size < 0 ||
          file.name.contains('..') ||
          file.name.startsWith('/') ||
          file.name.contains('\\') ||
          entries.containsKey(file.name)) {
        throw const FormatException('Unsafe or duplicate ZIP entry.');
      }
      if (file.size > _maxBackupBytes ||
          totalSize + file.size > _maxBackupBytes) {
        throw const FormatException('Decompressed backup exceeds 256 MB.');
      }
      final content = file.readBytes();
      if (content == null || content.length != file.size) {
        throw const FormatException('Damaged ZIP entry.');
      }
      totalSize += content.length;
      entries[file.name] = content;
    }
    if (!entries.containsKey('manifest.json') ||
        !entries.containsKey('data.json')) {
      throw const FormatException('Not an AstroManager backup.');
    }
    try {
      final manifest = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(entries['manifest.json']!)) as Map,
      );
      if (manifest['format'] != 'astromanager-backup' ||
          manifest['formatVersion'] != 1 ||
          manifest['databaseSchemaVersion'] != 6) {
        throw const FormatException(
          'Unsupported backup format or database version.',
        );
      }
      if (_hash(entries['data.json']!) != manifest['dataSha256']) {
        throw const FormatException('Backup data checksum mismatch.');
      }
      final rawTables = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(entries['data.json']!)) as Map,
      );
      final rawCounts = Map<String, dynamic>.from(manifest['counts'] as Map);
      if (rawTables.length != backupTables.length ||
          rawCounts.length != backupTables.length) {
        throw const FormatException('Incomplete backup table list.');
      }
      final tables = <String, List<Map<String, Object?>>>{};
      for (final table in backupTables) {
        final values = rawTables[table];
        if (values is! List) {
          throw FormatException('Missing table: $table');
        }
        final rows = values
            .map((value) {
              final row = Map<String, Object?>.from(value as Map);
              if (row.values.any((v) => v is Map || v is List)) {
                throw const FormatException(
                  'Nested SQLite values are not allowed.',
                );
              }
              return row;
            })
            .toList(growable: false);
        if (rawCounts[table] != rows.length) {
          throw FormatException('Row count mismatch for $table.');
        }
        tables[table] = rows;
      }
      // A restored mosaic must always refer to a project carried by the
      // archive; app_settings keys do not have SQL foreign key constraints.
      final savedProjectIds = tables['imaging_projects']!
          .map((row) => row['id'])
          .toSet();
      // Validate typed settings stored in the generic app_settings table,
      // including the JSON-based night plans from Issue #30.
      for (final row in tables['app_settings']!) {
        final key = row['key'];
        final value = row['value'];
        if (key is! String || value is! String) {
          throw const FormatException('Invalid application setting.');
        }
        if (key == 'app.preferences.v1') {
          AppPreferences.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          );
        } else if (key.startsWith('projects.mosaic.v1.')) {
          final plan = MosaicPlan.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          );
          if ('projects.mosaic.v1.${Uri.encodeComponent(plan.projectId)}' !=
                  key ||
              !savedProjectIds.contains(plan.projectId)) {
            throw const FormatException('Mosaic project key mismatch.');
          }
        } else if (key.startsWith('planner.night.v1.')) {
          final blocks = jsonDecode(value);
          if (blocks is! List) {
            throw const FormatException('Invalid night plan in backup.');
          }
          for (final item in blocks) {
            NightObservationBlock.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
          }
        }
      }
      final includesImages = manifest['includesImages'] == true;
      final imagesManifest = manifest['images'];
      if (imagesManifest is! List ||
          (!includesImages &&
              (imagesManifest.isNotEmpty ||
                  tables['observation_session_images']!.isNotEmpty))) {
        throw const FormatException('Invalid image manifest.');
      }
      final images = <String, Uint8List>{};
      for (final item in imagesManifest) {
        final entry = Map<String, dynamic>.from(item as Map);
        final id = entry['id'];
        final path = entry['path'];
        if (id is! String ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id) ||
            path != 'images/$id.bin' ||
            !entries.containsKey(path) ||
            images.containsKey(id)) {
          throw const FormatException('Invalid image reference.');
        }
        final data = entries[path]!;
        if (data.isEmpty ||
            data.length > _maxImageBytes ||
            data.length != entry['size'] ||
            _hash(data) != entry['sha256']) {
          throw const FormatException('Invalid image checksum or size.');
        }
        images[id] = data;
      }
      if (images.length != tables['observation_session_images']!.length ||
          entries.length != images.length + 2) {
        throw const FormatException('Missing or unexpected backup files.');
      }
      for (final row in tables['observation_session_images']!) {
        final id = row['id'];
        if (id is! String ||
            !images.containsKey(id) ||
            row['byte_length'] != images[id]!.length) {
          throw const FormatException('Image metadata mismatch.');
        }
      }
      final timestamp = DateTime.parse(manifest['createdAtUtc'] as String);
      if (!timestamp.isUtc) {
        throw const FormatException('Backup timestamp must be UTC.');
      }
      final theme = manifest['theme'];
      if (theme != null &&
          (theme is! String ||
              !{'system', 'light', 'dark', 'night'}.contains(theme))) {
        throw const FormatException('Invalid saved theme.');
      }
      return _ParsedBackup(
        BackupPreview(
          createdAtUtc: timestamp,
          counts: Map.unmodifiable({
            for (final table in backupTables) table: tables[table]!.length,
          }),
          includesImages: includesImages,
          imageCount: images.length,
          theme: theme as String?,
        ),
        tables,
        images,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid backup structure or data.');
    }
  }

  Future<Map<String, List<String>>> _columns() async {
    final columns = <String, List<String>>{};
    for (final table in backupTables) {
      final rows = await _db.customSelect('PRAGMA table_info($table)').get();
      if (rows.isEmpty) {
        throw StateError('Database missing table $table');
      }
      columns[table] = rows.map((row) => row.read<String>('name')).toList();
    }
    return columns;
  }

  Future<void> restore(
    Uint8List bytes, {
    BackupRestoreMode mode = BackupRestoreMode.merge,
    bool confirmedReplace = false,
  }) async {
    if (mode == BackupRestoreMode.replace && !confirmedReplace) {
      throw StateError(
        'Replacing existing records requires explicit confirmation.',
      );
    }
    final parsed = _parse(bytes);
    final columns = await _columns();
    for (final table in backupTables) {
      for (final row in parsed.tables[table]!) {
        if (row.keys.toSet().difference(columns[table]!.toSet()).isNotEmpty ||
            columns[table]!.toSet().difference(row.keys.toSet()).isNotEmpty) {
          throw FormatException('Unexpected columns in $table.');
        }
      }
    }

    // Fresh, unguessable keys prevent an import from overwriting preexisting
    // binary files even when record identifiers match.
    final staged = <String>[];
    final oldKeys = <String>[];
    try {
      for (final row in parsed.tables['observation_session_images']!) {
        final key = const Uuid().v4();
        await _attachments.put(key, parsed.images[row['id']]!);
        staged.add(key);
        row['storage_key'] = key;
      }
      await _db.transaction(() async {
        if (mode == BackupRestoreMode.replace) {
          final existing = await _db
              .customSelect(
                'SELECT storage_key FROM observation_session_images',
              )
              .get();
          oldKeys.addAll(existing.map((r) => r.read<String>('storage_key')));
          for (final table in _deleteOrder) {
            await _db.customStatement('DELETE FROM $table');
          }
        }
        for (final table in backupTables) {
          final names = columns[table]!;
          final sql =
              'INSERT INTO $table (${names.join(', ')}) '
              'VALUES (${List.filled(names.length, '?').join(', ')})';
          for (final row in parsed.tables[table]!) {
            // Retain saved IDs and relationships; never use OR REPLACE.
            await _db.customStatement(sql, [
              for (final col in names)
                row[col] is bool ? ((row[col] as bool) ? 1 : 0) : row[col],
            ]);
          }
        }
        final problems = await _db
            .customSelect('PRAGMA foreign_key_check')
            .get();
        if (problems.isNotEmpty) {
          throw const FormatException('Backup contains broken references.');
        }
      });
    } catch (_) {
      for (final key in staged) {
        try {
          await _attachments.remove(key);
        } catch (_) {
          // The database transaction is rolled back even if cleanup fails.
        }
      }
      rethrow;
    }
    for (final key in oldKeys) {
      try {
        await _attachments.remove(key);
      } catch (_) {
        // Best-effort cleanup of detached files after successful commit.
      }
    }
  }
}

final astroBackupServiceProvider = Provider<AstroBackupService>((ref) {
  return AstroBackupService(ref.watch(appDatabaseProvider));
});
