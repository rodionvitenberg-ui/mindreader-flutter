import '../core/models/divination_card.dart';
import 'live_reading_controller.dart';
import 'spread_controller.dart';

/// Glues the Guided Physical Spread FSM ([LiveReadingController]) to the card
/// source of truth ([SpreadController]) for the Triad Flow.
///
/// It holds NO card state of its own — it drives phases and asks the
/// [SpreadController] to bind confirmed cards, keeping the two single sources
/// of truth (cards / process) cleanly separated. The Oracle never mutates
/// cards through this type; it only observes the bound slots.
class GuidedSessionCoordinator {
  GuidedSessionCoordinator({required this.live, required this.spread});

  final LiveReadingController live;
  final SpreadController spread;

  /// Starts a guided session for the ACTIVE spread: resets the table to empty
  /// physical slots and moves the FSM to `awaitingIntention`.
  void start() {
    spread.startGuidedSpread();
    live.begin(slotCount: spread.spreadCardCount);
    live.transitionTo(GuidePhase.awaitingIntention);
  }

  /// The reader confirmed the recognized card for the CURRENT slot: binds it
  /// face-up into that slot and moves to interpretation. Returns false when
  /// the FSM is not awaiting confirmation or the slot is out of range.
  bool confirmCard(DivinationCard card, {required bool reversed}) {
    if (live.phase != GuidePhase.awaitingConfirmation) return false;
    if (!spread.bindGuidedCard(live.currentSlotIndex, card, reversed)) {
      return false;
    }
    live.transitionTo(GuidePhase.interpretingCard);
    return true;
  }

  /// Advances to the next base-spread slot, or completes the spread when the
  /// last slot is reached.
  bool nextCard() => live.advanceToNextSlot();

  /// True only when EVERY base slot actually holds a card AND the FSM has
  /// reached `spreadCompleted` — an incomplete spread is NEVER complete.
  bool get isComplete =>
      live.phase == GuidePhase.spreadCompleted &&
      spread.slots.take(spread.spreadCardCount).every((s) => s.card != null);
}
