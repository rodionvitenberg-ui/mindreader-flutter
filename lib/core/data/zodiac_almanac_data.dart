import '../models/natal_chart.dart';
import '../models/tarot_card_model.dart' show Element;

/// Yang (positive/outgoing) or yin (receptive) polarity of a sign.
enum ZodiacPolarity { yang, yin }

extension ZodiacPolarityX on ZodiacPolarity {
  String get label => switch (this) {
    ZodiacPolarity.yang => 'Yang · Positive',
    ZodiacPolarity.yin => 'Yin · Receptive',
  };
}

/// One fully offline Almanac entry for a zodiac sign.
class ZodiacSignEntry {
  const ZodiacSignEntry({
    required this.sign,
    required this.dateRange,
    required this.polarity,
    required this.houseAffinity,
    required this.keywords,
    required this.archetype,
    required this.shadow,
    required this.loveStyle,
    required this.careerVector,
    this.coRuler,
  });

  final ZodiacSign sign;

  /// E.g. 'Mar 21 – Apr 19'.
  final String dateRange;

  final ZodiacPolarity polarity;

  /// The natural house of the sign, 1..12.
  final int houseAffinity;

  /// Three archetype keywords.
  final List<String> keywords;

  /// Core psychological archetype.
  final String archetype;

  /// Shadow / stress tendencies.
  final String shadow;

  /// Love and connection style.
  final String loveStyle;

  /// Career and path vector.
  final String careerVector;

  /// Traditional co-ruler when it differs from the modern ruler.
  final PlanetId? coRuler;

  String get name => sign.title;
  String get glyph => sign.glyph;
  Element get element => sign.element;
  ZodiacModality get modality => sign.modality;

  /// Modern ruler.
  PlanetId get ruler => sign.ruler;

  /// Human-readable house affinity, e.g. '1st House'.
  String get houseLabel =>
      '$houseAffinity${_ordinalSuffix(houseAffinity)} House';

  /// Rulers line, e.g. 'Mars' or 'Pluto · trad. Mars'.
  String get rulersLabel => coRuler == null
      ? ruler.title
      : '${ruler.title} · trad. ${coRuler!.title}';
}

String _ordinalSuffix(int n) => switch (n) {
  1 => 'st',
  2 => 'nd',
  3 => 'rd',
  _ => 'th',
};

/// All twelve signs, Aries-first.
const List<ZodiacSignEntry> zodiacAlmanac = [
  ZodiacSignEntry(
    sign: ZodiacSign.aries,
    dateRange: 'Mar 21 – Apr 19',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 1,
    keywords: ['Initiative', 'Courage', 'Honesty'],
    archetype:
        'The Pioneer — the part of you that moves before the plan is ready '
        'and trusts the first honest impulse.',
    shadow:
        'Impatience, starting what it will not finish, and mistaking speed '
        'for courage when the room asks for listening.',
    loveStyle:
        'Direct pursuit and uncomplicated desire; needs the freedom to chase '
        'and a partner who answers honestly instead of playing games.',
    careerVector:
        'Founding, leading and competitive work where the first move counts '
        'more than the safe move.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.taurus,
    dateRange: 'Apr 20 – May 20',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 2,
    keywords: ['Steadiness', 'Value', 'Pleasure'],
    archetype:
        'The Builder — the part of you that knows what a thing is worth and '
        'keeps it long enough to grow.',
    shadow:
        'Stubbornness, possessiveness and using comfort as a way to avoid the '
        'change that has already arrived.',
    loveStyle:
        'Loyal, sensual and slow to trust; shows love through presence, food '
        'and reliable hands rather than grand speeches.',
    careerVector:
        'Finance, craft, land and long-horizon projects where patience '
        'compounds into real value.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.gemini,
    dateRange: 'May 21 – Jun 20',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 3,
    keywords: ['Curiosity', 'Language', 'Adaptation'],
    archetype:
        'The Messenger — the part of you that learns by naming, linking and '
        'asking the second question.',
    shadow:
        'Scatter, restlessness and half-truths told to keep every door open '
        'at once.',
    loveStyle:
        'Playful and conversational; needs a mind that answers back and space '
        'to change its story without losing the connection.',
    careerVector:
        'Media, writing, teaching and trade — anywhere the currency is '
        'information and the speed of the exchange.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.cancer,
    dateRange: 'Jun 21 – Jul 22',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 4,
    keywords: ['Care', 'Memory', 'Belonging'],
    archetype:
        'The Guardian — the part of you that remembers who was there and '
        'builds a home out of that loyalty.',
    shadow:
        'Over-attachment, moodiness and expressing needs indirectly so they '
        'can never be refused out loud.',
    loveStyle:
        'Protective and nurturing; bonds through shared history and needs '
        'reassurance that the home is mutual.',
    careerVector:
        'Care, hospitality, family business and heritage work where feeling '
        'is part of the competence.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.leo,
    dateRange: 'Jul 23 – Aug 22',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 5,
    keywords: ['Radiance', 'Heart', 'Creation'],
    archetype:
        'The Sovereign — the part of you that creates warmth by taking the '
        'stage and giving it back to the room.',
    shadow:
        'Pride, needing applause and becoming rigid when the audience looks '
        'elsewhere.',
    loveStyle:
        'Generous and loyal; wants to be seen and celebrated, and gives the '
        'same spotlight in return.',
    careerVector:
        'Performance, leadership and creative direction where a personal '
        'signature is the product.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.virgo,
    dateRange: 'Aug 23 – Sep 22',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 6,
    keywords: ['Discernment', 'Service', 'Craft'],
    archetype:
        'The Artisan — the part of you that serves by noticing what can be '
        'made precise.',
    shadow:
        'Perfectionism, self-criticism and control disguised as helpfulness.',
    loveStyle:
        'Attentive and practical; shows love through small acts of repair and '
        'needs appreciation for the invisible work.',
    careerVector:
        'Analysis, health, editing and systems where accuracy is the craft.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.libra,
    dateRange: 'Sep 23 – Oct 22',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 7,
    keywords: ['Balance', 'Relation', 'Beauty'],
    archetype:
        'The Diplomat — the part of you that weighs both sides before it '
        'commits and finds the fair form.',
    shadow:
        'Indecision, people-pleasing and avoiding conflict until the choice '
        'is made by default.',
    loveStyle:
        'Romantic and partnership-minded; flourishes with someone who treats '
        'the relationship as a shared work of art.',
    careerVector:
        'Law, design, negotiation and partnership where the human interface '
        'is the work.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.scorpio,
    dateRange: 'Oct 23 – Nov 21',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 8,
    keywords: ['Depth', 'Transformation', 'Intensity'],
    archetype:
        'The Alchemist — the part of you that goes all the way down and '
        'returns with something worth keeping.',
    shadow: 'Control, secrecy and resentment held long past its usefulness.',
    loveStyle:
        'All-in and private; tests trust before it gives it, then protects '
        'the bond with fierce loyalty.',
    careerVector:
        'Research, crisis work, finance and psychology where the hidden '
        'layer is the real subject.',
    coRuler: PlanetId.mars,
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.sagittarius,
    dateRange: 'Nov 22 – Dec 21',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 9,
    keywords: ['Meaning', 'Freedom', 'Horizon'],
    archetype:
        'The Seeker — the part of you that needs the bigger story and will '
        'travel to find the sentence that fits.',
    shadow: 'Dogma, escape and promising more adventure than can be delivered.',
    loveStyle:
        'Adventurous and honest; needs room to roam and a partner who is also '
        'a fellow traveller.',
    careerVector:
        'Teaching, travel, publishing and philosophy where the horizon is the '
        'point.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.capricorn,
    dateRange: 'Dec 22 – Jan 19',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 10,
    keywords: ['Mastery', 'Structure', 'Responsibility'],
    archetype:
        'The Architect — the part of you that respects limits and builds '
        'something that outlasts the mood.',
    shadow:
        'Coldness, workaholism and a fear of failure that turns discipline '
        'into self-punishment.',
    loveStyle:
        'Committed and slow; shows love through reliability and long-term '
        'plans rather than sudden declarations.',
    careerVector:
        'Management, engineering, institutions and legacy work where the long '
        'game is the reward.',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.aquarius,
    dateRange: 'Jan 20 – Feb 18',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 11,
    keywords: ['Vision', 'System', 'Independence'],
    archetype:
        'The Reformer — the part of you that questions the crowd and rebuilds '
        'the system for the people outside it.',
    shadow:
        'Detachment, contrarianism and keeping everyone at a principled '
        'distance.',
    loveStyle:
        'Friendship-first and unconventional; needs intellectual freedom and '
        'a partner who is also a comrade.',
    careerVector:
        'Technology, science, activism and networks where the future is being '
        'designed.',
    coRuler: PlanetId.saturn,
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.pisces,
    dateRange: 'Feb 19 – Mar 20',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 12,
    keywords: ['Imagination', 'Compassion', 'Surrender'],
    archetype:
        'The Mystic — the part of you that absorbs the mood and dreams it '
        'back softer.',
    shadow:
        'Escapism, blurred boundaries and a quiet habit of casting yourself as '
        'the one who can only endure.',
    loveStyle:
        'Merging and empathic; loves through atmosphere and imagination, and '
        'needs boundaries to keep the tenderness real.',
    careerVector:
        'Art, healing, music and contemplative work where sensitivity is the '
        'instrument.',
    coRuler: PlanetId.jupiter,
  ),
];

/// Sign entries of one element (3 each).
List<ZodiacSignEntry> zodiacEntriesForElement(Element element) => [
  for (final e in zodiacAlmanac)
    if (e.element == element) e,
];

/// Sign entries of one modality (4 each).
List<ZodiacSignEntry> zodiacEntriesForModality(ZodiacModality modality) => [
  for (final e in zodiacAlmanac)
    if (e.modality == modality) e,
];

/// The Almanac entry for a sign.
ZodiacSignEntry zodiacEntryFor(ZodiacSign sign) =>
    zodiacAlmanac.firstWhere((e) => e.sign == sign);

/// Civil birth-date ranges used by the twelve entries in this almanac.
ZodiacSign almanacBirthSign(DateTime date) {
  const firstDay = [20, 19, 21, 20, 21, 21, 23, 23, 23, 23, 22, 22];
  // January's late-month sign is Aquarius, at index 10 in Aries-first order.
  final lateSign = (date.month + 9) % 12;
  final index = date.day >= firstDay[date.month - 1]
      ? lateSign
      : (lateSign + 11) % 12;
  return zodiacAlmanac[index].sign;
}
