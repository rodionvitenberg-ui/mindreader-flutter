import '../services/vision/vision_engine.dart';
import 'divination_system.dart';

/// The domain events that drive the Guided Physical Spread flow.
///
/// These are DELIBERATELY higher-level than [VisionEvent]: a Vision event is
/// a raw tracking update ("a region appeared / was recognized / moved / left
/// the frame"), while a [PhysicalReadingEvent] carries the reading-level
/// meaning ("a card was confirmed into slot 2", "the spread completed").
///
/// Every event carries an [eventId] + [trackId] + [sessionId] so the flow can
/// (a) dedupe repeats, (b) correlate ONE physical card across frames, and
/// (c) reject events that belong to an older session.
enum PhysicalReadingEventType {
  cardObserved,
  cardRecognized,
  cardConfirmed,
  cardRevealed,
  cardTemporarilyOccluded,
  cardMoved,
  cardRemoved,
  cardOrientationChanged,
  clarifierConfirmed,
  spreadCompleted,
}

/// Base type for every physical-reading event. Sealed so a `switch` over
/// [PhysicalReadingEvent] is exhaustive and a forgotten event type is a
/// compile-time error rather than a silent drop.
sealed class PhysicalReadingEvent {
  const PhysicalReadingEvent({
    required this.eventId,
    required this.trackId,
    required this.sessionId,
    required this.timestamp,
  });

  /// Unique within the session; used to reject exact repeats.
  final String eventId;

  /// Correlates one physical card across frames (detection → recognition →
  /// confirmation). Distinct from [eventId]: many events share one track.
  final String trackId;

  /// The reading session this event belongs to; stale-session events are
  /// rejected by the ledger.
  final String sessionId;

  final DateTime timestamp;

  PhysicalReadingEventType get type => switch (this) {
        CardObservedEvent() => PhysicalReadingEventType.cardObserved,
        CardRecognizedEvent() => PhysicalReadingEventType.cardRecognized,
        CardConfirmedEvent() => PhysicalReadingEventType.cardConfirmed,
        CardRevealedEvent() => PhysicalReadingEventType.cardRevealed,
        CardTemporarilyOccludedEvent() =>
          PhysicalReadingEventType.cardTemporarilyOccluded,
        CardMovedEvent() => PhysicalReadingEventType.cardMoved,
        CardRemovedEvent() => PhysicalReadingEventType.cardRemoved,
        CardOrientationChangedEvent() =>
          PhysicalReadingEventType.cardOrientationChanged,
        ClarifierConfirmedEvent() => PhysicalReadingEventType.clarifierConfirmed,
        SpreadCompletedEvent() => PhysicalReadingEventType.spreadCompleted,
      };
}

/// A card-shaped region appeared in the frame — BEFORE recognition, so no
/// identity is claimed yet. Geometry is optional (never invented).
class CardObservedEvent extends PhysicalReadingEvent {
  const CardObservedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    this.boundingBox,
  });

  final NormalizedRect? boundingBox;
}

/// A card was identified as a canonical card. Identity fields are nullable
/// while recognition is incomplete (mirrors [VisionCardCandidate]).
class CardRecognizedEvent extends PhysicalReadingEvent {
  const CardRecognizedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    this.system,
    this.canonicalCardId,
    this.orientation = CardOrientation.unknown,
    this.faceState = CardFaceState.unknown,
  });

  final DivinationSystem? system;
  final int? canonicalCardId;
  final CardOrientation orientation;
  final CardFaceState faceState;
}

/// The reader confirmed this track into a specific spread [slotIndex].
/// Re-appearing afterwards must NOT produce another confirmation — the
/// ledger marks the track as confirmed on this event.
class CardConfirmedEvent extends PhysicalReadingEvent {
  const CardConfirmedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    required this.slotIndex,
  });

  final int slotIndex;
}

/// A face-down card was turned face-up. This is the explicit "reveal" beat
/// of the physical ritual — distinct from a recognition update.
class CardRevealedEvent extends PhysicalReadingEvent {
  const CardRevealedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    this.orientation = CardOrientation.upright,
  });

  final CardOrientation orientation;
}

/// A card briefly left the frame. This is TEMPORARY and must never be read
/// as [CardRemovedEvent]: a card drifting out of view does not cancel its
/// position in the spread.
class CardTemporarilyOccludedEvent extends PhysicalReadingEvent {
  const CardTemporarilyOccludedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
  });
}

/// A card's location changed. This does NOT reassign its role: the slot the
/// card is bound to stays the same unless a new [CardConfirmedEvent] says so.
class CardMovedEvent extends PhysicalReadingEvent {
  const CardMovedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    this.boundingBox,
  });

  final NormalizedRect? boundingBox;
}

/// A card was PERMANENTLY removed from the spread by an explicit action.
/// The inverse of [CardTemporarilyOccludedEvent]; a frame `lost` signal is
/// never mapped here.
class CardRemovedEvent extends PhysicalReadingEvent {
  const CardRemovedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
  });
}

/// The card flipped orientation (upright ↔ reversed).
class CardOrientationChangedEvent extends PhysicalReadingEvent {
  const CardOrientationChangedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    required this.from,
    required this.to,
  });

  final CardOrientation from;
  final CardOrientation to;
}

/// A physical clarifier was confirmed into [slotIndex] with its [question].
class ClarifierConfirmedEvent extends PhysicalReadingEvent {
  const ClarifierConfirmedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    required this.slotIndex,
    this.question,
  });

  final int slotIndex;
  final String? question;
}

/// Every base-spread slot is filled. Carries the final shape so consumers can
/// verify completeness without re-reading the table.
class SpreadCompletedEvent extends PhysicalReadingEvent {
  const SpreadCompletedEvent({
    required super.eventId,
    required super.trackId,
    required super.sessionId,
    required super.timestamp,
    required this.system,
    required this.cardCount,
  });

  final DivinationSystem system;
  final int cardCount;
}

/// Maps a raw [VisionEvent] onto the physical-reading domain in exactly ONE
/// place, so the camera pipeline and the Guided FSM never hand-roll the
/// translation.
///
/// The critical correctness property lives here: a `lost` Vision event is a
/// TEMPORARY occlusion, NOT a removal — a card leaving the frame never cancels
/// its position. `observed`/`recognized`/`updated` map straight through;
/// `updated` becomes [CardMovedEvent] (role unchanged).
PhysicalReadingEvent physicalEventFromVision(
  VisionEvent event, {
  required String sessionId,
  required String eventId,
}) {
  final c = event.candidate;
  final trackId = c.trackId;
  final timestamp = event.timestamp;
  switch (event.type) {
    case VisionEventType.observed:
      return CardObservedEvent(
        eventId: eventId,
        trackId: trackId,
        sessionId: sessionId,
        timestamp: timestamp,
        boundingBox: c.boundingBox,
      );
    case VisionEventType.recognized:
      return CardRecognizedEvent(
        eventId: eventId,
        trackId: trackId,
        sessionId: sessionId,
        timestamp: timestamp,
        system: c.system,
        canonicalCardId: c.canonicalCardId,
        orientation: c.orientation,
        faceState: c.faceState,
      );
    case VisionEventType.updated:
      return CardMovedEvent(
        eventId: eventId,
        trackId: trackId,
        sessionId: sessionId,
        timestamp: timestamp,
        boundingBox: c.boundingBox,
      );
    case VisionEventType.lost:
      return CardTemporarilyOccludedEvent(
        eventId: eventId,
        trackId: trackId,
        sessionId: sessionId,
        timestamp: timestamp,
      );
  }
}

/// Deduplicates physical-reading events across a session.
///
/// Two rules, both scoped by [sessionId]:
/// 1. an [eventId] that was already seen is a duplicate and [mark] returns
///    false (no effect);
/// 2. confirming a track ([CardConfirmedEvent] / [ClarifierConfirmedEvent])
///    records that track as confirmed, so a card re-appearing afterwards is
///    recognized as "already placed" rather than re-confirmed.
class PhysicalReadingEventLedger {
  final Map<String, Set<String>> _seenEventIds = {};
  final Map<String, Set<String>> _confirmedTracks = {};

  /// Records [event] and returns true when it is new; returns false (and
  /// records nothing) when its [eventId] was already seen in the session.
  bool mark(PhysicalReadingEvent event) {
    final seen = _seenEventIds.putIfAbsent(event.sessionId, () => <String>{});
    if (seen.contains(event.eventId)) return false;
    seen.add(event.eventId);
    if (event is CardConfirmedEvent || event is ClarifierConfirmedEvent) {
      _confirmedTracks
          .putIfAbsent(event.sessionId, () => <String>{})
          .add(event.trackId);
    }
    return true;
  }

  /// True once [trackId] was confirmed into the spread in [sessionId].
  bool isTrackConfirmed(String sessionId, String trackId) =>
      _confirmedTracks[sessionId]?.contains(trackId) ?? false;
}
