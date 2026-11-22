import '../models/rune_pack.dart';

/// Central registry of the 5 built-in volumetric 3D rune stone sets.
/// Each set ships 5 distinct blank 3D stone sprites (`stone_0..4.webp`)
/// overlaid with procedural carved rune engravings and ignition glow.
const List<RunePack> runePacksRegistry = [
  RunePack(
    id: 'obsidian_lavender',
    name: 'Obsidian & Lavender Quartz',
    subtitleKey: 'content.deck.obsidian_lavender.subtitle',
    assetFolder: 'assets/runes/obsidian_lavender/',
    licenseKey: 'content.license.customSet',
    stoneBaseArgb: 0xFF332E45,
    stoneDarkArgb: 0xFF100E1B,
    stoneRimArgb: 0xFFA78BFA,
    glyphArgb: 0xFFE5DBFF,
    glowArgb: 0xFFA78BFA,
    specularArgb: 0xFFE9E4FF,
    carveShadowArgb: 0xD905040B,
  ),
  RunePack(
    id: 'nordic_bone',
    name: 'Nordic Carved Bone & Gold',
    subtitleKey: 'content.deck.nordic_bone.subtitle',
    assetFolder: 'assets/runes/nordic_bone/',
    licenseKey: 'content.license.customSet',
    stoneBaseArgb: 0xFFEBDCC2,
    stoneDarkArgb: 0xFFB09978,
    stoneRimArgb: 0xFFFFF3DC,
    glyphArgb: 0xFF6B4212,
    glowArgb: 0xFFD99A36,
    specularArgb: 0xFFFFF8E6,
    carveShadowArgb: 0xC83A2108,
  ),
  RunePack(
    id: 'blood_jasper',
    name: 'Blood Jasper & Runic Fire',
    subtitleKey: 'content.deck.blood_jasper.subtitle',
    assetFolder: 'assets/runes/blood_jasper/',
    licenseKey: 'content.license.customSet',
    stoneBaseArgb: 0xFF512023,
    stoneDarkArgb: 0xFF190A0C,
    stoneRimArgb: 0xFFFB923C,
    glyphArgb: 0xFFFDE68A,
    glowArgb: 0xFFF97316,
    specularArgb: 0xFFFFD9B8,
    carveShadowArgb: 0xDD0B0304,
  ),
  RunePack(
    id: 'moss_agate',
    name: 'Forest Moss Agate & Silver',
    subtitleKey: 'content.deck.moss_agate.subtitle',
    assetFolder: 'assets/runes/moss_agate/',
    licenseKey: 'content.license.customSet',
    stoneBaseArgb: 0xFF233B30,
    stoneDarkArgb: 0xFF0C1712,
    stoneRimArgb: 0xFF6EE7B7,
    glyphArgb: 0xFFD1FAE5,
    glowArgb: 0xFF34D399,
    specularArgb: 0xFFE6FFF5,
    carveShadowArgb: 0xD9040C08,
  ),
];

/// Lookup by id; null for unknown ids.
RunePack? runePackById(String id) {
  for (final pack in runePacksRegistry) {
    if (pack.id == id) return pack;
  }
  return null;
}
