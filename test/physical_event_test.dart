import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/physical_reading_event.dart';
import 'package:mindreader/core/services/vision/vision_engine.dart';

import 'fakes/fake_vision_engine.dart';

void main() {
  final t = DateTime.fromMillisecondsSinceEpoch(0);

  group('physicalEventFromVision', () {
    test('a lost Vision event maps to a TEMPORARY occlusion, not a removal', () {
      final mapped = physicalEventFromVision(
        VisionEvent(
          type: VisionEventType.lost,
          candidate: FakeVisionEngine.candidate(trackId: 't1'),
          timestamp: t,
        ),
        sessionId: 's1',
        eventId: 'e1',
      );

      expect(mapped, isA<CardTemporarilyOccludedEvent>());
      expect(mapped, isNot(isA<CardRemovedEvent>()));
      expect(mapped.type, PhysicalReadingEventType.cardTemporarilyOccluded);
    });

    test('observed maps to CardObservedEvent', () {
      final mapped = physicalEventFromVision(
        VisionEvent(
          type: VisionEventType.observed,
          candidate: FakeVisionEngine.candidate(trackId: 't1'),
          timestamp: t,
        ),
        sessionId: 's1',
        eventId: 'e1',
      );
      expect(mapped, isA<CardObservedEvent>());
    });

    test('recognized maps to CardRecognizedEvent and carries identity', () {
      final mapped = physicalEventFromVision(
        VisionEvent(
          type: VisionEventType.recognized,
          candidate: FakeVisionEngine.candidate(
            trackId: 't1',
            canonicalCardId: 4,
            orientation: CardOrientation.reversed,
            faceState: CardFaceState.faceUp,
          ),
          timestamp: t,
        ),
        sessionId: 's1',
        eventId: 'e1',
      );
      final recognized = mapped as CardRecognizedEvent;
      expect(recognized.canonicalCardId, 4);
      expect(recognized.orientation, CardOrientation.reversed);
      expect(recognized.faceState, CardFaceState.faceUp);
    });

    test('updated maps to CardMovedEvent — a move never changes the role', () {
      final mapped = physicalEventFromVision(
        VisionEvent(
          type: VisionEventType.updated,
          candidate: FakeVisionEngine.candidate(trackId: 't1'),
          timestamp: t,
        ),
        sessionId: 's1',
        eventId: 'e1',
      );
      // Type-level guarantee: a CardMovedEvent has no slotIndex, so it cannot
      // reassign the slot a card was confirmed into.
      expect(mapped, isA<CardMovedEvent>());
      expect(mapped, isNot(isA<CardConfirmedEvent>()));
    });
  });

  group('ledger dedupe', () {
    test('a duplicate eventId in the same session is rejected', () {
      final ledger = PhysicalReadingEventLedger();
      final event = CardObservedEvent(
        eventId: 'e1',
        trackId: 't1',
        sessionId: 's1',
        timestamp: t,
      );
      expect(ledger.mark(event), isTrue);
      expect(ledger.mark(event), isFalse); // exact repeat
    });

    test('the same eventId in a different session is NOT a duplicate', () {
      final ledger = PhysicalReadingEventLedger();
      final s1 = CardObservedEvent(
        eventId: 'e1',
        trackId: 't1',
        sessionId: 's1',
        timestamp: t,
      );
      final s2 = CardObservedEvent(
        eventId: 'e1',
        trackId: 't1',
        sessionId: 's2',
        timestamp: t,
      );
      expect(ledger.mark(s1), isTrue);
      expect(ledger.mark(s2), isTrue);
    });

    test('a confirmed track is never re-confirmed on re-appearance', () {
      final ledger = PhysicalReadingEventLedger();
      final confirm = CardConfirmedEvent(
        eventId: 'c1',
        trackId: 't1',
        sessionId: 's1',
        timestamp: t,
        slotIndex: 2,
      );
      expect(ledger.mark(confirm), isTrue);
      expect(ledger.isTrackConfirmed('s1', 't1'), isTrue);
      // A fresh observation of the same track is a NEW event (not a dup of the
      // confirmation), but the track is already placed — consumers use
      // isTrackConfirmed to avoid re-confirming.
      final reappear = CardObservedEvent(
        eventId: 'e2',
        trackId: 't1',
        sessionId: 's1',
        timestamp: t,
      );
      expect(ledger.mark(reappear), isTrue);
      expect(ledger.isTrackConfirmed('s1', 't1'), isTrue);
    });

    test('confirmation tracking is scoped per session', () {
      final ledger = PhysicalReadingEventLedger();
      ledger.mark(
        CardConfirmedEvent(
          eventId: 'c1',
          trackId: 't1',
          sessionId: 's1',
          timestamp: t,
          slotIndex: 0,
        ),
      );
      expect(ledger.isTrackConfirmed('s1', 't1'), isTrue);
      expect(ledger.isTrackConfirmed('s2', 't1'), isFalse);
    });
  });
}
