/// Domain model for a single Tarot card. Pure Dart — no Flutter imports.
library;

import '../l10n/app_strings.dart';

enum Arcana { major, minor }

enum Suit { wands, cups, swords, pentacles }

enum Element { fire, water, air, earth }

extension ElementX on Element {
  String get label => AppStrings.g('content.element.$name.label');

  String get glyph => switch (this) {
    Element.fire => '△',
    Element.water => '▽',
    Element.air => '◇',
    Element.earth => '▫',
  };

  String get trait => AppStrings.g('content.element.$name.trait');
}

extension SuitX on Suit {
  String get label => AppStrings.g('content.suit.$name.label');

  Element get element => switch (this) {
    Suit.wands => Element.fire,
    Suit.cups => Element.water,
    Suit.swords => Element.air,
    Suit.pentacles => Element.earth,
  };
}

class TarotCard {
  final int id; // 0..77 — stable identity
  final String nameKey; // dictionary key, e.g. content.tarot.0.name
  final Arcana arcana;
  final Suit? suit; // null for major arcana
  final int number; // 0..21 major (The Fool = 0), 1..14 minor (Ace..King)
  final Element element;
  final List<String> keywordKeys; // 3 archetype keyword keys
  final String uprightKey; // one-sentence psychological meaning key
  final String reversedKey; // one-sentence shadow meaning key
  final String socraticKey; // sharp one-sentence question key

  const TarotCard({
    required this.id,
    required this.nameKey,
    required this.arcana,
    required this.suit,
    required this.number,
    required this.element,
    required this.keywordKeys,
    required this.uprightKey,
    required this.reversedKey,
    required this.socraticKey,
  });

  String get name => AppStrings.g(nameKey);
  List<String> get keywords => [
    for (final key in keywordKeys) AppStrings.g(key),
  ];
  String get upright => AppStrings.g(uprightKey);
  String get reversed => AppStrings.g(reversedKey);
  String get socratic => AppStrings.g(socraticKey);

  static const List<String> _roman = [
    '0',
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
    'XIII',
    'XIV',
    'XV',
    'XVI',
    'XVII',
    'XVIII',
    'XIX',
    'XX',
    'XXI',
  ];

  /// "XIII" for majors, "Ace".."King" for minors.
  String get positionLabel => arcana == Arcana.major
      ? _roman[number]
      : AppStrings.g('content.tarot.rank.${number - 1}');
}
