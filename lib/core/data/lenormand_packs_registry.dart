import '../models/lenormand_pack.dart';
import '../models/tarot_deck_pack.dart';

/// Central registry of the 3 built-in Petit Lenormand packs. Card art may
/// be dropped into `assets/lenormand/<id>/01.jpg..36.jpg` (Rider..Cross);
/// until then every pack renders its bespoke procedural face and back.
const List<LenormandPack> lenormandPacksRegistry = [
  LenormandPack(
    id: 'antique_petit',
    name: 'Antique Petit Lenormand',
    subtitleKey: 'content.deck.antique_petit.subtitle',
    assetFolder: 'assets/lenormand/antique_petit/',
    licenseKey: 'content.license.customPack',
    backStyle: CardBackStyle.hermetic,
    backAccentArgb: 0xFFE8D5B5,
    backSecondaryArgb: 0xFF8A6A4F,
    faceAccentArgb: 0xFF4A3728,
    faceSecondaryArgb: 0xFF8A6A4F,
    faceBackgroundArgb: 0xFFF2E8D5,
  ),
  LenormandPack(
    id: 'obsidian_gilded',
    name: 'Obsidian Gilded Lenormand',
    subtitleKey: 'content.deck.obsidian_gilded.subtitle',
    assetFolder: 'assets/lenormand/obsidian_gilded/',
    licenseKey: 'content.license.customPack',
    backStyle: CardBackStyle.obsidian,
    backAccentArgb: 0xFFA78BFA,
    backSecondaryArgb: 0xFF6366F1,
    faceAccentArgb: 0xFFA78BFA,
    faceSecondaryArgb: 0xFF6366F1,
    faceBackgroundArgb: 0xFF13131A,
  ),
  LenormandPack(
    id: 'botanical_noir',
    name: 'Botanical Noir Lenormand',
    subtitleKey: 'content.deck.botanical_noir.subtitle',
    assetFolder: 'assets/lenormand/botanical_noir/',
    licenseKey: 'content.license.customPack',
    backStyle: CardBackStyle.botanical,
    backAccentArgb: 0xFF34D399,
    backSecondaryArgb: 0xFF9CA3AF,
    faceAccentArgb: 0xFF34D399,
    faceSecondaryArgb: 0xFFA7C4A0,
    faceBackgroundArgb: 0xFF0E1512,
  ),
];

/// Lookup by id; null for unknown ids.
LenormandPack? lenormandPackById(String id) {
  for (final pack in lenormandPacksRegistry) {
    if (pack.id == id) return pack;
  }
  return null;
}
