import '../l10n/app_strings.dart';
import 'deck_pack.dart';
import 'tarot_card_model.dart';

/// Procedural card-back pattern family for a deck pack.
enum CardBackStyle { obsidian, marseille, hermetic, botanical, visconti, shadow, cyber }

/// How card asset files are named inside [TarotDeckPack.assetFolder].
enum CardNaming {
  /// `0.jpg`..`77.jpg` (+ padded `00.jpg`..`77.jpg`).
  indexed,

  /// Rider-Waite style: `00_Fool.jpg`, `21_World.jpg`, `Wands01.jpg`, …
  rws,

  /// Any scheme — only id-based candidates are attempted.
  generic,
}

/// One selectable tarot deck pack: asset location (bundled or store-downloaded),
/// procedural identity (back style + palettes as ARGB ints so the model stays
/// Flutter-free), licensing metadata and unlock flags.
class TarotDeckPack extends DeckPack {
  const TarotDeckPack({
    required this.id,
    required this.name,
    this.subtitleKey = '',
    this.rawSubtitle,
    required this.assetFolder,
    this.licenseKey = '',
    this.rawLicense,
    this.backStyle = CardBackStyle.obsidian,
    this.naming = CardNaming.indexed,
    this.backAsset,
    this.backAccentArgb = 0xFFA78BFA,
    this.backSecondaryArgb = 0xFF6366F1,
    this.faceAccentArgb = 0xFFA78BFA,
    this.faceSecondaryArgb = 0xFF6366F1,
    this.isIllustrated = false,
    this.isLocked = false,
    this.isPro = false,
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

  /// e.g. `assets/decks/rider_waite/` — images may not exist yet; the UI
  /// falls back to a bespoke procedural face/back for this pack.
  final String assetFolder;

  /// Short license / attribution line shown in the picker.
  final String licenseKey;
  final String? rawLicense;

  @override
  String get license =>
      rawLicense ?? (licenseKey.isEmpty ? '' : AppStrings.g(licenseKey));

  final CardBackStyle backStyle;
  final CardNaming naming;

  /// Optional `back.jpg` / `back.png` inside [assetFolder]; procedural back
  /// is used when the asset is missing.
  final String? backAsset;

  final int backAccentArgb;
  final int backSecondaryArgb;
  final int faceAccentArgb;
  final int faceSecondaryArgb;

  /// True for decks with full-bleed card illustrations (no text bars overlay).
  final bool isIllustrated;
  final bool isLocked;
  final bool isPro;

  @override
  final String? storeKey;
  @override
  final String? storeCoverPath;

  /// For store-downloaded decks: `cardId (0..77) -> relative path inside storeKey`.
  final Map<int, String>? storeCardPaths;

  /// For store-downloaded decks: relative path to `back.(jpg|png|webp)`.
  final String? storeBackPath;

  /// Relative path in `PackAssetStore` for [card], or `null` when absent.
  String? storeCardPathFor(TarotCard card) => storeCardPaths?[card.id];

  /// Ordered candidate bundled asset paths for [card]'s face image — the first
  /// one that loads wins; the procedural face renders when none exist yet.
  List<String> cardAssetCandidates(TarotCard card) {
    if (isStorePack || assetFolder.isEmpty) return const [];
    final id2 = card.id.toString().padLeft(2, '0');
    final out = <String>[];
    void add(String base) {
      out.add('$assetFolder$base.jpg');
      out.add('$assetFolder$base.png');
    }

    add('${card.id}');
    add(id2);
    if (naming == CardNaming.rws) {
      add('${id2}_${card.name.replaceAll(' ', '_')}');
      if (card.suit != null) {
        final suit = card.suit == Suit.pentacles ? 'Pents' : card.suit!.label;
        add('$suit${card.number.toString().padLeft(2, '0')}');
      }
    }
    return out;
  }

  /// Candidate bundled paths for the custom back asset (null → procedural back).
  List<String>? get backAssetCandidates => (isStorePack || backAsset == null)
      ? null
      : ['$assetFolder$backAsset.jpg', '$assetFolder$backAsset.png'];
}
