import 'dart:math';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/intention_prompts.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/features/digital_table/widgets/elemental_threads_painter.dart';
import 'package:mindreader/state/spread_controller.dart';

/// Phase 2 domain tests: pre-draw intentions, endless clarifiers, the
/// structured synthesis payload, elemental balance and the phygital
/// camera-sync mode.
void main() {
  group('pre-draw intention context', () {
    test('setUserContext composes chip + typed note', () {
      final slot = DealtCardSlot(index: 0, role: 'Current State');
      slot.setUserContext(chip: 'Inner Doubt', text: 'my own words');
      expect(slot.userContext, 'Inner Doubt · "my own words"');
      slot.setUserContext(text: 'just text');
      expect(slot.userContext, '"just text"');
      slot.setUserContext(chip: null, text: '');
      expect(slot.userContext, isNull);
    });

    test('intention prompts: slot questions + 4 zero-friction chips', () {
      final p0 = intentionForSlot(0);
      expect(p0.question, contains('What is on your mind'));
      expect(p0.chips, contains('Relationships & Feelings'));
      expect(p0.chips, contains('Career / Money Crossroads'));
      expect(p0.chips, contains('Inner Doubt'));
      expect(p0.chips, contains('Let the Deck Decide'));
      expect(p0.chips.length, 4);
      // Deeper spreads recycle the prompt list.
      expect(intentionForSlot(7).question, intentionForSlot(0).question);
      // The two fixed clarifier follow-ups exist.
      expect(clarifierFollowUpQuestions, hasLength(2));
    });

    test('dealing stores the intention into the freshly dealt slot', () {
      final c = SpreadController(random: Random(1));
      final idx = c.dealNextCard();
      expect(idx, 0);
      c.setSlotUserContext(idx!, chip: 'Inner Doubt', text: 'about a job');
      expect(c.slots[0].userContext, 'Inner Doubt · "about a job"');
      // Re-setting the context on the same slot never overwrites it.
      c.setSlotUserContext(0, chip: 'Other');
      expect(c.slots[0].userContext, 'Inner Doubt · "about a job"');
    });
  });

  group('locked +1 clarifier loop (sprint 3/3)', () {
    test('deck locks after the base spread; arm unlocks exactly one card',
        () {
      final c = SpreadController(random: Random(2));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      expect(c.remaining, 75);
      expect(c.isDealLocked, isTrue);
      expect(c.dealNextCardOrClarifier(), isNull); // no question armed

      expect(c.armClarifierQuestion('What is the hidden obstacle?'), isTrue);
      expect(c.isDealLocked, isFalse); // exactly +1 unlocked
      expect(c.allowedCardsLimit, 4);
      expect(c.pendingClarifierQuestion, 'What is the hidden obstacle?');

      final idx = c.dealNextCardOrClarifier();
      expect(idx, 3);
      final slot = c.slots[3];
      expect(slot.role, 'Clarifier 1');
      expect(slot.userContext, '"What is the hidden obstacle?"');
      expect(slot.state, SlotState.faceDown);
      expect(slot.card, isNotNull);
      expect(c.remaining, 74);
      expect(c.ledgerTotal, 78); // the digital ledger holds
      // The deck locks again immediately after the single draw.
      expect(c.pendingClarifierQuestion, isNull);
      expect(c.isDealLocked, isTrue);
      expect(c.dealNextCardOrClarifier(), isNull);
    });

    test('armClarifierQuestion requires the base spread complete', () {
      final c = SpreadController(random: Random(3));
      c.dealNextCard();
      expect(c.armClarifierQuestion('Too early?'), isFalse);
      expect(c.armClarifierQuestion('   '), isFalse);
      expect(c.pendingClarifierQuestion, isNull);
      c.dealNextCard();
      c.dealNextCard();
      expect(c.armClarifierQuestion('Now it is fine'), isTrue);
    });

    test('clarifier numbering continues across armed draws', () {
      final c = SpreadController(random: Random(31));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      c.armClarifierQuestion('What is hidden?');
      c.dealNextCardOrClarifier();
      c.armClarifierQuestion('What step should I take?');
      final idx2 = c.dealNextCardOrClarifier();
      expect(idx2, 4);
      expect(c.slots[4].role, 'Clarifier 2');
    });

    test('dealCardAtOrClarifier refuses invalid depths', () {
      final c = SpreadController(random: Random(4));
      expect(c.dealCardAtOrClarifier(-1), isNull);
      expect(c.dealCardAtOrClarifier(999), isNull);
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      c.armClarifierQuestion('What is hidden?');
      expect(c.dealCardAtOrClarifier(-1), isNull);
      expect(c.dealCardAtOrClarifier(999), isNull);
      expect(c.pendingClarifierQuestion, 'What is hidden?'); // still armed
    });

    test('clarifier slots survive setSpreadType (table reset)', () {
      final c = SpreadController(random: Random(5));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      c.armClarifierQuestion('What is hidden?');
      c.dealNextCardOrClarifier();
      c.setSpreadType(SpreadType.one);
      expect(c.slots.length, 1);
      expect(c.slots.every((s) => s.state == SlotState.empty), isTrue);
      expect(c.remaining, 78);
      expect(c.isDealLocked, isFalse); // fresh base spread, deck open
    });

    test('initialSpreadAllFaceUp ignores clarifier slots', () {
      final c = SpreadController(random: Random(6));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      expect(c.initialSpreadAllFaceUp, isTrue);
      c.armClarifierQuestion('What is hidden?');
      c.dealNextCardOrClarifier();
      // The clarifier landed face-down — the gate must stay open.
      expect(c.initialSpreadAllFaceUp, isTrue);
    });
  });


  group('phygital camera-to-table sync', () {
    test('scan handoff marks the session as physicalCameraSync', () {
      final c = SpreadController(random: Random(7));
      expect(c.sourceMode, TableSourceMode.digitalDeck);
      c.loadScannedSpreadFaceUp([
        (tarotDeck[0], false),
        (tarotDeck[1], true),
        (tarotDeck[2], false),
      ]);
      expect(c.sourceMode, TableSourceMode.physicalCameraSync);
      expect(c.initialSpreadAllFaceUp, isTrue);
      expect(c.slots.every((s) => s.fromPhysicalCard), isTrue);
      // Reset returns to the digital deck.
      c.resetTable();
      expect(c.sourceMode, TableSourceMode.digitalDeck);
      expect(c.slots.every((s) => s.state == SlotState.empty), isTrue);
    });

    test('attachContextToNextUntagged tags the first untagged card', () {
      final c = SpreadController(random: Random(8));
      c.loadScannedSpreadFaceUp([
        (tarotDeck[3], false),
        (tarotDeck[4], false),
      ]);
      expect(c.attachContextToNextUntagged(chip: 'Inner Doubt'), isTrue);
      expect(c.slots[0].userContext, 'Inner Doubt');
      expect(c.attachContextToNextUntagged(text: 'why these cards'), isTrue);
      expect(c.slots[1].userContext, '"why these cards"');
      expect(c.attachContextToNextUntagged(chip: 'Late'), isFalse);
    });

    test('clarifier camera scan appends the photographed card face-up', () {
      final c = SpreadController(random: Random(9));
      c.loadScannedSpreadFaceUp([
        (tarotDeck[5], false),
        (tarotDeck[6], true),
        (tarotDeck[7], false),
      ]);
      final remainingBefore = c.remaining; // 78 — physical cards
      expect(c.clarifierScanRequested, isFalse);
      c.requestClarifierScan('What is the hidden obstacle?');
      expect(c.clarifierScanRequested, isTrue);
      final idx = c.completeClarifierScan(tarotDeck[42], true);
      expect(idx, 3);
      expect(c.clarifierScanRequested, isFalse);
      final slot = c.slots[3];
      expect(slot.role, 'Clarifier 1');
      expect(slot.userContext, '"What is the hidden obstacle?"');
      expect(slot.state, SlotState.faceUp);
      expect(slot.fromPhysicalCard, isTrue);
      // The real card never left the digital 78-card ledger.
      expect(c.remaining, remainingBefore);
      // A second scan without arming does nothing.
      expect(c.completeClarifierScan(tarotDeck[1], false), isNull);
    });
  });


  group('structured synthesis + elemental alchemy', () {
    test('elementalBalance counts, dominant and missing elements', () {
      final slots = [
        DealtCardSlot(index: 0, role: 'A')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck[22]), false), // Ace of Wands — fire
        DealtCardSlot(index: 1, role: 'B')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck[27]), false), // Five of Wands — fire
        DealtCardSlot(index: 2, role: 'C')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck[0]), false), // The Fool — air
      ];
      final balance = elementalBalance(slots);
      expect(balance[Element.fire], 2);
      expect(balance[Element.air], 1);
      expect(balance[Element.water], 0);
      expect(balance[Element.earth], 0);
      expect(dominantElements(balance), [Element.fire]);
      expect(missingElements(balance), [Element.water, Element.earth]);
    });

    test('synthesizeStructured returns the three sections + follow-up',
        () async {
      final c = SpreadController(random: Random(10));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      c.setSlotUserContext(0, chip: 'Inner Doubt', text: 'my question');
      final contexts = {
        for (final s in c.slots)
          if (s.userContext != null) s.index: s.userContext!,
      };
      final result = await OracleSynthesisService().synthesizeStructured(
        slots: c.slots,
        type: c.spreadType,
        slotContexts: contexts,
      );
      expect(result.narrative, isNotEmpty);
      expect(result.narrative, contains('You held before drawing'));
      expect(result.narrative, contains('Inner Doubt'));
      expect(result.elementalAlchemy, contains('Balance:'));
      expect(result.verdict, contains('The step to take today:'));
      expect(result.followUp, isNotEmpty);
    });

    test('synthesizeClarifier weaves the question into the answer',
        () async {
      final c = SpreadController(random: Random(11));
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
        c.flipSlot(i);
      }
      c.armClarifierQuestion('What is the hidden obstacle?');
      c.dealNextCardOrClarifier();
      final slot = c.slots[3];
      final text = await OracleSynthesisService().synthesizeClarifier(
        question: 'What is the hidden obstacle?',
        newSlot: slot,
        previous: c.slots.where((s) => s.index < 3).toList(),
      );
      expect(text, contains('What is the hidden obstacle?'));
      expect(text, contains(slot.card!.name));
      expect(text, contains('The step to take:'));
    });

    test('elemental thread gradient pairs follow the spec', () {
      expect(elementalThreadColors(Element.fire).first,
          const Color(0xFFF59E0B));
      expect(elementalThreadColors(Element.fire).last,
          const Color(0xFFDC2626));
      expect(elementalThreadColors(Element.water).last,
          const Color(0xFF6366F1));
      expect(elementalThreadColors(Element.air).first,
          const Color(0xFFCBD5E1));
      expect(elementalThreadColors(Element.earth).last,
          const Color(0xFFFBBF24));
    });

    test('rectEdgeToward anchors a thread on the facing card edges', () {
      final above = const Rect.fromLTWH(0, 0, 220, 360);
      final below = const Rect.fromLTWH(0, 416, 220, 360);
      // Vertical neighbours: bottom-center → top-center.
      expect(rectEdgeToward(above, below.center),
          const Offset(110, 360));
      expect(rectEdgeToward(below, above.center),
          const Offset(110, 416));
      // Horizontal neighbours: right edge → left edge.
      final left = const Rect.fromLTWH(0, 0, 220, 360);
      final right = const Rect.fromLTWH(276, 0, 220, 360);
      expect(rectEdgeToward(left, right.center),
          const Offset(220, 180));
      expect(rectEdgeToward(right, left.center),
          const Offset(276, 180));
    });
  });

  group('elemental thread cord spec (sprint 1/3)', () {
    List<DealtCardSlot> dealtOf(SpreadController ctrl) =>
        [for (final s in ctrl.slots) if (s.card != null) s];

    test('anchors sit 8 px INSIDE both facing edges — zero visible gap', () {
      final ctrl = SpreadController(random: Random(11));
      ctrl.dealCardAt(0);
      ctrl.dealCardAt(0);
      ctrl.flipSlot(0);
      ctrl.flipSlot(1);
      final dealt = dealtOf(ctrl);
      // Vertical neighbours: bottom-center (8 px inside) → top-center
      // (8 px inside) — the cord physically reaches into both cards.
      final vertical = threadSegmentsFor(dealt, const [
        Rect.fromLTWH(0, 0, 220, 360),
        Rect.fromLTWH(0, 416, 220, 360),
      ]);
      expect(vertical.length, 1);
      expect(vertical.first.from, const Offset(110, 352)); // 360 - 8
      expect(vertical.first.to, const Offset(110, 424)); // 416 + 8
      expect(vertical.first.pairKey, dealt[0].index);

      // Horizontal neighbours: right edge − 8 → left edge + 8.
      final horizontal = threadSegmentsFor(dealt, const [
        Rect.fromLTWH(0, 0, 220, 360),
        Rect.fromLTWH(276, 0, 220, 360),
      ]);
      expect(horizontal.first.from, const Offset(212, 180)); // 220 - 8
      expect(horizontal.first.to, const Offset(284, 180)); // 276 + 8
    });

    test('a thread exists ONLY when BOTH adjacent cards are face-up', () {
      final ctrl = SpreadController(random: Random(3));
      ctrl.dealCardAt(0);
      ctrl.dealCardAt(0);
      ctrl.flipSlot(0); // only the first card
      const rects = [
        Rect.fromLTWH(0, 0, 220, 360),
        Rect.fromLTWH(0, 416, 220, 360),
      ];
      expect(threadSegmentsFor(dealtOf(ctrl), rects), isEmpty);
      ctrl.flipSlot(1); // the second card finishes flipping face-up
      expect(threadSegmentsFor(dealtOf(ctrl), rects).length, 1);
    });

    test('ignite flash duration is the 480ms spec', () {
      expect(igniteFlashDuration, const Duration(milliseconds: 480));
    });

    test('painter repaints as the ignite flash advances', () {
      const seg = ElementalThreadSegment(
        from: Offset.zero,
        to: Offset(0, 200),
        elementA: Element.fire,
        elementB: Element.water,
        tone: ThreadTone.neutral,
        pairKey: 0,
      );
      final pulse = AlwaysStoppedAnimation<double>(0.0);
      final cold = ElementalThreadsPainter(
          segments: const [seg], pulse: pulse, ignite: const {0: 0.0});
      final half = ElementalThreadsPainter(
          segments: const [seg], pulse: pulse, ignite: const {0: 0.5});
      final lit = ElementalThreadsPainter(
          segments: const [seg], pulse: pulse, ignite: const {0: 1.0});
      expect(cold.shouldRepaint(half), isTrue);
      expect(half.shouldRepaint(lit), isTrue);
      expect(
        lit.shouldRepaint(ElementalThreadsPainter(
            segments: const [seg], pulse: pulse, ignite: const {0: 1.0})),
        isFalse,
      );
    });
  });
}

