import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../models/store_models.dart';
import 'pack_asset_store.dart';

class PackageInstallException implements Exception {
  const PackageInstallException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Verifies and installs a downloaded ZIP package from Django into
/// [PackAssetStore] (IndexedDB on Web, private app directory on mobile/desktop).
class DeckPackageInstaller {
  DeckPackageInstaller({this.assetStore});

  final PackAssetStore? assetStore;

  PackAssetStore get _store => assetStore ?? PackAssetStore.instance;

  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  static bool _isSafeRelPath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.startsWith(r'\') ||
        path.contains('..') ||
        path.contains(r'\')) {
      return false;
    }
    return true;
  }

  /// Validates the archive size, SHA-256 digest, `deck_manifest.json` structure,
  /// and every asset checksum before saving files into [PackAssetStore].
  Future<InstalledPackRecord> verifyAndInstall({
    required StoreProduct product,
    required StoreDownloadInfo download,
    required Uint8List zipBytes,
  }) async {
    if (download.sizeBytes > 0 && zipBytes.length != download.sizeBytes) {
      throw PackageInstallException(
        'Package size mismatch (${zipBytes.length} != ${download.sizeBytes}).',
      );
    }
    if (download.sha256.isNotEmpty) {
      final actualSha = sha256Hex(zipBytes);
      if (actualSha != download.sha256.toLowerCase()) {
        throw const PackageInstallException('Package SHA-256 mismatch.');
      }
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const PackageInstallException('Invalid ZIP package.');
    }

    final entries = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (!_isSafeRelPath(name)) {
        throw PackageInstallException('Unsafe path inside package: $name');
      }
      final content = file.content;
      entries[name] = content;
    }

    final manifestBytes = entries['deck_manifest.json'];
    if (manifestBytes == null) {
      throw const PackageInstallException('Missing deck_manifest.json.');
    }

    final Map<String, dynamic> manifest;
    try {
      final decoded = jsonDecode(utf8.decode(manifestBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Manifest is not an object');
      }
      manifest = decoded;
    } catch (_) {
      throw const PackageInstallException('Invalid deck_manifest.json.');
    }

    if (manifest['schemaVersion'] != 1) {
      throw const PackageInstallException('Unsupported package schemaVersion.');
    }
    if (manifest['deckId'] != product.id) {
      throw const PackageInstallException('Manifest deckId mismatch.');
    }
    if (manifest['system'] != product.system.name) {
      throw const PackageInstallException('Manifest system mismatch.');
    }
    if (manifest['version'] != download.version) {
      throw const PackageInstallException('Manifest version mismatch.');
    }

    final verifiedFiles = <String, Uint8List>{};

    String verifyEntry(Object? rawAsset, String label) {
      if (rawAsset is! Map) {
        throw PackageInstallException('Invalid $label entry in manifest.');
      }
      final path = rawAsset['path'];
      final expectedSha = rawAsset['sha256'];
      if (path is! String ||
          !_isSafeRelPath(path) ||
          expectedSha is! String ||
          expectedSha.length != 64) {
        throw PackageInstallException('Malformed $label metadata in manifest.');
      }
      final bytes = entries[path];
      if (bytes == null) {
        throw PackageInstallException('Missing $label file: $path');
      }
      if (sha256Hex(bytes) != expectedSha.toLowerCase()) {
        throw PackageInstallException('Checksum mismatch for $path.');
      }
      verifiedFiles[path] = bytes;
      return path;
    }

    final coverPath = verifyEntry(manifest['cover'], 'cover');
    String? backPath;
    if (manifest.containsKey('back') && manifest['back'] != null) {
      backPath = verifyEntry(manifest['back'], 'back');
    }

    final cardPaths = <int, String>{};
    final rawCards = manifest['cards'];
    if (rawCards is Map) {
      for (final entry in rawCards.entries) {
        final key = entry.key.toString();
        final parts = key.split(':');
        if (parts.length != 2 || parts[0] != product.system.name) {
          throw PackageInstallException('Invalid card key: $key');
        }
        final cardId = int.tryParse(parts[1]);
        if (cardId == null) {
          throw PackageInstallException('Invalid numeric card ID: $key');
        }
        cardPaths[cardId] = verifyEntry(entry.value, key);
      }
    }

    final stonePaths = <String>[];
    final rawStones = manifest['stones'];
    if (rawStones is List) {
      for (var i = 0; i < rawStones.length; i++) {
        stonePaths.add(verifyEntry(rawStones[i], 'stone[$i]'));
      }
    }

    if (cardPaths.isEmpty && stonePaths.isEmpty) {
      throw const PackageInstallException(
        'Package contains neither cards nor rune stone sprites.',
      );
    }

    final style = <String, dynamic>{
      ...product.visualConfig,
      if (manifest['style'] is Map)
        ...Map<String, dynamic>.from(manifest['style'] as Map),
    };

    final storeKey = '${product.system.name}/${product.slug}/${download.version}';
    await _store.savePackFiles(storeKey, verifiedFiles);

    return InstalledPackRecord(
      deckId: product.id,
      slug: product.slug,
      system: product.system,
      version: download.version,
      storeKey: storeKey,
      title: product.title,
      tagline: product.tagline.isNotEmpty ? product.tagline : product.description,
      license: product.license,
      cardPaths: cardPaths,
      stonePaths: stonePaths,
      backPath: backPath,
      coverPath: coverPath,
      style: style,
    );
  }

  Future<void> uninstall(InstalledPackRecord record) async {
    await _store.deletePack(record.storeKey);
  }
}
