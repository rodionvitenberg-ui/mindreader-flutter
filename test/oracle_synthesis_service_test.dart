import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';

TarotCard byName(String name) => tarotDeck.firstWhere((c) => c.name == name);

DealtCardSlot slot(
  int i,
  TarotCard card, {
  SlotState state = SlotState.faceUp,
  String? role,
}) {
  final s = DealtCardSlot(index: i, role: role ?? 'Role $i');
  s.placeCardFaceUp(card, false);
  s.state = state;
  return s;
}

void main() {
  group('dignityBetween', () {
    test('same element → harmony', () {
      expect(
        dignityBetween(byName('Ace of Wands'), byName('Two of Wands')),
        ThreadTone.harmony,
      );
    });

    test('water + earth → harmony', () {
      expect(
        dignityBetween(byName('Ace of Cups'), byName('Ace of Pentacles')),
        ThreadTone.harmony,
      );
    });

    test('fire + water → conflict', () {
      expect(
        dignityBetween(byName('Ace of Wands'), byName('Ace of Cups')),
        ThreadTone.conflict,
      );
    });

    test('air + fire → conflict', () {
      expect(
        dignityBetween(byName('Ace of Swords'), byName('Ace of Wands')),
        ThreadTone.conflict,
      );
    });

    test('air + water → neutral', () {
      expect(
        dignityBetween(byName('Ace of Swords'), byName('Ace of Cups')),
        ThreadTone.neutral,
      );
    });
  });

  group('computeThreads', () {
    test('threads only between adjacent face-up slots', () {
      final slots = [
        slot(0, byName('Ace of Wands')),
        slot(1, byName('Ace of Cups')),
        slot(2, byName('Ace of Swords'), state: SlotState.faceDown),
        slot(3, byName('Ace of Pentacles')),
      ];
      final threads = computeThreads(slots);
      expect(threads.length, 1); // 2-3 is blocked by the face-down card
      expect(threads.single.from, 0);
      expect(threads.single.to, 1);
      expect(threads.single.tone, ThreadTone.conflict);
    });

    test('no threads when nothing is face-up', () {
      final slots = [
        slot(0, byName('Ace of Wands'), state: SlotState.faceDown),
        slot(1, byName('Ace of Cups'), state: SlotState.faceDown),
      ];
      expect(computeThreads(slots), isEmpty);
    });
  });

  group('synthesizeSpread', () {
    test('empty spread asks to flip a card', () {
      final slots = [DealtCardSlot(index: 0, role: 'Daily Anchor')];
      expect(
        synthesizeSpread(slots, SpreadType.one),
        contains('Flip at least one card'),
      );
    });

    test('full spread mentions cards, roles and elemental balance', () {
      final roles = SpreadType.three.slotRoles;
      final slots = [
        slot(0, byName('The Fool'), role: roles[0]),
        slot(1, byName('The High Priestess'), role: roles[1]),
        slot(2, byName('The Magician'), role: roles[2]),
      ];
      final text = synthesizeSpread(slots, SpreadType.three,
          contextChip: 'Career & Path');
      expect(text, contains('The Fool'));
      expect(text, contains('Current State / Essence'));
      expect(text, contains('Career & Path'));
      expect(text, contains('Between the cards'));
      expect(text, contains('The question to sit with'));
    });
  });
}
