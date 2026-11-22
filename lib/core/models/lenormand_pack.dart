import '../l10n/app_strings.dart';
import 'deck_pack.dart';
import 'tarot_deck_pack.dart';

/// One selectable Petit Lenormand pack: asset location (bundled or downloaded)
/// + procedural identity (palettes as ARGB ints so the model stays Flutter-free).
class LenormandPack extends DeckPack {
  const LenormandPack({
    required this.id,
    required this.name,
    this.subtitleKey = '',
    this.rawSubtitle,
    required this.assetFolder,
    this.licenseKey = '',
    this.rawLicense,
    required this.backStyle,
    required this.backAccentArgb,
    required this.backSecondaryArgb,
    required this.faceAccentArgb,
    required this.faceSecondaryArgb,
    required this.faceBackgroundArgb,
    this.storeKey,
    this.storeCoverPath,
    this.storeCardPaths,
    this.storeBackPath,
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

  /// e.g. `assets/lenormand/antique_petit/` — 01.jpg..36.jpg (Rider..Cross).
  final String assetFolder;

  final String licenseKey;
  final String? rawLicense;

  @override
  String get license =>
      rawLicense ?? (licenseKey.isEmpty ? '' : AppStrings.g(licenseKey));

  final CardBackStyle backStyle;
  final int backAccentArgb;
  final int backSecondaryArgb;
  final int faceAccentArgb;
  final int faceSecondaryArgb;

  /// Card-face background color of the procedural renderer.
  final int faceBackgroundArgb;

  @override
  final String? storeKey;
  @override
  final String? storeCoverPath;

  /// For store-downloaded packs: canonical card index (0..35) -> relative path.
  final Map<int, String>? storeCardPaths;
  final String? storeBackPath;

  /// Relative path in `PackAssetStore` for Lenormand card [number] (1..36).
  String? storeCardPathForNumber(int number) => storeCardPaths?[number - 1];

  /// Ordered candidate asset paths for card [number] (1..36) — the first
  /// path that loads wins; the procedural face renders when none exist.
  List<String> cardAssetCandidates(int number) {
    if (isStorePack || assetFolder.isEmpty) return const [];
    final n2 = number.toString().padLeft(2, '0');
    return [
      '$assetFolder$n2.jpg',
      '$assetFolder$n2.png',
      '$assetFolder$number.jpg',
      '$assetFolder$number.png',
    ];
  }
}
