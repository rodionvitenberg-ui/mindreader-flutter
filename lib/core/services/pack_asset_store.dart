import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'pack_asset_store_stub.dart'
    if (dart.library.io) 'pack_asset_store_io.dart'
    if (dart.library.js_interop) 'pack_asset_store_web.dart';

/// Cross-platform private storage for downloaded store pack assets:
/// - Android/iOS/Desktop: `<ApplicationSupportDirectory>/store_packs/<storeKey>/...`
/// - Flutter Web: IndexedDB (`tarot_tree_store_packs`) hydrated into an in-memory cache
///   so `ImageProvider` (`MemoryImage`) works synchronously & offline across reloads.
abstract class PackAssetStore {
  static PackAssetStore _instance = createPlatformPackAssetStore();

  static PackAssetStore get instance => _instance;

  @visibleForTesting
  static void setForTesting(PackAssetStore store) {
    _instance = store;
  }

  /// Persists all extracted files (`relPath -> bytes`) under [storeKey].
  Future<void> savePackFiles(String storeKey, Map<String, Uint8List> files);

  /// Warms/hydrates files for [storeKey] so [imageProviderFor] can resolve synchronously.
  Future<void> hydratePack(String storeKey);

  /// Removes all locally cached files for [storeKey].
  Future<void> deletePack(String storeKey);

  /// Synchronous [ImageProvider] for a downloaded asset, or `null` if unavailable.
  ImageProvider<Object>? imageProviderFor(String storeKey, String relPath);

  /// Asynchronous byte read for GPU image decoding (e.g. volumetric 3D rune sprites).
  Future<Uint8List?> readBytes(String storeKey, String relPath);
}

/// Pure in-memory implementation used by tests and fallback platforms.
class InMemoryPackAssetStore implements PackAssetStore {
  final Map<String, Map<String, Uint8List>> _packs = {};

  @override
  Future<void> savePackFiles(
    String storeKey,
    Map<String, Uint8List> files,
  ) async {
    _packs[storeKey] = {
      for (final entry in files.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
  }

  @override
  Future<void> hydratePack(String storeKey) async {}

  @override
  Future<void> deletePack(String storeKey) async {
    _packs.remove(storeKey);
  }

  @override
  ImageProvider<Object>? imageProviderFor(String storeKey, String relPath) {
    final bytes = _packs[storeKey]?[relPath];
    if (bytes == null || bytes.isEmpty) return null;
    return MemoryImage(bytes);
  }

  @override
  Future<Uint8List?> readBytes(String storeKey, String relPath) async {
    return _packs[storeKey]?[relPath];
  }
}
