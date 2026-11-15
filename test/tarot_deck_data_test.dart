import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';

void main() {
  test('deck has exactly 78 cards with unique ids 0..77', () {
    expect(tarotDeck.length, 78);
    final ids = tarotDeck.map((c) => c.id).toList();
    expect(ids.toSet().length, 78);
    expect(ids, List.generate(78, (i) => i));
  });

  test('arcana split: 22 major + 56 minor, 14 per suit', () {
    expect(tarotDeck.where((c) => c.arcana == Arcana.major).length, 22);
    expect(tarotDeck.where((c) => c.arcana == Arcana.minor).length, 56);
    for (final suit in Suit.values) {
      expect(tarotDeck.where((c) => c.suit == suit).length, 14);
    }
  });

  test('minor arcana element matches its suit', () {
    for (final c in tarotDeck.where((c) => c.arcana == Arcana.minor)) {
      expect(c.element, c.suit!.element, reason: c.name);
    }
  });

  test('every card has non-empty copy: keywords, meanings, socratic', () {
    for (final c in tarotDeck) {
      expect(c.name, isNotEmpty);
      expect(c.keywords.length, greaterThanOrEqualTo(2), reason: c.name);
      expect(c.upright, isNotEmpty, reason: c.name);
      expect(c.reversed, isNotEmpty, reason: c.name);
      expect(c.socratic, isNotEmpty, reason: c.name);
    }
  });

  test('position labels: Fool=0, majors roman, minors rank', () {
    expect(tarotDeck[0].positionLabel, '0');
    expect(tarotDeck[1].positionLabel, 'I');
    expect(tarotDeck[21].positionLabel, 'XXI');
    expect(tarotDeck[22].positionLabel, 'Ace');
    expect(tarotDeck[77].positionLabel, 'King');
  });
}
