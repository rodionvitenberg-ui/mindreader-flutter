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

/// Central registry of the 4 selectable built-in deck packs. The first 3 are
/// REAL public-domain / open-source decks, mapped by `tool/map_decks.py` from
/// `TarotCards/tarot/<deck>/720px/` into `assets/decks/<id>/NN.jpg`
/// (internal 0-77 card ids). The 4th is the procedural typographic fallback
/// deck ("Obsidian Minimal") with no assets at all.
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
