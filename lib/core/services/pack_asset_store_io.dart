import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'pack_asset_store.dart';

PackAssetStore createPlatformPackAssetStore() => IoPackAssetStore();

/// Filesystem-backed pack asset store for Android, iOS, and desktop platforms.
class IoPackAssetStore implements PackAssetStore {
  Directory? _rootDir;
  final Map<String, String> _hydratedDirs = {};

  Future<Directory> _ensureRoot() async {
    if (_rootDir != null) return _rootDir!;
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}${Platform.pathSeparator}store_packs');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _rootDir = root;
    return root;
  }

  String _safeKey(String storeKey) =>
      storeKey.replaceAll(RegExp(r'[^A-Za-z0-9._/-]'), '_');

  Future<Directory> _packDir(String storeKey) async {
    final root = await _ensureRoot();
    final safe = _safeKey(storeKey);
    return Directory(
      '${root.path}${Platform.pathSeparator}${safe.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  @override
  Future<void> savePackFiles(
    String storeKey,
    Map<String, Uint8List> files,
  ) async {
    final dir = await _packDir(storeKey);
    final tmp = Directory('${dir.path}.tmp');
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
    await tmp.create(recursive: true);
    for (final entry in files.entries) {
      final target = File(
        '${tmp.path}${Platform.pathSeparator}${entry.key.replaceAll('/', Platform.pathSeparator)}',
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
    }
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.parent.create(recursive: true);
    await tmp.rename(dir.path);
    _hydratedDirs[storeKey] = dir.path;
  }

  @override
  Future<void> hydratePack(String storeKey) async {
    final dir = await _packDir(storeKey);
    if (await dir.exists()) {
      _hydratedDirs[storeKey] = dir.path;
    }
  }

  @override
  Future<void> deletePack(String storeKey) async {
    _hydratedDirs.remove(storeKey);
    final dir = await _packDir(storeKey);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  ImageProvider<Object>? imageProviderFor(String storeKey, String relPath) {
    final dirPath = _hydratedDirs[storeKey];
    if (dirPath == null) return null;
    final file = File(
      '$dirPath${Platform.pathSeparator}${relPath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  @override
  Future<Uint8List?> readBytes(String storeKey, String relPath) async {
    final dirPath = _hydratedDirs[storeKey] ?? (await _packDir(storeKey)).path;
    final file = File(
      '$dirPath${Platform.pathSeparator}${relPath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!await file.exists()) return null;
    _hydratedDirs[storeKey] = dirPath;
    return file.readAsBytes();
  }
}
