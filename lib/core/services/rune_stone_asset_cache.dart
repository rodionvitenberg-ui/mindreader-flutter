import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/rune_pack.dart';
import 'pack_asset_store.dart';

/// Asynchronous, deduplicated GPU image cache for volumetric 3D rune stone
/// blank sprites — supports both bundled assets (`assets/runes/<id>/stone_0..4.webp`)
/// and store-downloaded rune sets stored in [PackAssetStore].
class RuneStoneAssetCache extends ChangeNotifier {
  RuneStoneAssetCache._();

  static final RuneStoneAssetCache instance = RuneStoneAssetCache._();

  final Map<String, ui.Image> _images = {};
  final Set<String> _inFlight = {};
  final Set<String> _missing = {};

  String _cacheKey(RunePack pack, int variantIndex) {
    final path = pack.stoneBlankAsset(variantIndex);
    return pack.isStorePack ? 'store:${pack.storeKey}:$path' : path;
  }

  /// Returns the decoded [ui.Image] for [pack] and [variantIndex], or `null`
  /// while loading (triggering a single background load) or if unavailable.
  ui.Image? imageFor(RunePack pack, int variantIndex) {
    final key = _cacheKey(pack, variantIndex);
    final cached = _images[key];
    if (cached != null) return cached;
    if (!_missing.contains(key) && !_inFlight.contains(key)) {
      unawaited(_load(pack, variantIndex));
    }
    return null;
  }

  /// Pre-decodes every blank stone variant of [pack] so the first frame of a
  /// rune spread or Almanac screen paints textured 3D stones immediately.
  Future<void> warmPack(RunePack pack) async {
    final count = pack.storeStonePaths?.length ?? pack.stoneVariantCount;
    await Future.wait([
      for (var i = 0; i < count; i++) _load(pack, i),
    ]);
  }

  Future<void> _load(RunePack pack, int variantIndex) async {
    final key = _cacheKey(pack, variantIndex);
    if (_images.containsKey(key) ||
        _missing.contains(key) ||
        _inFlight.contains(key)) {
      return;
    }
    _inFlight.add(key);
    try {
      final path = pack.stoneBlankAsset(variantIndex);
      final Uint8List? bytes;
      if (pack.isStorePack) {
        bytes = await PackAssetStore.instance.readBytes(pack.storeKey!, path);
      } else {
        final data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      }
      if (bytes == null || bytes.isEmpty) {
        _missing.add(key);
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[key] = frame.image;
      notifyListeners();
    } catch (_) {
      _missing.add(key);
    } finally {
      _inFlight.remove(key);
    }
  }

  @visibleForTesting
  void clearForTest() {
    _images.clear();
    _inFlight.clear();
    _missing.clear();
  }
}
