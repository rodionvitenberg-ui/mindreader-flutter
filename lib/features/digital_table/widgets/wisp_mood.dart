import '../../../core/models/guide_event.dart';
import '../../../core/models/guide_hint.dart';

/// The companion's facial moods — the wisp's mimicry is the point, so every
/// expression has a meaning the mentor can actually reach.
enum WispMood {
  /// Soft smile `^ ^` — meeting the reader, and the one celebration.
  greeting,

  /// Wide-eyed `o o` — a card is being dealt, revealed or read.
  curious,

  /// Soft sympathy — two cards pull in different directions; support, not
  /// excitement.
  empathetic,

  /// Flowing contemplation — an answer is being composed.
  thinking,

  /// Closed eyes `– –` — the companion is resting.
  sleeping,
}

/// Maps the mentor's single current hint onto the companion's expression.
///
/// Pure (no Flutter imports), so every branch is unit-tested without pumping
/// widgets. A finished spread is the only celebration; an opposing pair is the
/// only moment that asks for sympathy instead of curiosity.
WispMood wispMoodFor(GuideHint? hint, {bool tension = false}) {
  if (hint == null) return WispMood.sleeping;
  if (hint.eventType == GuideEventType.spreadCompleted) {
    return WispMood.greeting;
  }
  if (tension) return WispMood.empathetic;
  return WispMood.curious;
}
