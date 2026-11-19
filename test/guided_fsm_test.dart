import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/reading_status.dart';
import 'package:mindreader/state/live_reading_controller.dart';

void main() {
  group('happy path', () {
    test('preparing walks the full Triad flow to spreadCompleted', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);

      expect(c.phase, GuidePhase.preparing);
      expect(c.transitionTo(GuidePhase.awaitingIntention), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingCard), isTrue);

      // Card 1: face-down detect -> reveal -> recognize -> confirm -> interpret.
      expect(c.transitionTo(GuidePhase.cardDetected), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingReveal), isTrue);
      expect(c.transitionTo(GuidePhase.recognizingCard), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingConfirmation), isTrue);
      expect(c.transitionTo(GuidePhase.interpretingCard), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingNextCard), isTrue);

      // Card 2.
      expect(c.advanceToNextSlot(), isTrue);
      expect(c.currentSlotIndex, 1);
      expect(c.phase, GuidePhase.awaitingCard);
      expect(c.transitionTo(GuidePhase.cardDetected), isTrue);
      expect(c.transitionTo(GuidePhase.recognizingCard), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingConfirmation), isTrue);
      expect(c.transitionTo(GuidePhase.interpretingCard), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingNextCard), isTrue);

      // Card 3 (last): advancing past it completes the spread, never overflows.
      expect(c.advanceToNextSlot(), isTrue);
      expect(c.currentSlotIndex, 2);
      expect(c.isOnLastSlot, isTrue);
      expect(c.transitionTo(GuidePhase.cardDetected), isTrue);
      expect(c.transitionTo(GuidePhase.recognizingCard), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingConfirmation), isTrue);
      expect(c.transitionTo(GuidePhase.interpretingCard), isTrue);
      expect(c.transitionTo(GuidePhase.awaitingNextCard), isTrue);

      expect(c.advanceToNextSlot(), isFalse);
      expect(c.phase, GuidePhase.spreadCompleted);
      expect(c.complete(), isTrue);
      expect(c.phase, GuidePhase.completed);
    });

    test('a face-up card skips the reveal step', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      expect(c.transitionTo(GuidePhase.cardDetected), isTrue);
      expect(c.transitionTo(GuidePhase.recognizingCard), isTrue);
    });
  });

  group('invalid transitions are rejected', () {
    test('preparing cannot jump straight to awaitingCard', () {
      final c = LiveReadingController();
      expect(c.transitionTo(GuidePhase.awaitingCard), isFalse);
      expect(c.phase, GuidePhase.preparing);
    });

    test('awaitingCard cannot jump to interpretingCard', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      expect(c.transitionTo(GuidePhase.interpretingCard), isFalse);
      expect(c.phase, GuidePhase.awaitingCard);
    });

    test('terminal states accept no further transition', () {
      final c = LiveReadingController();
      c.cancel();
      expect(c.phase, GuidePhase.cancelled);
      expect(c.transitionTo(GuidePhase.awaitingCard), isFalse);
    });
  });

  group('retry', () {
    test('a rejected confirmation returns to awaitingCard', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      c.transitionTo(GuidePhase.cardDetected);
      c.transitionTo(GuidePhase.recognizingCard);
      c.transitionTo(GuidePhase.awaitingConfirmation);
      expect(c.transitionTo(GuidePhase.awaitingCard), isTrue);
      expect(c.phase, GuidePhase.awaitingCard);
    });
  });

  group('position guard', () {
    test('advanceToNextSlot never moves past the last slot', () {
      final c = LiveReadingController();
      c.begin(slotCount: 1);
      // Reach awaitingNextCard on the single (last) slot.
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      c.transitionTo(GuidePhase.cardDetected);
      c.transitionTo(GuidePhase.recognizingCard);
      c.transitionTo(GuidePhase.awaitingConfirmation);
      c.transitionTo(GuidePhase.interpretingCard);
      c.transitionTo(GuidePhase.awaitingNextCard);
      expect(c.currentSlotIndex, 0);
      expect(c.isOnLastSlot, isTrue);
      expect(c.advanceToNextSlot(), isFalse);
      expect(c.phase, GuidePhase.spreadCompleted);
      expect(c.currentSlotIndex, 0); // never overflows
      expect(c.advanceToNextSlot(), isFalse); // terminal: still a no-op
      expect(c.currentSlotIndex, 0);
    });
  });

  group('pause / resume / cancel / fail', () {
    test('pause preserves and resume restores the active phase', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      c.pause();
      expect(c.phase, GuidePhase.paused);
      expect(c.readingStatus, ReadingStatus.paused);
      c.resume();
      expect(c.phase, GuidePhase.awaitingCard);
    });

    test('cancel from an active phase reaches a terminal state', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.cancel();
      expect(c.phase, GuidePhase.cancelled);
      expect(c.readingStatus, ReadingStatus.cancelled);
    });

    test('cancel is a no-op once terminal', () {
      final c = LiveReadingController();
      c.cancel();
      c.fail();
      expect(c.phase, GuidePhase.cancelled); // unchanged
    });
  });

  group('begin resets', () {
    test('begin restores preparing and slot 0 without touching cards', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      c.begin(slotCount: 7);
      expect(c.phase, GuidePhase.preparing);
      expect(c.currentSlotIndex, 0);
      expect(c.slotCount, 7);
    });
  });
}
