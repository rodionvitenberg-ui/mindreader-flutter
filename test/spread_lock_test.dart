import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/state/spread_controller.dart';

void main() {
  group('authentic base card limits & canonical roles', () {
    test('every spread type carries its canonical slot count', () {
      expect(SpreadType.one.cardCount, 1);
      expect(SpreadType.three.cardCount, 3);
      expect(SpreadType.four.cardCount, 4);
      expect(SpreadType.seven.cardCount, 7);
    });

    test('canonical slot role definitions per spread', () {
      expect(SpreadType.one.slotRoles, ['Core Daily Impulse']);
      expect(SpreadType.three.slotRoles, [
        'Current State / Essence',
        'Hidden Shadow / Block',
        'Vector / Action',
      ]);
      expect(SpreadType.four.slotRoles, [
        'Your Shore',
        'The Other / Environment',
        'What Bridges or Blocks',
        'Turning Point',
      ]);
      expect(SpreadType.seven.slotRoles, [
        'Past',
        'Present',
        'Hidden Influences',
        'Obstacle',
        'External Forces',
        'Advice',
        'Outcome',
      ]);
    });

    test('baseCardLimit follows the active spread', () {
      final c = SpreadController(random: Random(1));
      expect(c.baseCardLimit, 3);
      c.setSpreadType(SpreadType.seven);
      expect(c.baseCardLimit, 7);
      c.setSpreadType(SpreadType.one);
      expect(c.baseCardLimit, 1);
    });
  });

  group('deal lock after the base cards', () {
    test('Triad locks exactly at 3 cards', () {
      final c = SpreadController(random: Random(2));
      expect(c.isDealLocked, isFalse);
      c.dealNextCard();
      c.dealNextCard();
      expect(c.isDealLocked, isFalse);
      c.dealNextCard();
      expect(c.dealtCount, 3);
      expect(c.isDealLocked, isTrue);
      // No further deals: neither the plain deal nor the clarifier gate.
      expect(c.dealNextCard(), isNull);
      expect(c.dealNextCardOrClarifier(), isNull);
      expect(c.dealCardAtOrClarifier(0), isNull);
    });

    test('every spread type locks at its canonical count', () {
      for (final type in SpreadType.values) {
        final c = SpreadController(random: Random(type.index));
        c.setSpreadType(type);
        for (var i = 0; i < type.cardCount; i++) {
          expect(c.dealNextCard(), i);
        }
        expect(c.dealtCount, type.cardCount);
        expect(c.isDealLocked, isTrue);
        expect(c.dealNextCardOrClarifier(), isNull);
      }
    });
  });

  group('additional cards', () {
    test('manual draws wait for the previous card to be revealed', () {
      final c = SpreadController(random: Random(3));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      final first = c.deckTop.first.id;
      expect(c.dealNextCardOrClarifier(), 3);
      expect(c.slots[3].card!.id, first);
      expect(c.slots[3].state, SlotState.faceDown);
      expect(c.slots[3].oracleQuestion, isNull);
      expect(c.isDealLocked, isTrue);
      expect(c.drawOracleClarifier('Too soon?'), isNull);
      expect(c.dealNextCardOrClarifier(), isNull);
      c.flipSlot(3);
      expect(c.dealNextCardOrClarifier(), 4);
    });

    test('Oracle draws and reveals the top card in one notification', () {
      final c = SpreadController(random: Random(4));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      final top = c.deckTop.first.id;
      var notifications = 0;
      c.addListener(() {
        notifications++;
        expect(c.slots[3].state, SlotState.faceUp);
        expect(c.slots[3].oracleQuestion, 'Next step?');
        expect(c.remaining, 74);
      });
      expect(c.drawOracleClarifier('Next step?'), 3);
      expect(notifications, 1);
      expect(c.slots[3].card!.id, top);
      expect(c.ledgerTotal, 78);
    });

    for (final baseCount in [3, 12]) {
      test('$baseCount base cards can extend to 15 and no further', () {
        final c = SpreadController(random: Random(baseCount));
        if (baseCount == 12) {
          c.setCustomSpread(
            CustomSpreadConfig.fromQuestions(
              questions: [for (var i = 1; i <= baseCount; i++) 'Question $i?'],
            ),
          );
        }
        expect(c.baseCardLimit, baseCount);
        expect(c.maxCardsForCurrentSpread, 15);
        for (var i = 0; i < 15; i++) {
          if (i > baseCount && i.isOdd) {
            expect(c.drawOracleClarifier('Follow-up $i?'), i);
          } else {
            expect(c.dealNextCardOrClarifier(), i);
            c.flipSlot(i);
          }
        }
        expect(c.clarifierCount, 15 - baseCount);
        expect(c.isDealLocked, isTrue);
        expect(c.dealNextCardOrClarifier(), isNull);
        expect(c.drawOracleClarifier('One more?'), isNull);
        expect(c.requestClarifierScan('Physical one more?'), isFalse);
        expect(c.ledgerTotal, 78);
      });
    }

    test(
      'restoring a digital table preserves its unrevealed card and deck ledger',
      () {
        final c = SpreadController(random: Random(15));
        for (var i = 0; i < 3; i++) {
          c.dealNextCard();
          c.flipSlot(i);
        }
        c.dealNextCardOrClarifier();
        final cards = [
          for (final s in c.slots)
            (
              cardId: s.card!.id,
              reversed: s.isReversed,
              role: s.role,
              userContext: s.userContext,
            ),
        ];
        c.restoreSpread(
          system: DivinationSystem.tarot,
          type: SpreadType.three,
          cards: cards,
          sessionNotes: const [],
          physicalCards: const {},
          faceDownCards: const {3},
          sourceMode: TableSourceMode.digitalDeck,
        );
        expect(c.remaining, 74);
        expect(c.ledgerTotal, 78);
        expect(c.slots[3].state, SlotState.faceDown);
        expect(c.isDealLocked, isTrue);
        expect(
          c.remainingDeck.map((card) => card.id),
          isNot(contains(cards[3].cardId)),
        );
        c.flipSlot(3);
        expect(c.dealNextCardOrClarifier(), 4);
      },
    );

    test(
      'a camera reservation at 14 cards consumes the same final position',
      () {
        final c = SpreadController(random: Random(9));
        for (var i = 0; i < 14; i++) {
          c.dealNextCardOrClarifier();
          c.flipSlot(i);
        }
        final remaining = c.remaining;
        expect(c.requestClarifierScan('Camera?'), isTrue);
        expect(c.dealNextCardOrClarifier(), isNull);
        expect(c.drawOracleClarifier('Digital?'), isNull);
        final card = (c.slots[0].card! as TarotDivinationCard).card;
        expect(c.completeClarifierScan(card, false), 14);
        expect(c.completeClarifierScan(card, false), isNull);
        expect(c.remaining, remaining);
        expect(c.dealtCount, 15);
      },
    );
  });

  group('AI-generated clarifier suggestions', () {
    List<DealtCardSlot> slotsOf(SpreadController c) => [
      for (final s in c.slots)
        if (s.card != null) s,
    ];

    test('2-3 questions dynamically reference the actual cards', () {
      final c = SpreadController(random: Random(10));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      final suggestions = buildClarifierSuggestions(slotsOf(c));
      expect(suggestions.length, 3);
      // The first probe names a real card on the table.
      final tableNames = [for (final s in slotsOf(c)) s.card!.name];
      expect(
        suggestions.first,
        anyOf([for (final name in tableNames) contains(name)]),
      );
      // A reversed card on the table is referenced as (Reversed).
      if (slotsOf(c).any((s) => s.isReversed)) {
        expect(suggestions.any((q) => q.contains('(Reversed)')), isTrue);
      }
    });

    test('conflict threads name the two tensioned cards', () {
      final c = SpreadController(random: Random(11));
      c.setSpreadType(SpreadType.four);
      for (var i = 0; i < 4; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      final conflict = [
        for (final t in computeThreads(c.slots))
          if (t.tone == ThreadTone.conflict) t,
      ];
      final suggestions = buildClarifierSuggestions(slotsOf(c));
      if (conflict.isNotEmpty) {
        final t = conflict.first;
        final a = c.slots[t.from].card!.name;
        final b = c.slots[t.to].card!.name;
        expect(
          suggestions,
          contains(
            'What concrete action resolves the elemental tension '
            'between $a and $b?',
          ),
        );
      }
    });

    test('suggestions stop at the total table ceiling', () {
      final c = SpreadController(random: Random(12));
      for (var i = 0; i < 15; i++) {
        c.dealNextCardOrClarifier();
        c.flipSlot(i);
      }
      expect(c.dealtCount, c.maxCardsForCurrentSpread);
      expect(
        buildClarifierSuggestions(c.slots, hardMax: c.maxCardsForCurrentSpread),
        isEmpty,
      );
    });

    test('suggestions are empty on an empty table', () {
      final c = SpreadController(random: Random(13));
      expect(buildClarifierSuggestions(c.slots), isEmpty);
    });
  });
}
