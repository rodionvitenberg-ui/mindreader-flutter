import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
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
    final before = c.deckOrder; // snapshot: the stack order before the deal
    c.dealNextCard();
    expect(c.slots[0].card!.id, before[0]);
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

  test('remainingDeck exposes the full 78-card stack and depletes on deal',
      () {
    final c = SpreadController(random: Random(11));
    expect(c.totalCards, 78);
    expect(c.remaining, 78);
    expect(c.remainingDeck.length, 78);
    c.dealNextCard();
    expect(c.remaining, 77);
    expect(c.remainingDeck.length, 77);
    // The dealt card left the physical stack.
    final dealtId = c.slots[0].card!.id;
    expect(c.remainingDeck.any((t) => t.$1.id == dealtId), isFalse);
  });

  test('weaveShuffleRemaining permutes only the remaining stack', () {
    final c = SpreadController(random: Random(12));
    c.dealNextCard();
    final dealtId = c.slots[0].card!.id;
    final before = [for (final t in c.remainingDeck) t.$1.id];

    var changed = false;
    for (var i = 0; i < 40; i++) {
      c.weaveShuffleRemaining();
      final after = [for (final t in c.remainingDeck) t.$1.id];
      expect(after.toSet(), equals(before.toSet())); // same cards, new order
      if (!listEquals(after, before)) changed = true;
    }
    expect(changed, isTrue); // the secure RNG actually moved cards
    expect(c.slots[0].card!.id, dealtId); // dealt card untouched
    expect(c.remaining, 77); // depletion preserved
  });

  test('dealCardAt extracts any exposed card from the shuffled deck', () {
    final c = SpreadController(random: Random(21));
    final before = List<int>.from(c.deckOrder);
    // Grab the 5th card down from the top (a middle layer of the fan).
    final grabbedId = before[5];
    expect(c.dealCardAt(5), 0);
    expect(c.slots[0].card!.id, grabbedId);
    expect(c.slots[0].state, SlotState.faceDown);
    expect(c.remaining, 77);
    // The grabbed card left the stack; the order of the rest is preserved.
    expect(
      List<int>.from(c.deckOrder),
      equals([...before.take(5), ...before.skip(6)]),
    );
  });

  test('dealCardAt refuses out-of-range depths and a full spread', () {
    final c = SpreadController(random: Random(22));
    expect(c.dealCardAt(-1), isNull);
    expect(c.dealCardAt(999), isNull);
    for (var i = 0; i < 3; i++) {
      expect(c.dealCardAt(0), i);
    }
    expect(c.dealCardAt(0), isNull); // spread is full
    expect(c.remaining, 75);
  });

  test('dealCardAt honours depletion with reversed orientation', () {
    final c = SpreadController(random: Random(23));
    final depth = 2;
    final grabbedReversed = c.remainingDeck[depth].$2;
    c.dealCardAt(depth);
    expect(c.slots[0].isReversed, grabbedReversed);
  });

  test('totalCards configures the physical stack size', () {
    final c = SpreadController(random: Random(13), totalCards: 22);
    expect(c.totalCards, 22);
    expect(c.remaining, 22);
    expect(c.remainingDeck.length, 22);
    // 3-card spread: 3 deals succeed, then the table is full.
    expect(c.dealNextCard(), 0);
    expect(c.dealNextCard(), 1);
    expect(c.dealNextCard(), 2);
    expect(c.remaining, 19);
    expect(c.remainingDeck.length, 19);
    expect(c.dealNextCard(), isNull); // spread is full
  });

  test('resetTable returns dealt cards to the deck: ledger stays 78', () {
    final c = SpreadController(random: Random(31));
    final dealtIds = <int>[];
    for (var i = 0; i < 3; i++) {
      expect(c.dealNextCard(), i);
      dealtIds.add(c.slots[i].card!.id);
    }
    // Cards left the stack...
    expect(c.remaining, 75);
    expect(c.dealtCount, 3);
    expect(c.ledgerTotal, 78); // invariant holds mid-spread
    expect(c.remainingDeck.any((t) => dealtIds.contains(t.$1.id)), isFalse);

    // ...and the badge reset physically re-inserts ALL of them.
    c.resetTable();
    expect(c.remaining, 78);
    expect(c.dealtCount, 0);
    expect(c.ledgerTotal, 78);
    expect(c.remainingDeck.length, 78);
    expect(c.slots.every((s) => s.state == SlotState.empty), isTrue);
  });

  test('setSpreadType restores the full 78-card deck (no lost cards)', () {
    final c = SpreadController(random: Random(32));
    for (var i = 0; i < 3; i++) {
      c.dealNextCard();
    }
    expect(c.remaining, 75);
    c.setSpreadType(SpreadType.seven);
    expect(c.slots.length, 7);
    expect(c.remaining, 78);
    expect(c.ledgerTotal, 78);
    expect(c.remainingDeck.length, 78);
    // The restored deck is still a full permutation of all 78 cards.
    expect(c.deckOrder.toSet().length, 78);
  });

  test('ledger invariant holds through deals, weaves and resets', () {
    final c = SpreadController(random: Random(33));
    expect(c.ledgerTotal, 78);
    c.dealCardAt(4);
    expect(c.ledgerTotal, 78);
    for (var i = 0; i < 30; i++) {
      c.weaveShuffleRemaining();
    }
    expect(c.ledgerTotal, 78);
    c.dealNextCard();
    c.dealNextCard();
    expect(c.ledgerTotal, 78);
    c.resetTable();
    expect(c.ledgerTotal, 78);
    c.setSpreadType(SpreadType.four);
    expect(c.ledgerTotal, 78);
  });
}
