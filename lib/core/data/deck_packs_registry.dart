import '../models/tarot_deck_pack.dart';

/// Central registry of the 8 selectable deck packs. Asset folders follow
/// the `assets/decks/<id>/` convention — drop the user's downloaded deck
/// images there (id-based or RWS naming) and they replace the bespoke
/// procedural faces/backs automatically, with zero-crash fallback.
const List<TarotDeckPack> deckPacksRegistry = [
  TarotDeckPack(
    id: 'rider_waite',
    name: 'Rider-Waite',
    subtitle: 'The classic 1909 Rider–Waite–Smith deck',
    assetFolder: 'assets/decks/rider_waite/',
    license: 'Public Domain · Pamela Colman Smith, 1909',
    naming: CardNaming.rws,
    backStyle: CardBackStyle.obsidian,
    backAccentArgb: 0xFFA78BFA,
    backSecondaryArgb: 0xFF6366F1,
    faceAccentArgb: 0xFFA78BFA,
    faceSecondaryArgb: 0xFF6366F1,
  ),
  TarotDeckPack(
    id: 'marseille',
    name: 'Tarot de Marseille',
    subtitle: 'The classic French pattern, historical trump numbering',
    assetFolder: 'assets/decks/marseille/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.marseille,
    backAccentArgb: 0xFFE8D5B5,
    backSecondaryArgb: 0xFF9A6B4F,
    faceAccentArgb: 0xFFE8D5B5,
    faceSecondaryArgb: 0xFF9A6B4F,
  ),
  TarotDeckPack(
    id: 'thoth_obsidian',
    name: 'Thoth Obsidian',
    subtitle: 'Esoteric geometry, obsidian glass and sigils',
    assetFolder: 'assets/decks/thoth_obsidian/',
    license: 'Custom pack · CC BY 4.0',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.hermetic,
    backAccentArgb: 0xFF8B5CF6,
    backSecondaryArgb: 0xFF22D3EE,
    faceAccentArgb: 0xFF8B5CF6,
    faceSecondaryArgb: 0xFF22D3EE,
    isPro: true,
  ),
  TarotDeckPack(
    id: 'botanical',
    name: 'Botanical',
    subtitle: 'Herbarium line work in moss and emerald',
    assetFolder: 'assets/decks/botanical/',
    license: 'Custom pack · CC BY 4.0',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.botanical,
    backAccentArgb: 0xFF34D399,
    backSecondaryArgb: 0xFF14532D,
    faceAccentArgb: 0xFF34D399,
    faceSecondaryArgb: 0xFF14532D,
  ),
  TarotDeckPack(
    id: 'hermetic',
    name: 'Hermetic',
    subtitle: 'Minimal runic seals on slate',
    assetFolder: 'assets/decks/hermetic/',
    license: 'Custom pack · CC BY 4.0',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.shadow,
    backAccentArgb: 0xFF94A3B8,
    backSecondaryArgb: 0xFFFB7185,
    faceAccentArgb: 0xFF94A3B8,
    faceSecondaryArgb: 0xFFFB7185,
  ),
  TarotDeckPack(
    id: 'visconti',
    name: 'Visconti-Sforza',
    subtitle: 'Renaissance hand-painted medallions, Milan c. 1450',
    assetFolder: 'assets/decks/visconti/',
    license: 'Public Domain · Wikimedia Commons',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.visconti,
    backAccentArgb: 0xFFD6C7A8,
    backSecondaryArgb: 0xFF8C6E4E,
    faceAccentArgb: 0xFFD6C7A8,
    faceSecondaryArgb: 0xFF8C6E4E,
  ),
  TarotDeckPack(
    id: 'shadow_minimal',
    name: 'Shadow Minimal',
    subtitle: 'Monochrome lattice, distilled to bare geometry',
    assetFolder: 'assets/decks/shadow_minimal/',
    license: 'Custom pack · CC BY 4.0',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.obsidian,
    backAccentArgb: 0xFF71717A,
    backSecondaryArgb: 0xFF3F3F46,
    faceAccentArgb: 0xFFA1A1AA,
    faceSecondaryArgb: 0xFF3F3F46,
  ),
  TarotDeckPack(
    id: 'cyber_arcana',
    name: 'Cyber Arcana',
    subtitle: 'Neon circuit traces on carbon black',
    assetFolder: 'assets/decks/cyber_arcana/',
    license: 'Custom pack · CC BY 4.0',
    naming: CardNaming.indexed,
    backStyle: CardBackStyle.cyber,
    backAccentArgb: 0xFF22D3EE,
    backSecondaryArgb: 0xFFF472B6,
    faceAccentArgb: 0xFF22D3EE,
    faceSecondaryArgb: 0xFFF472B6,
    isPro: true,
  ),
];

/// Lookup by id; null for unknown ids.
TarotDeckPack? deckPackById(String id) {
  for (final pack in deckPacksRegistry) {
    if (pack.id == id) return pack;
  }
  return null;
}
