import '../l10n/app_strings.dart';
import 'deck_pack.dart';

/// One selectable 3D rune stone set: volumetric blank stone sprites
/// (`assets/runes/<id>/stone_<0..N-1>.webp` for built-in sets, or extracted
/// files in `PackAssetStore` for store sets) paired with procedural carved-groove
/// palettes (stored as ARGB ints so the model stays Flutter-free).
class RunePack extends DeckPack {
  const RunePack({
    required this.id,
    required this.name,
    this.subtitleKey = '',
    this.rawSubtitle,
    required this.assetFolder,
    this.licenseKey = '',
    this.rawLicense,
    required this.stoneBaseArgb,
    required this.stoneDarkArgb,
    required this.stoneRimArgb,
    required this.glyphArgb,
    required this.glowArgb,
    required this.specularArgb,
    this.carveShadowArgb = 0xCC06060A,
    this.stoneVariantCount = 5,
    this.storeKey,
    this.storeCoverPath,
    this.storeStonePaths,
  });

  @override
  final String id;
  @override
  final String name;
  final String subtitleKey;
  final String? rawSubtitle;

  @override
  String get subtitle =>
      rawSubtitle ?? (subtitleKey.isEmpty ? '' : AppStrings.g(subtitleKey));

  final String assetFolder; // assets/runes/<id>/
  final String licenseKey;
  final String? rawLicense;

  @override
  String get license =>
      rawLicense ?? (licenseKey.isEmpty ? '' : AppStrings.g(licenseKey));

  /// Radial rock-shader center → edge colors (procedural 3D fallback).
  final int stoneBaseArgb;
  final int stoneDarkArgb;

  /// Chiseled edge highlight & lower carved-groove rim catch-light.
  final int stoneRimArgb;

  /// Engraved rune glyph foreground color.
  final int glyphArgb;

  /// Ignition glow behind the glyph when a cast stone is tapped.
  final int glowArgb;

  /// Specular glint sweep color.
  final int specularArgb;

  /// Recessed upper-left chisel shadow inside the carved rune channel.
  final int carveShadowArgb;

  /// Number of distinct blank 3D stone silhouettes shipped in this set.
  final int stoneVariantCount;

  @override
  final String? storeKey;
  @override
  final String? storeCoverPath;

  /// For store-downloaded rune sets: ordered relative paths (e.g. `stones/stone_0.webp`).
  final List<String>? storeStonePaths;

  /// Deterministic silhouette variant index (`0..stoneVariantCount-1`) for
  /// Elder Futhark rune [stoneId], distributing shapes evenly across the 24 stones.
  int variantIndexFor(int stoneId) {
    final count = storeStonePaths != null && storeStonePaths!.isNotEmpty
        ? storeStonePaths!.length
        : stoneVariantCount;
    if (count <= 1) return 0;
    return (stoneId * 7 + 3).abs() % count;
  }

  /// Path to blank 3D stone sprite variant [variantIndex] (asset path or relative
  /// store path when [isStorePack] is true).
  String stoneBlankAsset(int variantIndex) {
    final storePaths = storeStonePaths;
    if (storePaths != null && storePaths.isNotEmpty) {
      return storePaths[variantIndex.abs() % storePaths.length];
    }
    final idx = stoneVariantCount <= 0
        ? 0
        : variantIndex.abs() % stoneVariantCount;
    return '${assetFolder}stone_$idx.webp';
  }

  /// Candidate per-rune texture paths for optional full-stone overrides.
  List<String> stoneAssetCandidates(int runeId) => isStorePack
      ? const []
      : ['$assetFolder$runeId.png', '$assetFolder$runeId.jpg'];
}
