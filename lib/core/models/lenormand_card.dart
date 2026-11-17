import 'tarot_card_model.dart';

/// The traditional French playing-card inset suit of a Petit Lenormand
/// card (the 36 cards each carry a standard playing card — 9 of each suit).
enum PlayingCardSuit { hearts, diamonds, clubs, spades }

extension PlayingCardSuitX on PlayingCardSuit {
  String get label => switch (this) {
        PlayingCardSuit.hearts => 'Hearts',
        PlayingCardSuit.diamonds => 'Diamonds',
        PlayingCardSuit.clubs => 'Clubs',
        PlayingCardSuit.spades => 'Spades',
      };

  String get glyph => switch (this) {
        PlayingCardSuit.hearts => '♥',
        PlayingCardSuit.diamonds => '♦',
        PlayingCardSuit.clubs => '♣',
        PlayingCardSuit.spades => '♠',
      };

  /// Hearts read emotional matters, Diamonds practical/material,
  /// Clubs work and growth, Spades challenge and obstacles.
  String get domain => switch (this) {
        PlayingCardSuit.hearts => 'Emotion / Heart',
        PlayingCardSuit.diamonds => 'Matter / Resource',
        PlayingCardSuit.clubs => 'Work / Growth',
        PlayingCardSuit.spades => 'Challenge / Obstacle',
      };
}

/// One authentic Petit Lenormand card (1 Rider .. 36 Cross). Pure Dart.
///
/// Lenormand cards are ALWAYS upright — there is no reversed meaning in
/// the tradition, so this model deliberately has no `reversed` field.
class LenormandCard {
  const LenormandCard({
    required this.number,
    required this.name,
    required this.playingCard,
    required this.inset,
    required this.element,
    required this.keywords,
    required this.meaning,
    required this.combinations,
    required this.timing,
  });

  /// 1..36 — the canonical Petit Lenormand order.
  final int number;
  final String name;

  /// The traditional playing-card inset, e.g. '9♥' (9 of Hearts).
  final PlayingCardSuit playingCard;
  final String inset;

  /// Elemental affinity used by the Fate Threads and the Oracle alchemy.
  final Element element;

  /// 3 archetype keywords.
  final List<String> keywords;

  /// One-sentence traditional meaning (always upright).
  final String meaning;

  /// Authentic combinatory meanings: what this card adds to the cards
  /// sitting beside it (Lenormand is read in pairs).
  final List<String> combinations;

  /// Traditional timing / polarity note, e.g. 'Soon', 'Slow', 'Now'.
  final String timing;

  /// Stable identity used by serialization: number - 1 (0..35).
  int get id => number - 1;

  /// '9♥' — the playing-card inset label shown on the card face.
  String get insetLabel => inset;

  /// 'HEARTS · EMOTION / HEART' — the suit category line for filters.
  String get suitLine =>
      '${playingCard.label.toUpperCase()} · ${playingCard.domain.toUpperCase()}';
}
