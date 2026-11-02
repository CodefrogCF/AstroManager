/* Image data lives in its own IndexedDB object store, never in SQLite. */
(function () {
  'use strict';
  const DB_NAME = 'astromanager-session-attachments';
  function open() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => req.result.createObjectStore('images');
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }
  async function operation(mode, action) {
    const db = await open();
    try {
      return await new Promise((resolve, reject) => {
        const tx = db.transaction('images', mode);
        const request = action(tx.objectStore('images'));
        let value;
        request.onsuccess = () => { value = request.result; };
        tx.oncomplete = () => resolve(value);
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error);
      });
    } finally {
      db.close();
    }
  }
  window.astroSessionAttachments = Object.freeze({
    put(key, bytes) {
      return operation('readwrite', store => store.put(bytes, key));
    },
    async read(key) {
      const bytes = await operation('readonly', store => store.get(key));
      if (!bytes) throw new Error('Attachment not found: ' + key);
      return new Uint8Array(bytes);
    },
    remove(key) {
      return operation('readwrite', store => store.delete(key));
    },
  });
}());
