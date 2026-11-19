import 'package:flutter/foundation.dart';

import '../core/models/reading_status.dart';

/// The finite-state-machine phase of the Guided Physical Spread flow.
///
/// [preparing] is the entry; the happy path runs
/// `awaitingIntention → awaitingCard → cardDetected → (awaitingReveal →
/// recognizingCard | recognizingCard) → awaitingConfirmation →
/// interpretingCard → (awaitingUser → awaitingNextCard | awaitingNextCard) →
/// awaitingCard → … → spreadCompleted → completed`.
///
/// [paused] / [completed] / [cancelled] / [error] are control/terminal
/// states: [completed]/[cancelled]/[error] accept no further transition.
enum GuidePhase {
  preparing,
  awaitingIntention,
  awaitingCard,
  cardDetected,
  awaitingReveal,
  recognizingCard,
  awaitingConfirmation,
  interpretingCard,
  awaitingUser,
  awaitingNextCard,
  spreadCompleted,
  paused,
  completed,
  cancelled,
  error,
}

extension GuidePhaseX on GuidePhase {
  /// True once the session can no longer change state.
  bool get isTerminal =>
      this == GuidePhase.completed ||
      this == GuidePhase.cancelled ||
      this == GuidePhase.error;

  /// Whether [next] is a legal happy-path (or retry) transition from this
  /// phase. Control transitions (pause/cancel/fail/complete) are handled by
  /// explicit controller methods, not this table, so they stay auditable.
  bool canTransitionTo(GuidePhase next) => switch (this) {
        GuidePhase.preparing => next == GuidePhase.awaitingIntention,
        GuidePhase.awaitingIntention => next == GuidePhase.awaitingCard,
        GuidePhase.awaitingCard => next == GuidePhase.cardDetected,
        GuidePhase.cardDetected =>
          next == GuidePhase.awaitingReveal ||
              next == GuidePhase.recognizingCard,
        GuidePhase.awaitingReveal => next == GuidePhase.recognizingCard,
        GuidePhase.recognizingCard => next == GuidePhase.awaitingConfirmation,
        GuidePhase.awaitingConfirmation =>
          next == GuidePhase.interpretingCard ||
              next == GuidePhase.awaitingCard,
        GuidePhase.interpretingCard =>
          next == GuidePhase.awaitingUser ||
              next == GuidePhase.awaitingNextCard,
        GuidePhase.awaitingUser => next == GuidePhase.awaitingNextCard,
        GuidePhase.awaitingNextCard =>
          next == GuidePhase.awaitingCard ||
              next == GuidePhase.spreadCompleted,
        GuidePhase.spreadCompleted => next == GuidePhase.completed,
        GuidePhase.paused ||
        GuidePhase.completed ||
        GuidePhase.cancelled ||
        GuidePhase.error => false,
      };
}

/// How talkative the Oracle is during the physical ritual.
///
/// * [active] — walks the reader through each physical beat;
/// * [quiet] — stays silent except at the meaningful beats (interpreting a
///   card, completing the spread, answering a reader question), so the Oracle
///   never comments on every movement.
enum GuidanceMode { active, quiet }

/// Whether the Oracle should emit a guidance line at [phase] under [mode].
///
/// Both modes speak at the meaningful beats — interpreting a card, completing
/// the spread, a direct reader question — and never speak for the pure
/// bookkeeping states. [active] additionally voices the transitional beats
/// (card detected / reveal / recognize); [quiet] stays silent on those so the
/// ritual feels natural rather than narrated.
bool guidanceShouldSpeak(GuidanceMode mode, GuidePhase phase) {
  switch (phase) {
    case GuidePhase.interpretingCard:
    case GuidePhase.spreadCompleted:
    case GuidePhase.awaitingUser:
      return true;
    case GuidePhase.cardDetected:
    case GuidePhase.awaitingReveal:
    case GuidePhase.recognizingCard:
    case GuidePhase.awaitingConfirmation:
      return mode == GuidanceMode.active;
    case GuidePhase.preparing:
    case GuidePhase.awaitingIntention:
    case GuidePhase.awaitingCard:
    case GuidePhase.awaitingNextCard:
    case GuidePhase.paused:
    case GuidePhase.completed:
    case GuidePhase.cancelled:
    case GuidePhase.error:
      return false;
  }
}

/// The single source of truth for the GUIDED PHYSICAL SPREAD process.
///
/// This orchestrates the physical interaction ONLY. It deliberately does NOT
/// hold a copy of the spread: the cards themselves live in `SpreadController`
/// (the single card source of truth). It knows the chosen spread's *shape*
/// ([slotCount]) so it can guard "never move to a position that does not
/// exist", but it has no API that mutates cards — so the Oracle or any
/// consumer cannot change cards or jump to an invalid slot through this type.
class LiveReadingController extends ChangeNotifier {
  LiveReadingController();

  int _slotCount = 3;
  int get slotCount => _slotCount;

  GuidePhase _phase = GuidePhase.preparing;
  GuidePhase get phase => _phase;

  /// The base-spread slot currently being filled (0-based, always `< slotCount`).
  int _currentSlotIndex = 0;
  int get currentSlotIndex => _currentSlotIndex;

  GuidePhase _phaseBeforePause = GuidePhase.preparing;

  GuidanceMode _guidanceMode = GuidanceMode.active;
  GuidanceMode get guidanceMode => _guidanceMode;

  /// Sets how talkative the Oracle is during this session. Persists across
  /// [begin] (it is a reader preference, not per-spread state).
  void setGuidanceMode(GuidanceMode mode) {
    if (_guidanceMode == mode) return;
    _guidanceMode = mode;
    notifyListeners();
  }

  /// Whether the Oracle should speak at the current phase — the single gate
  /// the UI/coordinator checks before emitting a guidance line, so the Oracle
  /// never comments on every movement in quiet mode.
  bool get oracleShouldSpeak => guidanceShouldSpeak(_guidanceMode, _phase);

  /// Whether another base-spread slot follows the current one.
  bool get hasNextSlot => _currentSlotIndex + 1 < _slotCount;

  /// Whether the current slot is the LAST base-spread slot.
  bool get isOnLastSlot => !hasNextSlot;

  /// Coarse lifecycle status projected onto [ReadingStatus] so the Guided
  /// flow and the Oracle session share one vocabulary.
  ReadingStatus get readingStatus => switch (_phase) {
        GuidePhase.preparing => ReadingStatus.preparing,
        GuidePhase.paused => ReadingStatus.paused,
        GuidePhase.completed => ReadingStatus.completed,
        GuidePhase.cancelled => ReadingStatus.cancelled,
        GuidePhase.error => ReadingStatus.failed,
        _ => ReadingStatus.active,
      };

  /// Starts (or restarts) the guided session for a spread of [slotCount]
  /// slots. Resets the phase and position; the cards remain untouched in
  /// `SpreadController`.
  void begin({required int slotCount}) {
    _slotCount = slotCount;
    _currentSlotIndex = 0;
    _phase = GuidePhase.preparing;
    _phaseBeforePause = GuidePhase.preparing;
    notifyListeners();
  }

  /// Legal happy-path/retry transition. Returns false (state unchanged) when
  /// [next] is unreachable from the current phase.
  bool transitionTo(GuidePhase next) {
    if (_phase == next) return true;
    if (!_phase.canTransitionTo(next)) return false;
    _phase = next;
    notifyListeners();
    return true;
  }

  /// Advances to the next base-spread slot. Moving past the last slot is
  /// IMPOSSIBLE: the guard transitions to [GuidePhase.spreadCompleted]
  /// instead and returns false.
  bool advanceToNextSlot() {
    if (!hasNextSlot) {
      transitionTo(GuidePhase.spreadCompleted);
      return false;
    }
    _currentSlotIndex++;
    transitionTo(GuidePhase.awaitingCard);
    return true;
  }

  /// Suspends the session (only from a non-terminal, non-paused phase).
  void pause() {
    if (_phase.isTerminal || _phase == GuidePhase.paused) return;
    _phaseBeforePause = _phase;
    _phase = GuidePhase.paused;
    notifyListeners();
  }

  /// Resumes the phase that was active before [pause].
  void resume() {
    if (_phase != GuidePhase.paused) return;
    _phase = _phaseBeforePause;
    notifyListeners();
  }

  /// Abandons the session (only from a non-terminal phase).
  void cancel() {
    if (_phase.isTerminal) return;
    _phase = GuidePhase.cancelled;
    notifyListeners();
  }

  /// Marks the session as failed (only from a non-terminal phase).
  void fail() {
    if (_phase.isTerminal) return;
    _phase = GuidePhase.error;
    notifyListeners();
  }

  /// Completes the session — legal only once the spread is complete.
  bool complete() => transitionTo(GuidePhase.completed);
}

