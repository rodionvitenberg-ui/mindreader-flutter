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

/// One selectable tarot deck pack: asset location, procedural identity
/// (back style + palettes as ARGB ints so the model stays Flutter-free),
/// licensing metadata and unlock flags.
class TarotDeckPack {
  const TarotDeckPack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.assetFolder,
    required this.license,
    this.backStyle = CardBackStyle.obsidian,
    this.naming = CardNaming.indexed,
    this.backAsset,
    this.backAccentArgb = 0xFFA78BFA,
    this.backSecondaryArgb = 0xFF6366F1,
    this.faceAccentArgb = 0xFFA78BFA,
    this.faceSecondaryArgb = 0xFF6366F1,
    this.isLocked = false,
    this.isPro = false,
  });

  final String id;
  final String name;
  final String subtitle;

  /// e.g. `assets/decks/rider_waite/` — images may not exist yet; the UI
  /// falls back to a bespoke procedural face/back for this pack.
  final String assetFolder;

  /// Short license / attribution line shown in the picker.
  final String license;

  final CardBackStyle backStyle;
  final CardNaming naming;

  /// Optional `back.jpg` / `back.png` inside [assetFolder]; procedural back
  /// is used when the asset is missing.
  final String? backAsset;

  final int backAccentArgb;
  final int backSecondaryArgb;
  final int faceAccentArgb;
  final int faceSecondaryArgb;
  final bool isLocked;
  final bool isPro;

  /// Ordered candidate asset paths for [card]'s face image — the first one
  /// that loads wins; the procedural face renders when none exist yet.
  List<String> cardAssetCandidates(TarotCard card) {
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

  /// Candidate paths for the custom back asset (null → procedural back).
  List<String>? get backAssetCandidates => backAsset == null
      ? null
      : ['$assetFolder$backAsset.jpg', '$assetFolder$backAsset.png'];
}
