import '../l10n/app_strings.dart';
import '../models/natal_chart.dart';
import '../models/tarot_card_model.dart' show Element;

/// Yang (positive/outgoing) or yin (receptive) polarity of a sign.
enum ZodiacPolarity { yang, yin }

extension ZodiacPolarityX on ZodiacPolarity {
  String get label => AppStrings.g('content.polarity.$name');
}

/// One fully offline Almanac entry for a zodiac sign.
class ZodiacSignEntry {
  const ZodiacSignEntry({
    required this.sign,
    required this.dateRangeKey,
    required this.polarity,
    required this.houseAffinity,
    required this.keywordKeys,
    required this.archetypeKey,
    required this.shadowKey,
    required this.loveStyleKey,
    required this.careerVectorKey,
    this.coRuler,
  });

  final ZodiacSign sign;

  /// E.g. 'Mar 21 – Apr 19'.
  final String dateRangeKey;

  final ZodiacPolarity polarity;

  /// The natural house of the sign, 1..12.
  final int houseAffinity;

  /// Three archetype keywords.
  final List<String> keywordKeys;

  /// Core psychological archetype.
  final String archetypeKey;

  /// Shadow / stress tendencies.
  final String shadowKey;

  /// Love and connection style.
  final String loveStyleKey;

  /// Career and path vector.
  final String careerVectorKey;

  /// Traditional co-ruler when it differs from the modern ruler.
  final PlanetId? coRuler;

  String get dateRange => AppStrings.g(dateRangeKey);
  List<String> get keywords => [
    for (final key in keywordKeys) AppStrings.g(key),
  ];
  String get archetype => AppStrings.g(archetypeKey);
  String get shadow => AppStrings.g(shadowKey);
  String get loveStyle => AppStrings.g(loveStyleKey);
  String get careerVector => AppStrings.g(careerVectorKey);

  String get name => sign.title;
  String get glyph => sign.glyph;
  Element get element => sign.element;
  ZodiacModality get modality => sign.modality;

  /// Modern ruler.
  PlanetId get ruler => sign.ruler;

  /// Human-readable house affinity, e.g. '1st House'.
  String get houseLabel => AppStrings.g('content.house.$houseAffinity');

  /// Rulers line, e.g. 'Mars' or 'Pluto · trad. Mars'.
  String get rulersLabel => coRuler == null
      ? ruler.title
      : AppStrings.g('content.rulers.traditional', {
          'modern': ruler.title,
          'traditional': coRuler!.title,
        });
}

/// All twelve signs, Aries-first.
const List<ZodiacSignEntry> zodiacAlmanac = [
  ZodiacSignEntry(
    sign: ZodiacSign.aries,
    dateRangeKey: 'content.zodiac.aries.dateRange',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 1,
    keywordKeys: [
      'content.zodiac.aries.keyword.0',
      'content.zodiac.aries.keyword.1',
      'content.zodiac.aries.keyword.2',
    ],
    archetypeKey: 'content.zodiac.aries.archetype',
    shadowKey: 'content.zodiac.aries.shadow',
    loveStyleKey: 'content.zodiac.aries.loveStyle',
    careerVectorKey: 'content.zodiac.aries.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.taurus,
    dateRangeKey: 'content.zodiac.taurus.dateRange',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 2,
    keywordKeys: [
      'content.zodiac.taurus.keyword.0',
      'content.zodiac.taurus.keyword.1',
      'content.zodiac.taurus.keyword.2',
    ],
    archetypeKey: 'content.zodiac.taurus.archetype',
    shadowKey: 'content.zodiac.taurus.shadow',
    loveStyleKey: 'content.zodiac.taurus.loveStyle',
    careerVectorKey: 'content.zodiac.taurus.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.gemini,
    dateRangeKey: 'content.zodiac.gemini.dateRange',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 3,
    keywordKeys: [
      'content.zodiac.gemini.keyword.0',
      'content.zodiac.gemini.keyword.1',
      'content.zodiac.gemini.keyword.2',
    ],
    archetypeKey: 'content.zodiac.gemini.archetype',
    shadowKey: 'content.zodiac.gemini.shadow',
    loveStyleKey: 'content.zodiac.gemini.loveStyle',
    careerVectorKey: 'content.zodiac.gemini.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.cancer,
    dateRangeKey: 'content.zodiac.cancer.dateRange',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 4,
    keywordKeys: [
      'content.zodiac.cancer.keyword.0',
      'content.zodiac.cancer.keyword.1',
      'content.zodiac.cancer.keyword.2',
    ],
    archetypeKey: 'content.zodiac.cancer.archetype',
    shadowKey: 'content.zodiac.cancer.shadow',
    loveStyleKey: 'content.zodiac.cancer.loveStyle',
    careerVectorKey: 'content.zodiac.cancer.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.leo,
    dateRangeKey: 'content.zodiac.leo.dateRange',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 5,
    keywordKeys: [
      'content.zodiac.leo.keyword.0',
      'content.zodiac.leo.keyword.1',
      'content.zodiac.leo.keyword.2',
    ],
    archetypeKey: 'content.zodiac.leo.archetype',
    shadowKey: 'content.zodiac.leo.shadow',
    loveStyleKey: 'content.zodiac.leo.loveStyle',
    careerVectorKey: 'content.zodiac.leo.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.virgo,
    dateRangeKey: 'content.zodiac.virgo.dateRange',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 6,
    keywordKeys: [
      'content.zodiac.virgo.keyword.0',
      'content.zodiac.virgo.keyword.1',
      'content.zodiac.virgo.keyword.2',
    ],
    archetypeKey: 'content.zodiac.virgo.archetype',
    shadowKey: 'content.zodiac.virgo.shadow',
    loveStyleKey: 'content.zodiac.virgo.loveStyle',
    careerVectorKey: 'content.zodiac.virgo.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.libra,
    dateRangeKey: 'content.zodiac.libra.dateRange',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 7,
    keywordKeys: [
      'content.zodiac.libra.keyword.0',
      'content.zodiac.libra.keyword.1',
      'content.zodiac.libra.keyword.2',
    ],
    archetypeKey: 'content.zodiac.libra.archetype',
    shadowKey: 'content.zodiac.libra.shadow',
    loveStyleKey: 'content.zodiac.libra.loveStyle',
    careerVectorKey: 'content.zodiac.libra.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.scorpio,
    dateRangeKey: 'content.zodiac.scorpio.dateRange',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 8,
    keywordKeys: [
      'content.zodiac.scorpio.keyword.0',
      'content.zodiac.scorpio.keyword.1',
      'content.zodiac.scorpio.keyword.2',
    ],
    archetypeKey: 'content.zodiac.scorpio.archetype',
    shadowKey: 'content.zodiac.scorpio.shadow',
    loveStyleKey: 'content.zodiac.scorpio.loveStyle',
    careerVectorKey: 'content.zodiac.scorpio.careerVector',
    coRuler: PlanetId.mars,
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.sagittarius,
    dateRangeKey: 'content.zodiac.sagittarius.dateRange',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 9,
    keywordKeys: [
      'content.zodiac.sagittarius.keyword.0',
      'content.zodiac.sagittarius.keyword.1',
      'content.zodiac.sagittarius.keyword.2',
    ],
    archetypeKey: 'content.zodiac.sagittarius.archetype',
    shadowKey: 'content.zodiac.sagittarius.shadow',
    loveStyleKey: 'content.zodiac.sagittarius.loveStyle',
    careerVectorKey: 'content.zodiac.sagittarius.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.capricorn,
    dateRangeKey: 'content.zodiac.capricorn.dateRange',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 10,
    keywordKeys: [
      'content.zodiac.capricorn.keyword.0',
      'content.zodiac.capricorn.keyword.1',
      'content.zodiac.capricorn.keyword.2',
    ],
    archetypeKey: 'content.zodiac.capricorn.archetype',
    shadowKey: 'content.zodiac.capricorn.shadow',
    loveStyleKey: 'content.zodiac.capricorn.loveStyle',
    careerVectorKey: 'content.zodiac.capricorn.careerVector',
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.aquarius,
    dateRangeKey: 'content.zodiac.aquarius.dateRange',
    polarity: ZodiacPolarity.yang,
    houseAffinity: 11,
    keywordKeys: [
      'content.zodiac.aquarius.keyword.0',
      'content.zodiac.aquarius.keyword.1',
      'content.zodiac.aquarius.keyword.2',
    ],
    archetypeKey: 'content.zodiac.aquarius.archetype',
    shadowKey: 'content.zodiac.aquarius.shadow',
    loveStyleKey: 'content.zodiac.aquarius.loveStyle',
    careerVectorKey: 'content.zodiac.aquarius.careerVector',
    coRuler: PlanetId.saturn,
  ),
  ZodiacSignEntry(
    sign: ZodiacSign.pisces,
    dateRangeKey: 'content.zodiac.pisces.dateRange',
    polarity: ZodiacPolarity.yin,
    houseAffinity: 12,
    keywordKeys: [
      'content.zodiac.pisces.keyword.0',
      'content.zodiac.pisces.keyword.1',
      'content.zodiac.pisces.keyword.2',
    ],
    archetypeKey: 'content.zodiac.pisces.archetype',
    shadowKey: 'content.zodiac.pisces.shadow',
    loveStyleKey: 'content.zodiac.pisces.loveStyle',
    careerVectorKey: 'content.zodiac.pisces.careerVector',
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
