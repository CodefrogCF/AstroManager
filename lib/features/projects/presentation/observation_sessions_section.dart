import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/observation_sessions_repository.dart';
import '../domain/observation_session.dart';
import 'observation_session_editor_dialog.dart';

/// Project-scoped session history, with editable exposure logs and optional
/// image attachments. All writes invalidate repository-backed providers.
class ObservationSessionsSection extends ConsumerStatefulWidget {
  const ObservationSessionsSection({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ObservationSessionsSection> createState() =>
      _ObservationSessionsSectionState();
}

class _ObservationSessionsSectionState
    extends ConsumerState<ObservationSessionsSection> {
  bool _busy = false;

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session operation failed: $error')),
      );
    }
  }

  Future<void> _edit([ObservationSession? current]) async {
    final changed = await showDialog<ObservationSession>(
      context: context,
      builder: (context) => ObservationSessionEditorDialog(
        projectId: widget.projectId,
        session: current,
      ),
    );
    if (changed == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(observationSessionsRepositoryProvider).save(changed);
      if (!mounted) return;
      ref.invalidate(observationSessionsForProjectProvider(widget.projectId));
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ObservationSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete observation session?'),
        content: const Text(
          'The session and its attached images will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('session-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(observationSessionsRepositoryProvider).remove(session.id);
      if (!mounted) return;
      ref.invalidate(observationSessionsForProjectProvider(widget.projectId));
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(ObservationSession session) async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null || !mounted) return;

      const maxAttachmentBytes = 20 * 1024 * 1024;
      // Check known sizes before reading to avoid loading oversized images.
      final length = file.lengthSync() ?? await file.length();
      if (length != null && length > maxAttachmentBytes) {
        throw const FormatException('Maximum attachment size is 20 MB.');
      }
      final bytes = await file.readAsBytes();
      // Some providers cannot report the file size in advance.
      if (bytes.lengthInBytes > maxAttachmentBytes) {
        throw const FormatException('Maximum attachment size is 20 MB.');
      }
      if (!mounted) return;
      await ref
          .read(observationSessionsRepositoryProvider)
          .addImage(session.id, file.name, bytes);
      if (!mounted) return;
      ref.invalidate(observationSessionImagesProvider(session.id));
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _show(SessionImageAttachment image) async {
    final future = ref
        .read(observationSessionsRepositoryProvider)
        .readImage(image);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(image.fileName),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
          child: FutureBuilder<Uint8List>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Unable to open image: ${snapshot.error}');
              }
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return Image.memory(snapshot.data!, fit: BoxFit.contain);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeImage(SessionImageAttachment image) async {
    try {
      await ref.read(observationSessionsRepositoryProvider).removeImage(image);
      if (!mounted) return;
      ref.invalidate(observationSessionImagesProvider(image.sessionId));
    } catch (error) {
      _error(error);
    }
  }

  String _date(ObservationSession session) {
    final local = tz.TZDateTime.from(
      session.startedAtUtc,
      ObservationSession.zone(session.timeZoneId),
    );
    String two(int n) => n.toString().padLeft(2, '0');
    final sign = session.utcOffsetMinutes < 0 ? '-' : '+';
    final offset = session.utcOffsetMinutes.abs();
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)} ${session.timeZoneId} '
        '(UTC$sign${two(offset ~/ 60)}:${two(offset % 60)})';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(
      observationSessionsForProjectProvider(widget.projectId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Observation sessions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('session-add'),
              onPressed: _busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add session'),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        switch (sessions) {
          AsyncData(value: final data) =>
            data.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No observation sessions recorded yet.'),
                  )
                : Column(
                    children: [
                      for (final session in data) _sessionCard(session),
                    ],
                  ),
          AsyncError(:final error) => Text('Unable to load sessions: $error'),
          _ => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }

  Widget _sessionCard(ObservationSession session) {
    final images = ref.watch(observationSessionImagesProvider(session.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _date(session),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Exposure: ${session.exposureSeconds}s × ${session.frameCount} '
              '(accepted ${session.acceptedFrames}, rejected ${session.rejectedFrames})',
            ),
            Text(
              'Accepted integration: ${session.acceptedIntegrationSeconds}s',
            ),
            Text('Location: ${session.locationName ?? 'Not recorded'}'),
            Text(
              'Camera: ${session.cameraName ?? 'Not recorded'} · '
              'Optics: ${session.opticName ?? 'Not recorded'} · '
              'Mount: ${session.mountName ?? 'Not recorded'}',
            ),
            Text(
              'ISO: ${session.iso ?? '—'} · Gain: ${session.gain ?? '—'} · '
              'Aperture: ${session.apertureFNumber ?? '—'} · Bin: ${session.binning}',
            ),
            if (session.filterName.isNotEmpty)
              Text('Filter: ${session.filterName}'),
            if (session.sensorTemperatureC != null)
              Text('Sensor: ${session.sensorTemperatureC}°C'),
            if (session.notes.isNotEmpty) Text(session.notes),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('session-edit-${session.id}'),
                  onPressed: _busy ? null : () => _edit(session),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  key: ValueKey('session-attach-${session.id}'),
                  onPressed: _busy ? null : () => _attach(session),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Attach image'),
                ),
                TextButton.icon(
                  key: ValueKey('session-delete-${session.id}'),
                  onPressed: _busy ? null : () => _remove(session),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
            switch (images) {
              AsyncData(value: final data) => Wrap(
                spacing: 6,
                children: [
                  for (final image in data)
                    InputChip(
                      label: Text(image.fileName),
                      onPressed: () => _show(image),
                      onDeleted: () => _removeImage(image),
                    ),
                ],
              ),
              AsyncError(:final error) => Text('Images unavailable: $error'),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}
