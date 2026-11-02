import 'dart:js_interop';
import 'dart:typed_data';

import 'attachment_store.dart';

@JS('astroSessionAttachments.put')
external JSPromise<JSAny?> _put(JSString key, JSUint8Array bytes);

@JS('astroSessionAttachments.read')
external JSPromise<JSUint8Array> _read(JSString key);

@JS('astroSessionAttachments.remove')
external JSPromise<JSAny?> _remove(JSString key);

SessionAttachmentStore createStore() => _WebSessionAttachmentStore();

final class _WebSessionAttachmentStore implements SessionAttachmentStore {
  @override
  Future<void> put(String key, Uint8List bytes) async {
    await _put(key.toJS, bytes.toJS).toDart;
  }

  @override
  Future<Uint8List> read(String key) async =>
      (await _read(key.toJS).toDart).toDart;

  @override
  Future<void> remove(String key) async {
    await _remove(key.toJS).toDart;
  }
}
