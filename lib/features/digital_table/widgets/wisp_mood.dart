import '../../../core/models/guide_event.dart';
import '../../../core/models/guide_hint.dart';

/// Wisp's facial moods — mimicry is the heart of the companion, so every
/// expression maps to a real reading moment.
enum WispMood {
  /// Soft smile `^ ^` — meeting the reader, Step 1 welcome, and celebration.
  greeting,

  /// Wide-eyed `o o` — a card is being dealt, revealed or read.
  curious,

  /// Soft sympathy — two cards pull in different directions; support, not
  /// excitement.
  empathetic,

  /// Flowing contemplation — an answer is being composed.
  thinking,

  /// Closed eyes `– –` — Wisp is resting.
  sleeping,
}

/// Maps the mentor's single current hint onto Wisp's expression.
///
/// Pure (no Flutter imports), so every branch is unit-tested without pumping
/// widgets. Step 1 greeting and a finished spread bring the smile; an opposing
/// pair asks for sympathy instead of curiosity.
WispMood wispMoodFor(GuideHint? hint, {bool tension = false}) {
  if (hint == null) return WispMood.sleeping;
  if (hint.eventType == GuideEventType.spreadCompleted ||
      hint.eventType == GuideEventType.spreadSelected) {
    return WispMood.greeting;
  }
  if (tension) return WispMood.empathetic;
  return WispMood.curious;
}
