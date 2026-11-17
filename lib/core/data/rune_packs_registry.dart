import '../models/rune_pack.dart';

/// Central registry of the 3 built-in 3D rune stone sets. Custom textures
/// may be dropped into `assets/runes/<id>/<rune_id>.png`; the procedural
/// carved-rock shader renders until assets exist.
const List<RunePack> runePacksRegistry = [
  RunePack(
    id: 'obsidian_lavender',
    name: 'Obsidian & Lavender Quartz',
    subtitle: 'Dark volcanic stone with glowing violet engravings',
    assetFolder: 'assets/runes/obsidian_lavender/',
    license: 'Custom set · CC BY 4.0',
    stoneBaseArgb: 0xFF3B3650,
    stoneDarkArgb: 0xFF12101E,
    stoneRimArgb: 0xFFA78BFA,
    glyphArgb: 0xFFD8CBFB,
    glowArgb: 0xFFA78BFA,
    specularArgb: 0xFFE9E4FF,
  ),
  RunePack(
    id: 'nordic_bone',
    name: 'Nordic Carved Bone & Gold',
    subtitle: 'Aged ivory stone with molten gold runes',
    assetFolder: 'assets/runes/nordic_bone/',
    license: 'Custom set · CC BY 4.0',
    stoneBaseArgb: 0xFFF0E6D2,
    stoneDarkArgb: 0xFFB8A98E,
    stoneRimArgb: 0xFFE8C066,
    glyphArgb: 0xFF8A5A10,
    glowArgb: 0xFFE8B23C,
    specularArgb: 0xFFFFF8E6,
  ),
  RunePack(
    id: 'blood_jasper',
    name: 'Blood Jasper & Runic Fire',
    subtitle: 'Deep crimson-charcoal stone with amber runes',
    assetFolder: 'assets/runes/blood_jasper/',
    license: 'Custom set · CC BY 4.0',
    stoneBaseArgb: 0xFF4A1F22,
    stoneDarkArgb: 0xFF170B0D,
    stoneRimArgb: 0xFFF97316,
    glyphArgb: 0xFFFBBF24,
    glowArgb: 0xFFF97316,
    specularArgb: 0xFFFFD9B8,
  ),
];

/// Lookup by id; null for unknown ids.
RunePack? runePackById(String id) {
  for (final pack in runePacksRegistry) {
    if (pack.id == id) return pack;
  }
  return null;
}
