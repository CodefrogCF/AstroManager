import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../domain/observation_session.dart';
import 'attachments/attachment_store.dart';

abstract interface class ObservationSessionsRepository {
  Future<List<ObservationSession>> forProject(String projectId);
  Future<void> save(ObservationSession session);
  Future<void> remove(String sessionId);
  Future<List<SessionImageAttachment>> images(String sessionId);
  Future<SessionImageAttachment> addImage(
    String sessionId,
    String fileName,
    Uint8List bytes,
  );
  Future<Uint8List> readImage(SessionImageAttachment attachment);
  Future<void> removeImage(SessionImageAttachment attachment);
}

final class DriftObservationSessionsRepository
    implements ObservationSessionsRepository {
  DriftObservationSessionsRepository(
    this._db, {
    SessionAttachmentStore? attachments,
  }) : _attachments = attachments ?? createSessionAttachmentStore();

  final AppDatabase _db;
  final SessionAttachmentStore _attachments;

  @override
  Future<List<ObservationSession>> forProject(String projectId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM observation_sessions
      WHERE project_id = ? ORDER BY started_at_utc DESC, id
    ''',
          variables: [Variable<String>(projectId)],
        )
        .get();
    return List.unmodifiable(
      rows.map(
        (row) => ObservationSession(
          id: row.read<String>('id'),
          projectId: row.read<String>('project_id'),
          startedAtUtc: DateTime.parse(row.read<String>('started_at_utc'))
              .toUtc(),
          endedAtUtc: _date(row.readNullable<String>('ended_at_utc')),
          timeZoneId: row.read<String>('time_zone_id'),
          utcOffsetMinutes: row.read<int>('utc_offset_minutes'),
          locationId: row.readNullable<String>('location_id'),
          locationName: row.readNullable<String>('location_name'),
          cameraId: row.readNullable<String>('camera_id'),
          cameraName: row.readNullable<String>('camera_name'),
          opticId: row.readNullable<String>('optic_id'),
          opticName: row.readNullable<String>('optic_name'),
          mountId: row.readNullable<String>('mount_id'),
          mountName: row.readNullable<String>('mount_name'),
          exposureSeconds: row.read<double>('exposure_seconds'),
          frameCount: row.read<int>('frame_count'),
          acceptedFrames: row.read<int>('accepted_frames'),
          rejectedFrames: row.read<int>('rejected_frames'),
          iso: row.readNullable<int>('iso'),
          gain: row.readNullable<double>('gain'),
          apertureFNumber: row.readNullable<double>('aperture_f_number'),
          binning: row.read<int>('binning'),
          filterName: row.read<String>('filter_name'),
          sensorTemperatureC: row.readNullable<double>('sensor_temperature_c'),
          notes: row.read<String>('notes'),
        ),
      ),
    );
  }

  DateTime? _date(String? value) =>
      value == null ? null : DateTime.parse(value).toUtc();

  @override
  Future<void> save(ObservationSession session) async {
    session.validate();
    await _db.customStatement(
      '''
      INSERT INTO observation_sessions (
        id, project_id, started_at_utc, ended_at_utc, time_zone_id,
        utc_offset_minutes, location_id, location_name, camera_id, camera_name,
        optic_id, optic_name, mount_id, mount_name, exposure_seconds,
        frame_count, accepted_frames, rejected_frames, iso, gain,
        aperture_f_number, binning, filter_name, sensor_temperature_c, notes
      ) VALUES (${List.filled(25, '?').join(',')})
      ON CONFLICT(id) DO UPDATE SET
        project_id=excluded.project_id,
        started_at_utc=excluded.started_at_utc,
        ended_at_utc=excluded.ended_at_utc,
        time_zone_id=excluded.time_zone_id,
        utc_offset_minutes=excluded.utc_offset_minutes,
        location_id=excluded.location_id,
        location_name=excluded.location_name,
        camera_id=excluded.camera_id,
        camera_name=excluded.camera_name,
        optic_id=excluded.optic_id,
        optic_name=excluded.optic_name,
        mount_id=excluded.mount_id,
        mount_name=excluded.mount_name,
        exposure_seconds=excluded.exposure_seconds,
        frame_count=excluded.frame_count,
        accepted_frames=excluded.accepted_frames,
        rejected_frames=excluded.rejected_frames,
        iso=excluded.iso,
        gain=excluded.gain,
        aperture_f_number=excluded.aperture_f_number,
        binning=excluded.binning,
        filter_name=excluded.filter_name,
        sensor_temperature_c=excluded.sensor_temperature_c,
        notes=excluded.notes
    ''',
      [
        session.id,
        session.projectId,
        session.startedAtUtc.toIso8601String(),
        session.endedAtUtc?.toIso8601String(),
        session.timeZoneId,
        session.utcOffsetMinutes,
        session.locationId,
        session.locationName,
        session.cameraId,
        session.cameraName,
        session.opticId,
        session.opticName,
        session.mountId,
        session.mountName,
        session.exposureSeconds,
        session.frameCount,
        session.acceptedFrames,
        session.rejectedFrames,
        session.iso,
        session.gain,
        session.apertureFNumber,
        session.binning,
        session.filterName,
        session.sensorTemperatureC,
        session.notes,
      ],
    );
  }

  @override
  Future<void> remove(String sessionId) async {
    final attached = await images(sessionId);
    await _db.customStatement('DELETE FROM observation_sessions WHERE id = ?', [
      sessionId,
    ]);
    for (final image in attached) {
      await _attachments.remove(image.storageKey);
    }
  }

  @override
  Future<List<SessionImageAttachment>> images(String sessionId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM observation_session_images WHERE session_id = ?
      ORDER BY created_at_utc, id
    ''',
          variables: [Variable<String>(sessionId)],
        )
        .get();
    return List.unmodifiable(
      rows.map(
        (row) => SessionImageAttachment(
          id: row.read<String>('id'),
          sessionId: row.read<String>('session_id'),
          fileName: row.read<String>('file_name'),
          storageKey: row.read<String>('storage_key'),
          byteLength: row.read<int>('byte_length'),
          createdAtUtc: DateTime.parse(row.read<String>('created_at_utc'))
              .toUtc(),
        ),
      ),
    );
  }

  @override
  Future<SessionImageAttachment> addImage(
    String sessionId,
    String fileName,
    Uint8List bytes,
  ) async {
    if (sessionId.trim().isEmpty ||
        fileName.trim().isEmpty ||
        fileName.length > 255 ||
        bytes.isEmpty ||
        bytes.length > 20 * 1024 * 1024 ||
        !RegExp(
          r'\.(jpe?g|png|webp|gif|heic)$',
          caseSensitive: false,
        ).hasMatch(fileName)) {
      throw const FormatException('Choose a supported image (up to 20 MB).');
    }
    final id = const Uuid().v4();
    final image = SessionImageAttachment(
      id: id,
      sessionId: sessionId,
      fileName: fileName,
      storageKey: id,
      byteLength: bytes.length,
      createdAtUtc: DateTime.now().toUtc(),
    );
    await _attachments.put(id, bytes);
    try {
      await _db.customStatement(
        '''
        INSERT INTO observation_session_images
        (id, session_id, file_name, storage_key, byte_length, created_at_utc)
        VALUES (?, ?, ?, ?, ?, ?)
      ''',
        [
          id,
          sessionId,
          fileName,
          id,
          bytes.length,
          image.createdAtUtc.toIso8601String(),
        ],
      );
    } catch (_) {
      await _attachments.remove(id);
      rethrow;
    }
    return image;
  }

  @override
  Future<Uint8List> readImage(SessionImageAttachment attachment) =>
      _attachments.read(attachment.storageKey);

  @override
  Future<void> removeImage(SessionImageAttachment attachment) async {
    await _db.customStatement(
      'DELETE FROM observation_session_images WHERE id = ? AND session_id = ?',
      [attachment.id, attachment.sessionId],
    );
    await _attachments.remove(attachment.storageKey);
  }
}

final observationSessionsRepositoryProvider =
    Provider<ObservationSessionsRepository>(
      (ref) =>
          DriftObservationSessionsRepository(ref.watch(appDatabaseProvider)),
    );

final observationSessionsForProjectProvider =
    FutureProvider.family<List<ObservationSession>, String>(
      (ref, projectId) => ref
          .watch(observationSessionsRepositoryProvider)
          .forProject(projectId),
      retry: (count, error) => null,
    );

final observationSessionImagesProvider =
    FutureProvider.family<List<SessionImageAttachment>, String>(
      (ref, sessionId) =>
          ref.watch(observationSessionsRepositoryProvider).images(sessionId),
      retry: (count, error) => null,
    );
