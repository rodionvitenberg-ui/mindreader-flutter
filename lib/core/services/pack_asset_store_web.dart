import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'pack_asset_store.dart';

PackAssetStore createPlatformPackAssetStore() => WebPackAssetStore();

/// IndexedDB-backed pack asset store for Flutter Web.
///
/// Stores extracted pack files persistently in IndexedDB (`tarot_tree_store_packs`)
/// and hydrates them into an in-memory map on startup/install so `MemoryImage`
/// renders synchronously and offline across browser reloads.
class WebPackAssetStore implements PackAssetStore {
  static const _dbName = 'tarot_tree_store_packs';
  static const _storeName = 'files';

  final Map<String, Map<String, Uint8List>> _cache = {};
  Future<web.IDBDatabase?>? _dbFuture;

  Future<web.IDBDatabase?> _openDb() {
    return _dbFuture ??= _initDb();
  }

  Future<web.IDBDatabase?> _initDb() async {
    try {
      final completer = Completer<web.IDBDatabase?>();
      final req = web.window.indexedDB.open(_dbName, 1);
      req.onupgradeneeded = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }).toJS;
      req.onsuccess = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.complete(req.result as web.IDBDatabase);
        }
      }).toJS;
      req.onerror = ((web.Event _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  String _compoundKey(String storeKey, String relPath) => '$storeKey::$relPath';

  @override
  Future<void> savePackFiles(
    String storeKey,
    Map<String, Uint8List> files,
  ) async {
    final copy = <String, Uint8List>{
      for (final entry in files.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
    _cache[storeKey] = copy;

    final db = await _openDb();
    if (db == null) return;
    try {
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);
      for (final entry in copy.entries) {
        store.put(
          entry.value.toJS,
          _compoundKey(storeKey, entry.key).toJS,
        );
      }
      await _waitTx(tx);
    } catch (_) {
      // In-memory cache still serves the current browser session.
    }
  }

  @override
  Future<void> hydratePack(String storeKey) async {
    if (_cache.containsKey(storeKey)) return;
    final db = await _openDb();
    if (db == null) return;
    final prefix = '$storeKey::';
    final loaded = <String, Uint8List>{};
    try {
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final req = store.openCursor();
      final completer = Completer<void>();
      req.onsuccess = ((web.Event _) {
        final cursor = req.result as web.IDBCursorWithValue?;
        if (cursor == null) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        final key = (cursor.key as JSString).toDart;
        if (key.startsWith(prefix)) {
          final val = cursor.value as JSUint8Array?;
          if (val != null) {
            loaded[key.substring(prefix.length)] = val.toDart;
          }
        }
        cursor.continue_();
      }).toJS;
      req.onerror = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      await completer.future;
      if (loaded.isNotEmpty) {
        _cache[storeKey] = loaded;
      }
    } catch (_) {
      // Ignore IndexedDB cursor errors.
    }
  }

  @override
  Future<void> deletePack(String storeKey) async {
    _cache.remove(storeKey);
    final db = await _openDb();
    if (db == null) return;
    final prefix = '$storeKey::';
    try {
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);
      final req = store.openCursor();
      final completer = Completer<void>();
      req.onsuccess = ((web.Event _) {
        final cursor = req.result as web.IDBCursorWithValue?;
        if (cursor == null) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        final key = (cursor.key as JSString).toDart;
        if (key.startsWith(prefix)) {
          cursor.delete();
        }
        cursor.continue_();
      }).toJS;
      req.onerror = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      await completer.future;
      await _waitTx(tx);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  @override
  ImageProvider<Object>? imageProviderFor(String storeKey, String relPath) {
    final bytes = _cache[storeKey]?[relPath];
    if (bytes == null || bytes.isEmpty) return null;
    return MemoryImage(bytes);
  }

  @override
  Future<Uint8List?> readBytes(String storeKey, String relPath) async {
    if (!_cache.containsKey(storeKey)) {
      await hydratePack(storeKey);
    }
    return _cache[storeKey]?[relPath];
  }

  Future<void> _waitTx(web.IDBTransaction tx) {
    final completer = Completer<void>();
    tx.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    tx.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    return completer.future;
  }
}
