/// Domain model for a single Tarot card. Pure Dart — no Flutter imports.
enum Arcana { major, minor }

enum Suit { wands, cups, swords, pentacles }

enum Element { fire, water, air, earth }

extension ElementX on Element {
  String get label => switch (this) {
        Element.fire => 'Fire',
        Element.water => 'Water',
        Element.air => 'Air',
        Element.earth => 'Earth',
      };

  String get glyph => switch (this) {
        Element.fire => '△',
        Element.water => '▽',
        Element.air => '◇',
        Element.earth => '□',
      };

  String get trait => switch (this) {
        Element.fire => 'Will / Drive',
        Element.water => 'Emotion / Intuition',
        Element.air => 'Mind / Conflict',
        Element.earth => 'Matter / Resource',
      };
}

extension SuitX on Suit {
  String get label => switch (this) {
        Suit.wands => 'Wands',
        Suit.cups => 'Cups',
        Suit.swords => 'Swords',
        Suit.pentacles => 'Pentacles',
      };

  Element get element => switch (this) {
        Suit.wands => Element.fire,
        Suit.cups => Element.water,
        Suit.swords => Element.air,
        Suit.pentacles => Element.earth,
      };
}

class TarotCard {
  final int id; // 0..77 — stable identity
  final String name; // "The Fool", "Ace of Wands"
  final Arcana arcana;
  final Suit? suit; // null for major arcana
  final int number; // 0..21 major (The Fool = 0), 1..14 minor (Ace..King)
  final Element element;
  final List<String> keywords; // 3 archetype keywords
  final String upright; // one-sentence psychological meaning
  final String reversed; // one-sentence shadow meaning
  final String socratic; // sharp one-sentence question

  const TarotCard({
    required this.id,
    required this.name,
    required this.arcana,
    required this.suit,
    required this.number,
    required this.element,
    required this.keywords,
    required this.upright,
    required this.reversed,
    required this.socratic,
  });

  static const List<String> _roman = [
    '0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI',
    'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX', 'XXI',
  ];

  static const List<String> _ranks = [
    'Ace', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Page', 'Knight', 'Queen', 'King',
  ];

  /// "XIII" for majors, "Ace".."King" for minors.
  String get positionLabel =>
      arcana == Arcana.major ? _roman[number] : _ranks[number - 1];
}
