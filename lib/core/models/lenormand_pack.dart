import 'tarot_deck_pack.dart';

/// One selectable Petit Lenormand pack: asset location + procedural
/// identity (palettes as ARGB ints so the model stays Flutter-free).
/// Cards may be dropped into `assets/lenormand/<id>/01.jpg..36.jpg` —
/// the renderer falls back to the procedural face when assets are absent.
class LenormandPack {
  const LenormandPack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.assetFolder,
    required this.license,
    required this.backStyle,
    required this.backAccentArgb,
    required this.backSecondaryArgb,
    required this.faceAccentArgb,
    required this.faceSecondaryArgb,
    required this.faceBackgroundArgb,
  });

  final String id;
  final String name;
  final String subtitle;

  /// e.g. `assets/lenormand/antique_petit/` — 01.jpg..36.jpg (Rider..Cross).
  final String assetFolder;

  final String license;
  final CardBackStyle backStyle;
  final int backAccentArgb;
  final int backSecondaryArgb;
  final int faceAccentArgb;
  final int faceSecondaryArgb;

  /// Card-face background color of the procedural renderer.
  final int faceBackgroundArgb;

  /// Ordered candidate asset paths for card [number] (1..36) — the first
  /// path that loads wins; the procedural face renders when none exist.
  List<String> cardAssetCandidates(int number) {
    final n2 = number.toString().padLeft(2, '0');
    return [
      '$assetFolder$n2.jpg',
      '$assetFolder$n2.png',
      '$assetFolder$number.jpg',
      '$assetFolder$number.png',
    ];
  }
}
