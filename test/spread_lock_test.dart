import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/state/spread_controller.dart';

/// Sprint 3/3: authentic spread caps, the Deal Lock after the base cards,
/// the question-driven +1 Clarifier unlock loop and the hard 10-card
/// table ceiling.
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
      expect(c.allowedCardsLimit, 3);
      c.dealNextCard();
      c.dealNextCard();
      expect(c.isDealLocked, isFalse);
      c.dealNextCard();
      expect(c.dealtCount, 3);
      expect(c.isDealLocked, isTrue);
      expect(c.allowedCardsLimit, 3);
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

  group('+1 clarifier unlock loop', () {
    test('allowedCardsLimit = dealtCount + 1 while armed', () {
      final c = SpreadController(random: Random(3));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      expect(c.allowedCardsLimit, 3);
      c.armClarifierQuestion('What is hidden?');
      expect(c.allowedCardsLimit, 4);
      c.dealNextCardOrClarifier();
      expect(c.allowedCardsLimit, 3); // relocked
      expect(c.isDealLocked, isTrue);
    });

    test('the armed question lands on the clarifier slot', () {
      final c = SpreadController(random: Random(4));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      c.armClarifierQuestion('What concrete step should I take?');
      final idx = c.dealNextCardOrClarifier();
      expect(idx, 3);
      expect(c.slots[3].role, 'Clarifier 1');
      expect(
        c.slots[3].userContext,
        '"What concrete step should I take?"',
      );
    });

    test('cancelling an armed question relocks the deck', () {
      final c = SpreadController(random: Random(5));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      c.armClarifierQuestion('What is hidden?');
      expect(c.isDealLocked, isFalse);
      c.cancelClarifierScan();
      expect(c.pendingClarifierQuestion, isNull);
      expect(c.isDealLocked, isTrue);
      expect(c.dealNextCardOrClarifier(), isNull);
    });

    test('restored sessions are locked until a new question is armed', () {
      final c = SpreadController(random: Random(6));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
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
      );
      expect(c.dealtCount, 3);
      expect(c.isDealLocked, isTrue);
      c.armClarifierQuestion('Deepen the outcome?');
      expect(c.isDealLocked, isFalse);
      expect(c.allowedCardsLimit, 4);
    });

  group('12-position base limit & separate 3-clarifier ceiling', () {
    test('the 4th clarifier is refused: max 3 clarifiers above base spread',
        () {
      final c = SpreadController(random: Random(7));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      // Three armed clarifiers reach the separate clarifier ceiling (3 + 3 = 6).
      for (var i = 0; i < SpreadController.maxClarifierCards; i++) {
        expect(c.armClarifierQuestion('Clarifier ${i + 1}?'), isTrue);
        final idx = c.dealNextCardOrClarifier();
        expect(idx, 3 + i);
        expect(c.slots[3 + i].role, 'Clarifier ${i + 1}');
      }
      expect(c.clarifierCount, SpreadController.maxClarifierCards);
      expect(c.dealtCount, 6);
      expect(c.isClarifierLimitReached, isTrue);
      expect(c.isDealLocked, isTrue);
      // Arming fails: the clarifier cap is permanent for this reading.
      expect(c.armClarifierQuestion('One more?'), isFalse);
      expect(c.pendingClarifierQuestion, isNull);
      // No deal path can add a 4th clarifier.
      expect(c.dealNextCardOrClarifier(), isNull);
      expect(c.dealCardAtOrClarifier(0), isNull);
      expect(c.allowedCardsLimit, 6);
    });

    test('12-position custom spread deals all 12 base cards + up to 3 clarifiers',
        () {
      final c = SpreadController(random: Random(8));
      c.setCustomSpread(
        CustomSpreadConfig.fromQuestions(
          questions: [for (var i = 1; i <= 12; i++) 'Question $i?'],
          name: 'Year Ahead',
        ),
      );
      expect(c.baseCardLimit, 12);
      expect(c.maxCardsForCurrentSpread, 15);
      for (var i = 0; i < 12; i++) {
        expect(c.dealNextCardOrClarifier(), i);
        c.flipSlot(i);
      }
      expect(c.dealtCount, 12);
      expect(c.initialSpreadAllFaceUp, isTrue);
      expect(c.isDealLocked, isTrue);

      for (var i = 0; i < 3; i++) {
        expect(c.armClarifierQuestion('Follow-up ${i + 1}?'), isTrue);
        expect(c.allowedCardsLimit, 13 + i);
        expect(c.dealNextCardOrClarifier(), 12 + i);
      }
      expect(c.dealtCount, SpreadController.maxTableCards); // 15
      expect(c.isClarifierLimitReached, isTrue);
      expect(c.armClarifierQuestion('4th clarifier?'), isFalse);
    });

    test('camera clarifier scan is refused once 3 clarifiers are reached', () {
      final c = SpreadController(random: Random(9));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      for (var i = 0; i < SpreadController.maxClarifierCards; i++) {
        c.armClarifierQuestion('Q$i?');
        c.dealNextCardOrClarifier();
      }
      expect(c.isClarifierLimitReached, isTrue);
      c.requestClarifierScan('Physical one more?');
      expect(c.pendingClarifierQuestion, isNull); // refused at clarifier cap
      // No armed question → no camera slot can be appended.
      expect(
        c.completeClarifierScan(
          (c.slots[0].card! as TarotDivinationCard).card,
          false,
        ),
        isNull,
      );
    });
  });

  group('AI-generated clarifier suggestions', () {
    List<DealtCardSlot> slotsOf(SpreadController c) =>
        [for (final s in c.slots) if (s.card != null) s];

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
          contains('What concrete action resolves the elemental tension '
              'between $a and $b?'),
        );
      }
    });

    test('suggestions stop at the reading clarifier ceiling', () {
      final c = SpreadController(random: Random(12));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      for (var i = 0; i < SpreadController.maxClarifierCards; i++) {
        c.armClarifierQuestion('Q$i?');
        c.dealNextCardOrClarifier();
      }
      expect(c.dealtCount, c.maxCardsForCurrentSpread);
      expect(
        buildClarifierSuggestions(
          c.slots,
          hardMax: c.maxCardsForCurrentSpread,
        ),
        isEmpty,
      );
    });

    test('suggestions are empty on an empty table', () {
      final c = SpreadController(random: Random(13));
      expect(buildClarifierSuggestions(c.slots), isEmpty);
    });
  });

  });
}