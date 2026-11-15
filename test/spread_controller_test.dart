import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/state/spread_controller.dart';

void main() {
  test('shuffleDeck is a permutation of all 78 cards', () {
    final c = SpreadController(random: Random(42));
    expect(c.deckOrder.length, 78);
    expect(c.deckOrder.toSet().length, 78);
    final c2 = SpreadController(random: Random(43));
    expect(c2.deckOrder, isNot(equals(c.deckOrder)));
  });

  test('dealing fills slots in order, face down, then refuses when full',
      () {
    final c = SpreadController(random: Random(1));
    expect(c.spreadType, SpreadType.three);
    expect(c.slots.length, 3);

    for (var i = 0; i < 3; i++) {
      final idx = c.dealNextCard();
      expect(idx, i);
      expect(c.slots[i].state, SlotState.faceDown);
      expect(c.slots[i].card, isNotNull);
    }
    expect(c.allDealt, isTrue);
    expect(c.dealNextCard(), isNull);
  });

  test('dealt cards come from the shuffled deck top', () {
    final c = SpreadController(random: Random(2));
    c.dealNextCard();
    expect(c.slots[0].card!.id, c.deckOrder[0]);
  });

  test('flipSlot reveals face-up only from face-down', () {
    final c = SpreadController(random: Random(3));
    c.dealNextCard();
    expect(c.slots[0].state, SlotState.faceDown);
    c.flipSlot(0);
    expect(c.slots[0].state, SlotState.faceUp);
    c.flipSlot(0); // idempotent
    expect(c.slots[0].state, SlotState.faceUp);
  });

  test('setSpreadType resets slots with the right roles', () {
    final c = SpreadController(random: Random(4));
    c.dealNextCard();
    c.setSpreadType(SpreadType.seven);
    expect(c.slots.length, 7);
    expect(c.slots.every((s) => s.state == SlotState.empty), isTrue);
    expect(c.slots[0].role, 'The Heart of the Matter');
    expect(c.slots[6].role, 'The Outcome');
  });

  test('loadScannedSpreadFaceUp materializes everything face-up', () {
    final c = SpreadController(random: Random(5));
    final scanned = [
      (tarotDeck[0], false),
      (tarotDeck[13], true),
      (tarotDeck[50], false),
    ];
    c.loadScannedSpreadFaceUp(scanned);
    expect(c.spreadType, SpreadType.three);
    expect(c.allFaceUp, isTrue);
    expect(c.slots[0].card!.name, 'The Fool');
    expect(c.slots[1].card!.name, 'Death');
    expect(c.slots[1].isReversed, isTrue);
  });

  test('buildHistoryEntry serializes the completed spread', () {
    final c = SpreadController(random: Random(6));
    for (var i = 0; i < 3; i++) {
      c.dealNextCard();
    }
    final entry = c.buildHistoryEntry(synthesis: 'test synthesis');
    expect(entry['synthesis'], 'test synthesis');
    expect((entry['cards'] as List).length, 3);
    expect(entry['spreadType'], 'three');
    expect(entry['timestamp'], isNotEmpty);
  });
}
