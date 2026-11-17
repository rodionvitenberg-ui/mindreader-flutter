import '../models/lenormand_pack.dart';
import '../models/tarot_deck_pack.dart';

/// Central registry of the 3 built-in Petit Lenormand packs. Card art may
/// be dropped into `assets/lenormand/<id>/01.jpg..36.jpg` (Rider..Cross);
/// until then every pack renders its bespoke procedural face and back.
const List<LenormandPack> lenormandPacksRegistry = [
  LenormandPack(
    id: 'antique_petit',
    name: 'Antique Petit Lenormand',
    subtitle: '1840s vintage engraving aesthetic — cream paper, sepia ink',
    assetFolder: 'assets/lenormand/antique_petit/',
    license: 'Custom pack · CC BY 4.0',
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
    subtitle: 'Dark obsidian faces with lavender gilded line-work',
    assetFolder: 'assets/lenormand/obsidian_gilded/',
    license: 'Custom pack · CC BY 4.0',
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
    subtitle: 'Charcoal paper, ivy-green ink, night-garden engravings',
    assetFolder: 'assets/lenormand/botanical_noir/',
    license: 'Custom pack · CC BY 4.0',
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
