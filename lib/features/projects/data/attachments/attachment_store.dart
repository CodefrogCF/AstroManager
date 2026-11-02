import 'dart:typed_data';

import 'attachment_store_native.dart'
    if (dart.library.js_interop) 'attachment_store_web.dart'
    as platform;

/// Detached binary storage. SQLite only stores opaque storage keys and names.
abstract interface class SessionAttachmentStore {
  Future<void> put(String key, Uint8List bytes);
  Future<Uint8List> read(String key);
  Future<void> remove(String key);
}

SessionAttachmentStore createSessionAttachmentStore() => platform.createStore();
