import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/state/guided_session_coordinator.dart';
import 'package:mindreader/state/live_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

void main() {
  group('Triad Flow lifecycle', () {
    late LiveReadingController live;
    late SpreadController spread;
    late GuidedSessionCoordinator c;

    setUp(() {
      live = LiveReadingController();
      spread = SpreadController();
      c = GuidedSessionCoordinator(live: live, spread: spread);
    });

    test('start resets the table and awaits intention', () {
      c.start();
      expect(live.phase, GuidePhase.awaitingIntention);
      expect(spread.slots.length, 3); // Triad Flow default
      expect(spread.slots.every((s) => s.card == null), isTrue);
    });

    test('the full Triad Flow binds 3 cards and completes', () {
      c.start();
      live.transitionTo(GuidePhase.awaitingCard);

      void confirmCard(int cardId, int slotIndex) {
        live.transitionTo(GuidePhase.cardDetected);
        live.transitionTo(GuidePhase.awaitingReveal);
        live.transitionTo(GuidePhase.recognizingCard);
        live.transitionTo(GuidePhase.awaitingConfirmation);
        expect(
          c.confirmCard(TarotDivinationCard(tarotDeck[cardId]), reversed: false),
          isTrue,
        );
        expect(live.phase, GuidePhase.interpretingCard);
        expect(spread.slots[slotIndex].card!.id, tarotDeck[cardId].id);
        expect(spread.slots[slotIndex].fromPhysicalCard, isTrue);
        live.transitionTo(GuidePhase.awaitingNextCard);
      }

      confirmCard(0, 0);
      expect(c.isComplete, isFalse); // 1 of 3 — NOT complete

      expect(c.nextCard(), isTrue);
      expect(live.currentSlotIndex, 1);
      confirmCard(1, 1);
      expect(c.isComplete, isFalse); // 2 of 3 — NOT complete

      expect(c.nextCard(), isTrue);
      expect(live.currentSlotIndex, 2);
      confirmCard(2, 2);

      expect(c.nextCard(), isFalse); // last slot -> spreadCompleted
      expect(live.phase, GuidePhase.spreadCompleted);
      expect(c.isComplete, isTrue);
    });

    test('an incomplete spread is never reported complete', () {
      c.start();
      live.transitionTo(GuidePhase.awaitingCard);
      live.transitionTo(GuidePhase.cardDetected);
      live.transitionTo(GuidePhase.recognizingCard);
      live.transitionTo(GuidePhase.awaitingConfirmation);
      c.confirmCard(TarotDivinationCard(tarotDeck[0]), reversed: false);

      expect(live.phase, GuidePhase.interpretingCard);
      expect(c.isComplete, isFalse);
      // The FSM cannot reach `completed` from here (only spreadCompleted can).
      expect(live.complete(), isFalse);
      expect(live.phase, GuidePhase.interpretingCard);
    });

    test('confirmCard refuses outside awaitingConfirmation', () {
      c.start();
      live.transitionTo(GuidePhase.awaitingCard);
      expect(
        c.confirmCard(TarotDivinationCard(tarotDeck[0]), reversed: false),
        isFalse,
      );
      expect(spread.slots[0].card, isNull);
    });

    test('bindGuidedCard guards an out-of-range index', () {
      c.start();
      expect(
        spread.bindGuidedCard(99, TarotDivinationCard(tarotDeck[0]), false),
        isFalse,
      );
      expect(
        spread.bindGuidedCard(-1, TarotDivinationCard(tarotDeck[0]), false),
        isFalse,
      );
    });
  });
}
