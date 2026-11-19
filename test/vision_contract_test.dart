import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/services/vision/legacy_vision_adapter.dart';
import 'package:mindreader/core/services/vision/unavailable_vision_engine.dart';
import 'package:mindreader/core/services/vision/vision_engine.dart';

import 'fakes/fake_vision_engine.dart';

void main() {
  group('normalized coordinates are 0..1', () {
    test('clamp01 clamps into the unit interval', () {
      expect(clamp01(-0.5), 0.0);
      expect(clamp01(0.3), 0.3);
      expect(clamp01(1.7), 1.0);
    });

    test('NormalizedPoint.clamped clamps both axes', () {
      const p = NormalizedPoint(-0.2, 1.4);
      expect(p.clamped(), const NormalizedPoint(0.0, 1.0));
    });

    test(
      'NormalizedRect.isNormalized rejects out-of-bounds and inverted boxes',
      () {
        const good = NormalizedRect(
          left: 0.1,
          top: 0.1,
          right: 0.9,
          bottom: 0.9,
        );
        expect(good.isNormalized, isTrue);

        const outOfBounds = NormalizedRect(
          left: -0.1,
          top: 0,
          right: 0.5,
          bottom: 0.5,
        );
        expect(outOfBounds.isNormalized, isFalse);

        const inverted = NormalizedRect(
          left: 0.9,
          top: 0.1,
          right: 0.1,
          bottom: 0.9,
        );
        expect(inverted.isNormalized, isFalse);
      },
    );

    test('NormalizedRect.clamped normalizes a degenerate box', () {
      const raw = NormalizedRect(left: -1, top: 0, right: 2, bottom: 3);
      final clamped = raw.clamped();
      expect(clamped.left, 0.0);
      expect(clamped.top, 0.0);
      expect(clamped.right, 1.0);
      expect(clamped.bottom, 1.0);
      expect(clamped.isNormalized, isTrue);
    });
  });

  group('cancellation', () {
    test(
      'a cancelled token makes scanImage throw VisionCancelledException',
      () async {
        final engine = FakeVisionEngine(delay: const Duration(milliseconds: 1));
        final token = CancelToken()..cancel();
        await expectLater(
          engine.scanImage(FakeVisionEngine.frame(), cancelToken: token),
          throwsA(isA<VisionCancelledException>()),
        );
      },
    );

    test('an uncancelled token lets the scan complete', () async {
      final engine = FakeVisionEngine();
      engine.enqueueResult(
        VisionScanResult(
          candidates: [FakeVisionEngine.candidate()],
          observations: const [],
        ),
      );
      final result = await engine.scanImage(
        FakeVisionEngine.frame(),
        cancelToken: CancelToken(),
      );
      expect(result.detectedCount, 1);
    });
  });

  group('stale-frame rejection', () {
    test('VisionFrameGate rejects an older frame for the same session', () {
      final gate = VisionFrameGate();
      final newer = FakeVisionEngine.frame(
        timestamp: DateTime(2026, 11, 18, 12, 0),
      );
      final older = FakeVisionEngine.frame(
        timestamp: DateTime(2026, 11, 18, 11, 0),
      );
      expect(gate.guard('s1', newer), isNull);
      expect(gate.guard('s1', older), isNotNull);
      // A different session has its own timeline.
      expect(gate.guard('s2', older), isNull);
    });

    test('a frame with no timestamp is never stale', () {
      final gate = VisionFrameGate();
      final a = FakeVisionEngine.frame(
        bytes: [1],
        timestamp: DateTime(2026, 11, 18, 12, 0),
      );
      final noTimestamp = VisionFrame(
        bytes: Uint8List.fromList(const [2]),
        sourceWidth: 10,
        sourceHeight: 10,
      );
      gate.guard('s', a);
      expect(gate.guard('s', noTimestamp), isNull);
    });

    test(
      'FakeVisionEngine throws StaleVisionFrameException on an old frame',
      () async {
        final engine = FakeVisionEngine();
        final newer = FakeVisionEngine.frame(
          timestamp: DateTime(2026, 11, 18, 12, 0),
        );
        final older = FakeVisionEngine.frame(
          timestamp: DateTime(2026, 11, 18, 11, 0),
        );
        await engine.scanImage(newer, sessionId: 's');
        await expectLater(
          engine.scanImage(older, sessionId: 's'),
          throwsA(isA<StaleVisionFrameException>()),
        );
      },
    );
  });

  group('scripted scenarios', () {
    test('many cards and face-down/unknown states round-trip', () async {
      final engine = FakeVisionEngine();
      engine.enqueueResult(
        VisionScanResult(
          candidates: [
            FakeVisionEngine.candidate(
              observationId: 'a',
              canonicalCardId: 1,
              faceState: CardFaceState.faceDown,
              status: RecognitionStatus.detected,
            ),
            FakeVisionEngine.candidate(
              observationId: 'b',
              canonicalCardId: null,
              orientation: CardOrientation.unknown,
              status: RecognitionStatus.ambiguous,
            ),
            FakeVisionEngine.candidate(
              observationId: 'c',
              canonicalCardId: 2,
              orientation: CardOrientation.reversed,
            ),
          ],
          observations: const [],
        ),
      );
      final result = await engine.scanImage(FakeVisionEngine.frame());
      expect(result.detectedCount, 3);
      expect(result.candidates[0].faceState, CardFaceState.faceDown);
      expect(
        result.candidates[0].recognitionStatus,
        RecognitionStatus.detected,
      );
      expect(result.candidates[1].canonicalCardId, isNull);
      expect(
        result.candidates[1].recognitionStatus,
        RecognitionStatus.ambiguous,
      );
      expect(result.candidates[2].orientation, CardOrientation.reversed);
    });

    test('scripted failure throws VisionEngineException', () async {
      final engine = FakeVisionEngine()..failOnScan = true;
      await expectLater(
        engine.scanImage(FakeVisionEngine.frame()),
        throwsA(isA<VisionEngineException>()),
      );
    });

    test('startSession streams scripted events in order', () async {
      final engine = FakeVisionEngine();
      final t = DateTime.fromMillisecondsSinceEpoch(0);
      engine.enqueueEvent(
        VisionEvent(
          type: VisionEventType.observed,
          candidate: FakeVisionEngine.candidate(observationId: '1'),
          timestamp: t,
        ),
      );
      engine.enqueueEvent(
        VisionEvent(
          type: VisionEventType.lost,
          candidate: FakeVisionEngine.candidate(observationId: '1'),
          timestamp: t,
        ),
      );
      final events = await engine.startSession(sessionId: 's').toList();
      expect(events.map((e) => e.type), [
        VisionEventType.observed,
        VisionEventType.lost,
      ]);
    });

    test('dispose is idempotent and tracked', () async {
      final engine = FakeVisionEngine();
      await engine.dispose();
      await engine.dispose();
      expect(engine.disposeCalls, 2);
    });
  });

  group('legacy adapter', () {
    test('detectSpread cardCount is optional: count comes from the result', () async {
      // No PRIMARY_WORKER_URL / VISION_API_URL in the test env → offline mock.
      final adapter = LegacyVisionAdapter();
      final result = await adapter.scanImage(
        FakeVisionEngine.frame(bytes: List.generate(64, (i) => i)),
      );
      expect(result.detectedCount, greaterThanOrEqualTo(1));
      expect(result.detectedCount, lessThanOrEqualTo(6));
      for (final c in result.candidates) {
        expect(c.system, DivinationSystem.tarot);
        expect(c.recognitionStatus, RecognitionStatus.recognized);
        expect(c.faceState, CardFaceState.faceUp);
        expect(c.canonicalCardId, isNotNull);
        expect(c.canonicalCardId, inInclusiveRange(0, 77));
        // No invented confidence or geometry.
        expect(c.recognitionConfidence, isNull);
        expect(c.boundingBox, isNull);
      }
    });

    test('adapter maps the reversed flag onto CardOrientation', () async {
      final adapter = LegacyVisionAdapter();
      // The mock's orientation is deterministic per image — every candidate
      // must be either upright or reversed, never unknown.
      final result = await adapter.scanImage(
        FakeVisionEngine.frame(bytes: List.generate(128, (i) => i * 7)),
      );
      for (final c in result.candidates) {
        expect(c.orientation, isNot(CardOrientation.unknown));
      }
    });
  });

  group('unavailable engine', () {
    test('is unavailable and demands manual fallback', () async {
      const engine = UnavailableVisionEngine();
      expect(engine.capabilities.isAvailable, isFalse);
      expect(engine.capabilities.supportsRecognition, isFalse);
      final result = await engine.scanImage(FakeVisionEngine.frame());
      expect(result.candidates, isEmpty);
      expect(result.manualFallbackRequired, isTrue);
    });
  });
}
