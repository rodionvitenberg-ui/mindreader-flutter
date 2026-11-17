import '../models/rune_stone.dart';
import '../models/tarot_card_model.dart';

/// The complete 24-rune Elder Futhark dataset (Fehu .. Othala) divided
/// into the three canonical Aetts. The 8 symmetrical runes (Gebo,
/// Hagalaz, Isa, Jera, Eihwaz, Sowilo, Ingwaz, Dagaz) carry NO merkstave
/// reading — their glyph is its own mirror, so they always stay upright.
const List<RuneStone> elderFuthark = [
  RuneStone(
    id: 0, name: 'Fehu', glyph: 'ᚠ', phonetic: 'F',
    aett: RuneAett.freyr, element: Element.fire,
    keywords: ['Wealth', 'Cattle', 'Energy'],
    upright: 'Movable wealth and raw energy — prosperity that must keep flowing to stay alive.',
    lore: 'Freyr’s first rune: the cattle-wealth a free farmer could count, and the fire that keeps a homestead alive.',
    merkstave: 'Loss, greed, or energy burned faster than it is earned.',
  ),
  RuneStone(
    id: 1, name: 'Uruz', glyph: 'ᚢ', phonetic: 'U',
    aett: RuneAett.freyr, element: Element.earth,
    keywords: ['Strength', 'Aurochs', 'Health'],
    upright: 'Untamed strength and the body’s own will — the aurochs that cannot be domesticated.',
    lore: 'The wild ox of the northern meadows — power that comes from the earth, not from training.',
    merkstave: 'Weakness, missed force, or strength turned against itself.',
  ),
  RuneStone(
    id: 2, name: 'Thurisaz', glyph: 'ᚦ', phonetic: 'TH',
    aett: RuneAett.freyr, element: Element.fire,
    keywords: ['Giant', 'Thorn', 'Defense'],
    upright: 'The thorn and the hammer — a reactive strike that protects the boundary.',
    lore: 'Thor’s rune of the giants’ thorn: defense that stings whatever pushes too far.',
    merkstave: 'Hostility, hasty blows, or a threat you refuse to see.',
  ),
  RuneStone(
    id: 3, name: 'Ansuz', glyph: 'ᚨ', phonetic: 'A',
    aett: RuneAett.freyr, element: Element.air,
    keywords: ['Voice', 'Odin', 'Wisdom'],
    upright: 'The mouth of Odin — inspired speech, signals, and the message carried on the wind.',
    lore: 'The rune of the Allfather’s breath — poetry, runes and the advice of elders.',
    merkstave: 'Lies, bad counsel, or words that outrun their meaning.',
  ),
  RuneStone(
    id: 4, name: 'Raidho', glyph: 'ᚱ', phonetic: 'R',
    aett: RuneAett.freyr, element: Element.air,
    keywords: ['Journey', 'Rhythm', 'Ride'],
    upright: 'The ride and the road — movement with a rhythm, the journey as much as the arrival.',
    lore: 'The wagon-rune: right motion in right order, the wheel that turns and returns.',
    merkstave: 'Delay, wrong turns, or a journey forced off its road.',
  ),
  RuneStone(
    id: 5, name: 'Kenaz', glyph: 'ᚲ', phonetic: 'K',
    aett: RuneAett.freyr, element: Element.fire,
    keywords: ['Torch', 'Craft', 'Revelation'],
    upright: 'The torch of skill — knowledge that illuminates and the craft that shapes the dark.',
    lore: 'The smith’s fire: the rune of the forge, the workshop and the skill of the hand.',
    merkstave: 'Extinguished light, raw potential unshaped, or fever without direction.',
  ),
  RuneStone(
    id: 6, name: 'Gebo', glyph: 'ᚷ', phonetic: 'G',
    aett: RuneAett.freyr, element: Element.air,
    keywords: ['Gift', 'Exchange', 'Partnership'],
    upright: 'The gift and the counter-gift — every bond is an exchange kept alive by both hands.',
    lore: 'The rune of hospitality: no gift without return, no bond without balance.',
  ),
  RuneStone(
    id: 7, name: 'Wunjo', glyph: 'ᚹ', phonetic: 'W',
    aett: RuneAett.freyr, element: Element.earth,
    keywords: ['Joy', 'Harmony', 'Belonging'],
    upright: 'Joy that comes from belonging — kinship, shared work and the peace of the tribe.',
    lore: 'The rune of the clan’s gladness — prosperity shared around one hearth.',
    merkstave: 'Loneliness, joy postponed, or belonging bought too cheap.',
  ),
  RuneStone(
    id: 8, name: 'Hagalaz', glyph: 'ᚺ', phonetic: 'H',
    aett: RuneAett.hagal, element: Element.water,
    keywords: ['Hail', 'Disruption', 'Clearing'],
    upright: 'Hail out of a clear sky — sudden disruption that clears the field for what comes next.',
    lore: 'The hail-rune: the storm that flattens the harvest and the seed it leaves behind.',
  ),
  RuneStone(
    id: 9, name: 'Nauthiz', glyph: 'ᚾ', phonetic: 'N',
    aett: RuneAett.hagal, element: Element.fire,
    keywords: ['Need', 'Constraint', 'Survival'],
    upright: 'Need-fire and necessity — constraint that teaches what comfort never could.',
    lore: 'The rune of necessity: the cold that teaches a long winter’s patience.',
    merkstave: 'Hunger, despair, or resistance to a lesson need is teaching.',
  ),
  RuneStone(
    id: 10, name: 'Isa', glyph: 'ᛁ', phonetic: 'I',
    aett: RuneAett.hagal, element: Element.water,
    keywords: ['Ice', 'Stillness', 'Patience'],
    upright: 'Ice — a frozen pause in which nothing moves and everything waits.',
    lore: 'The rune of the frozen river: stillness so deep it becomes its own season.',
  ),
  RuneStone(
    id: 11, name: 'Jera', glyph: 'ᛃ', phonetic: 'J',
    aett: RuneAett.hagal, element: Element.earth,
    keywords: ['Harvest', 'Cycle', 'Reward'],
    upright: 'The year’s wheel turning — what was sown in its season returns in its own time.',
    lore: 'The harvest-rune: the farmer’s year, where nothing ripens before its month.',
  ),
  RuneStone(
    id: 12, name: 'Eihwaz', glyph: 'ᛇ', phonetic: 'EI',
    aett: RuneAett.hagal, element: Element.earth,
    keywords: ['Yew', 'Endurance', 'Axis'],
    upright: 'The yew — the world-tree’s endurance, death and rebirth braided into one root.',
    lore: 'Odin’s rune of the yew bow: the spine of the worlds, flexible and unbroken.',
  ),
  RuneStone(
    id: 13, name: 'Perthro', glyph: 'ᛈ', phonetic: 'P',
    aett: RuneAett.hagal, element: Element.water,
    keywords: ['Mystery', 'Chance', 'Lot-cup'],
    upright: 'The lot-cup and the hidden — what chance decides and what the runes keep secret.',
    lore: 'The rune of the thrown lots: fate read in the fall of carved wood.',
    merkstave: 'Secrets kept too long, or luck that runs against you.',
  ),
  RuneStone(
    id: 14, name: 'Algiz', glyph: 'ᛉ', phonetic: 'Z',
    aett: RuneAett.hagal, element: Element.air,
    keywords: ['Protection', 'Elk', 'Warding'],
    upright: 'The elk’s antlers — protection raised, the ward that turns harm aside.',
    lore: 'The ward-rune: antlers lifted against the wolf, the warning of the marsh-bird.',
    merkstave: 'Exposure, dropped defenses, or a shield carried for the wrong war.',
  ),
  RuneStone(
    id: 15, name: 'Sowilo', glyph: 'ᛊ', phonetic: 'S',
    aett: RuneAett.hagal, element: Element.fire,
    keywords: ['Sun', 'Victory', 'Will'],
    upright: 'The sun — unstoppable light, will aimed true, victory that does not apologize.',
    lore: 'The sun-rune: the wheel of light that drives the long northern day.',
  ),
  RuneStone(
    id: 16, name: 'Tiwaz', glyph: 'ᛏ', phonetic: 'T',
    aett: RuneAett.tyr, element: Element.air,
    keywords: ['Justice', 'Honor', 'Sacrifice'],
    upright: 'Tyr’s rune — the hand offered into the wolf’s mouth for the sake of the oath.',
    lore: 'The rune of the one-handed god: justice that costs the judge something.',
    merkstave: 'Injustice, broken oaths, or victory won without honor.',
  ),
  RuneStone(
    id: 17, name: 'Berkano', glyph: 'ᛒ', phonetic: 'B',
    aett: RuneAett.tyr, element: Element.earth,
    keywords: ['Birch', 'Birth', 'Nurture'],
    upright: 'The birch-goddess — birth, growth and the quiet nurture that makes things flourish.',
    lore: 'The rune of the birch grove: spring’s first green and the goddess of new life.',
    merkstave: 'Stalled growth, neglect, or a birth refused its season.',
  ),
  RuneStone(
    id: 18, name: 'Ehwaz', glyph: 'ᛖ', phonetic: 'E',
    aett: RuneAett.tyr, element: Element.air,
    keywords: ['Horse', 'Trust', 'Progress'],
    upright: 'The horse and rider — two wills moving as one, progress built on mutual trust.',
    lore: 'The rune of the mounted pair: the bond between rider and steed, partner and partner.',
    merkstave: 'Mistrust, broken pace, or a partnership pulling in two directions.',
  ),
  RuneStone(
    id: 19, name: 'Mannaz', glyph: 'ᛗ', phonetic: 'M',
    aett: RuneAett.tyr, element: Element.air,
    keywords: ['Humanity', 'Self', 'Kinship'],
    upright: 'The human — self-knowledge and the kinship that makes an individual a people.',
    lore: 'The rune of humankind: the self seen in the eyes of the clan.',
    merkstave: 'Self-doubt, isolation, or the crowd drowning the self.',
  ),
  RuneStone(
    id: 20, name: 'Laguz', glyph: 'ᛚ', phonetic: 'L',
    aett: RuneAett.tyr, element: Element.water,
    keywords: ['Water', 'Flow', 'Intuition'],
    upright: 'Water and the deep — intuition that moves like the tide, under and around reason.',
    lore: 'The rune of the sea-road: voyages, dreams and what the depths remember.',
    merkstave: 'Drowning, illusion, or feeling that floods the shore.',
  ),
  RuneStone(
    id: 21, name: 'Ingwaz', glyph: 'ᛜ', phonetic: 'NG',
    aett: RuneAett.tyr, element: Element.earth,
    keywords: ['Seed', 'Potential', 'Fertility'],
    upright: 'The seed’s silence — potential stored, the energy of what is about to become.',
    lore: 'Ing’s rune: the god of the fertile earth, the stored seed of the coming year.',
  ),
  RuneStone(
    id: 22, name: 'Dagaz', glyph: 'ᛞ', phonetic: 'D',
    aett: RuneAett.tyr, element: Element.air,
    keywords: ['Daybreak', 'Awakening', 'Paradox'],
    upright: 'Daybreak — the turn of night into day, the paradox that completes itself.',
    lore: 'The rune of dawn: the moment the long night yields to the long day.',
  ),
  RuneStone(
    id: 23, name: 'Othala', glyph: 'ᛟ', phonetic: 'O',
    aett: RuneAett.tyr, element: Element.earth,
    keywords: ['Ancestry', 'Homeland', 'Legacy'],
    upright: 'The ancestral land — inheritance, home ground, and what outlives a single life.',
    lore: 'The rune of the family estate: land held across generations, a seat at the long table.',
    merkstave: 'Exile, inheritance squandered, or walls that keep kin out.',
  ),
];

/// Lookup by id (0..23); null for unknown ids.
RuneStone? runeStoneById(int id) {
  for (final r in elderFuthark) {
    if (r.id == id) return r;
  }
  return null;
}
