import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/services/vision/vision_engine.dart';
import 'package:mindreader/design_system/taro_tokens.dart';
import 'package:mindreader/features/camera_scan/widgets/card_overlay_painter.dart';

/// Phase 1 (1.6) — the viewfinder lock-on overlay is painted from the Vision
/// contract data alone: normalized→viewfinder mapping, per-state styling from
/// [TaroColors], and a hard rule that a candidate without geometry paints
/// NOTHING (no invented bounding boxes).
VisionCardCandidate _candidate({
  String id = 'o1',
  RecognitionStatus status = RecognitionStatus.recognized,
  CardFaceState face = CardFaceState.faceUp,
  NormalizedRect? box = const NormalizedRect(
    left: 0.25,
    top: 0.25,
    right: 0.75,
    bottom: 0.75,
  ),
  List<NormalizedPoint>? corners,
}) {
  return VisionCardCandidate(
    observationId: id,
    trackId: id,
    system: DivinationSystem.tarot,
    timestamp: DateTime(2024, 1, 1),
    faceState: face,
    recognitionStatus: status,
    boundingBox: box,
    corners: corners,
  );
}

void main() {
  test('normalizedToView maps and clamps 0..1 boxes to viewfinder pixels',
      () {
    const size = Size(400, 800);

    expect(
      normalizedToView(
        const NormalizedRect(left: 0, top: 0, right: 1, bottom: 1),
        size,
      ),
      const Rect.fromLTRB(0, 0, 400, 800),
    );

    expect(
      normalizedToView(
        const NormalizedRect(left: 0.25, top: 0.25, right: 0.75, bottom: 0.5),
        size,
      ),
      const Rect.fromLTRB(100, 200, 300, 400),
    );

    // Out-of-range boxes clamp to the canvas instead of painting off-screen.
    expect(
      normalizedToView(
        const NormalizedRect(left: -0.2, top: -0.2, right: 1.2, bottom: 1.2),
        size,
      ),
      const Rect.fromLTRB(0, 0, 400, 800),
    );
  });

  test('rectForCandidate returns null when there is no geometry', () {
    final noGeometry = _candidate(box: null);
    expect(rectForCandidate(noGeometry, const Size(400, 800)), isNull);
  });

  test('rectForCandidate derives a box from corners when bbox is absent', () {
    final cornersOnly = _candidate(
      box: null,
      corners: const [
        NormalizedPoint(0.1, 0.2),
        NormalizedPoint(0.9, 0.2),
        NormalizedPoint(0.9, 0.8),
        NormalizedPoint(0.1, 0.8),
      ],
    );
    expect(
      rectForCandidate(cornersOnly, const Size(400, 800)),
      const Rect.fromLTRB(40, 160, 360, 640),
    );
  });

  test('overlayStyleFor maps each recognition state to TaroColors', () {
    expect(
      overlayStyleFor(_candidate(status: RecognitionStatus.recognized)).color,
      TaroColors.lavender,
    );
    expect(
      overlayStyleFor(_candidate(status: RecognitionStatus.recognized)).dashed,
      isFalse,
    );

    expect(
      overlayStyleFor(_candidate(status: RecognitionStatus.recognizing)).dashed,
      isTrue,
    );
    expect(
      overlayStyleFor(_candidate(status: RecognitionStatus.ambiguous)).color,
      TaroColors.amber,
    );

    // A face-down card dims even when recognition says `recognized`.
    final faceDown = overlayStyleFor(
      _candidate(
        status: RecognitionStatus.recognized,
        face: CardFaceState.faceDown,
      ),
    );
    expect(faceDown.dashed, isTrue);
    expect(faceDown.color.a, lessThan(128));

    final lost = overlayStyleFor(_candidate(status: RecognitionStatus.lost));
    expect(lost.dashed, isTrue);
    expect(lost.color.a, lessThan(128));
  });

  test('shouldRepaint reacts to data changes only', () {
    final a = _candidate(id: 'a');
    final b = _candidate(id: 'b', status: RecognitionStatus.ambiguous);

    expect(
      CardOverlayPainter(candidates: [a])
          .shouldRepaint(CardOverlayPainter(candidates: [a])),
      isFalse,
    );
    expect(
      CardOverlayPainter(candidates: [b])
          .shouldRepaint(CardOverlayPainter(candidates: [a])),
      isTrue,
    );
  });

  testWidgets('paint tolerates geometry-less candidates without throwing',
      (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomPaint(
          size: const Size(400, 800),
          painter: CardOverlayPainter(
            candidates: [
              _candidate(box: null), // no geometry -> draws nothing
              _candidate(status: RecognitionStatus.recognizing),
              _candidate(
                status: RecognitionStatus.ambiguous,
                face: CardFaceState.faceDown,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
