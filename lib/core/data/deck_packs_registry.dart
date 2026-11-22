import '../models/deck_pack.dart';
import '../models/divination_system.dart';
import '../models/tarot_deck_pack.dart';
import 'lenormand_packs_registry.dart';
import 'rune_packs_registry.dart';

List<DeckPack> packsFor(DivinationSystem system) => switch (system) {
  DivinationSystem.tarot => deckPacksRegistry,
  DivinationSystem.lenormand => lenormandPacksRegistry,
  DivinationSystem.runes => runePacksRegistry,
};

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
    subtitleKey: 'content.deck.rider_waite.subtitle',
    assetFolder: 'assets/decks/rider_waite/',
    licenseKey: 'content.license.rws',
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
    subtitleKey: 'content.deck.marseille.subtitle',
    assetFolder: 'assets/decks/marseille/',
    licenseKey: 'content.license.publicDomain',
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
    subtitleKey: 'content.deck.oswald_wirth.subtitle',
    assetFolder: 'assets/decks/oswald_wirth/',
    licenseKey: 'content.license.publicDomain',
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
    subtitleKey: 'content.deck.etteilla.subtitle',
    assetFolder: 'assets/decks/etteilla/',
    licenseKey: 'content.license.publicDomain',
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
    subtitleKey: 'content.deck.visconti_sforza.subtitle',
    assetFolder: 'assets/decks/visconti_sforza/',
    licenseKey: 'content.license.publicDomain',
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
    subtitleKey: 'content.deck.vieville.subtitle',
    assetFolder: 'assets/decks/vieville/',
    licenseKey: 'content.license.publicDomain',
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
    id: 'obsidian_minimal',
    name: 'Obsidian Minimal',
    subtitleKey: 'content.deck.obsidian_minimal.subtitle',
    assetFolder: 'assets/decks/obsidian_minimal/',
    licenseKey: 'content.license.customPack',
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
