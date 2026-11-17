/// One selectable 3D rune stone set: procedural rock identity (palettes as
/// ARGB ints so the model stays Flutter-free) + optional stone textures.
/// Custom textures may be dropped into `assets/runes/<id>/<rune_id>.png`
/// (or `<rune_id>_back.png`) — the procedural obsidian shader renders when
/// assets are absent.
class RunePack {
  const RunePack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.assetFolder,
    required this.license,
    required this.stoneBaseArgb,
    required this.stoneDarkArgb,
    required this.stoneRimArgb,
    required this.glyphArgb,
    required this.glowArgb,
    required this.specularArgb,
  });

  final String id;
  final String name;
  final String subtitle;
  final String assetFolder; // assets/runes/<id>/
  final String license;

  /// Radial rock-shader center → edge colors.
  final int stoneBaseArgb;
  final int stoneDarkArgb;

  /// Chiseled edge highlight (specular glint) color.
  final int stoneRimArgb;

  /// Engraved rune glyph color.
  final int glyphArgb;

  /// Ignition glow behind the glyph when a cast stone is tapped.
  final int glowArgb;

  /// Moving specular glint sweep color.
  final int specularArgb;

  /// Candidate texture paths for rune [id] (0..23); null → procedural.
  List<String> stoneAssetCandidates(int runeId) => [
        '$assetFolder$runeId.png',
        '$assetFolder$runeId.jpg',
      ];
}
