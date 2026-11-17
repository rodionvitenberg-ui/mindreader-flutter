import '../models/tarot_deck_pack.dart';

/// Central registry of the 8 selectable deck packs. The first 7 are REAL
/// public-domain / open-source decks, mapped by `tool/map_decks.py` from
/// `TarotCards/tarot/<deck>/720px/` into `assets/decks/<id>/NN.jpg`
/// (internal 0-77 card ids). The 8th is the procedural typographic fallback
/// deck ("Obsidian Minimal") with no assets at all. Cards missing from a
/// scan (Oswald Wirth minors, a few Visconti cards, 3 Etteilla cards) fall
/// back to the procedural face seamlessly.
const List<TarotDeckPack> deckPacksRegistry = [
  TarotDeckPack(
    id: 'rider_waite',
    name: 'Rider-Waite',
    subtitle: 'The classic 1909 Rider–Waite–Smith deck — real scans',
    assetFolder: 'assets/decks/rider_waite/',
    license: 'Public Domain · Pamela Colman Smith, 1909',
    naming: CardNaming.indexed,
    backAsset: 'back',
    backStyle: CardBackStyle.obsidian,
    backAccentArgb: 0xFFA78BFA,
    backSecondaryArgb: 0xFF6366F1,
    faceAccentArgb: 0xFFA78BFA,
    faceSecondaryArgb: 0xFF6366F1,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'marseille',
    name: 'Tarot de Marseille',
    subtitle: 'The classic French pattern, VIII Justice · XI Strength',
    assetFolder: 'assets/decks/marseille/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.marseille,
    backAccentArgb: 0xFFE8D5B5,
    backSecondaryArgb: 0xFF9A6B4F,
    faceAccentArgb: 0xFFE8D5B5,
    faceSecondaryArgb: 0xFF9A6B4F,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'oswald_wirth',
    name: 'Oswald Wirth',
    subtitle: '1889 esoteric majors, hand-engraved symbolism',
    assetFolder: 'assets/decks/oswald_wirth/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.hermetic,
    backAccentArgb: 0xFFC9B8A3,
    backSecondaryArgb: 0xFF6B5B4F,
    faceAccentArgb: 0xFFC9B8A3,
    faceSecondaryArgb: 0xFF6B5B4F,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'etteilla',
    name: 'Grand Etteilla',
    subtitle: 'Etteilla’s divinatory deck, c. 1880 — own 1–78 numbering',
    assetFolder: 'assets/decks/etteilla/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.shadow,
    backAccentArgb: 0xFFD8C3A5,
    backSecondaryArgb: 0xFF7A5C43,
    faceAccentArgb: 0xFFD8C3A5,
    faceSecondaryArgb: 0xFF7A5C43,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'visconti_sforza',
    name: 'Visconti-Sforza',
    subtitle: 'Milanese court cards, XV century',
    assetFolder: 'assets/decks/visconti_sforza/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.visconti,
    backAccentArgb: 0xFFD6C7A8,
    backSecondaryArgb: 0xFF8C6E4E,
    faceAccentArgb: 0xFFD6C7A8,
    faceSecondaryArgb: 0xFF8C6E4E,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'vieville',
    name: 'Jacques Viéville',
    subtitle: 'Parisian tarot, c. 1650 — quirky woodcut majors',
    assetFolder: 'assets/decks/vieville/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backAsset: 'back',
    backStyle: CardBackStyle.botanical,
    backAccentArgb: 0xFFCDBB9E,
    backSecondaryArgb: 0xFF8A7A5F,
    faceAccentArgb: 0xFFCDBB9E,
    faceSecondaryArgb: 0xFF8A7A5F,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'soimoi',
    name: 'Soimoi',
    subtitle: 'Japanese-style illustrated deck by Mike Koz',
    assetFolder: 'assets/decks/soimoi/',
    license: 'CC BY 4.0 · Mike Koz (koz.tv)',
    naming: CardNaming.indexed,
    backAsset: 'back',
    backStyle: CardBackStyle.cyber,
    backAccentArgb: 0xFF7DD3FC,
    backSecondaryArgb: 0xFFF472B6,
    faceAccentArgb: 0xFF7DD3FC,
    faceSecondaryArgb: 0xFFF472B6,
    isIllustrated: true,
  ),
  TarotDeckPack(
    id: 'obsidian_minimal',
    name: 'Obsidian Minimal',
    subtitle: 'Procedural typographic faces — the built-in fallback',
    assetFolder: 'assets/decks/obsidian_minimal/',
    license: 'Custom pack · CC BY 4.0',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.obsidian,
    backAccentArgb: 0xFFA78BFA,
    backSecondaryArgb: 0xFF6366F1,
    faceAccentArgb: 0xFFA78BFA,
    faceSecondaryArgb: 0xFF6366F1,
  ),
];

/// Lookup by id; null for unknown ids.
TarotDeckPack? deckPackById(String id) {
  for (final pack in deckPacksRegistry) {
    if (pack.id == id) return pack;
  }
  return null;
}
