import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'attachment_store.dart';

SessionAttachmentStore createStore() => _NativeSessionAttachmentStore();

final class _NativeSessionAttachmentStore implements SessionAttachmentStore {
  Future<File> _file(String key) async {
    if (!RegExp(r'^[a-zA-Z0-9-]{1,100}$').hasMatch(key)) {
      throw const FormatException('Invalid attachment storage key.');
    }
    final base = await getApplicationSupportDirectory();
    final folder = Directory(
      '${base.path}${Platform.pathSeparator}session_images',
    );
    await folder.create(recursive: true);
    return File('${folder.path}${Platform.pathSeparator}$key');
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    final file = await _file(key);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List> read(String key) async => (await _file(key)).readAsBytes();

  @override
  Future<void> remove(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }
}
