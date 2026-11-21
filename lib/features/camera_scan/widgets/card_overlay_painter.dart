import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../core/services/vision/vision_engine.dart';
import '../../../design_system/taro_tokens.dart';

/// Visual style for one detected/recognized card region.
class OverlayStyle {
  const OverlayStyle({
    required this.color,
    required this.dashed,
    this.strokeWidth = 2.2,
  });

  final Color color;
  final bool dashed;
  final double strokeWidth;
}

/// Maps a candidate's recognition + face state to a viewfinder style. Colors
/// come only from [TaroColors] (lavender / amber / mist); a card that is
/// face-down or lost dims instead of disappearing. Face-down wins over
/// recognition — a face-down card cannot be "recognized" by definition.
OverlayStyle overlayStyleFor(VisionCardCandidate c) {
  if (c.faceState == CardFaceState.faceDown) {
    return OverlayStyle(
      color: TaroColors.lavender.withValues(alpha: 0.35),
      dashed: true,
      strokeWidth: 1.6,
    );
  }
  return switch (c.recognitionStatus) {
    RecognitionStatus.detected => OverlayStyle(
      color: TaroColors.lavender.withValues(alpha: 0.6),
      dashed: false,
      strokeWidth: 1.6,
    ),
    RecognitionStatus.recognizing => const OverlayStyle(
      color: TaroColors.lavender,
      dashed: true,
    ),
    RecognitionStatus.recognized => const OverlayStyle(
      color: TaroColors.lavender,
      dashed: false,
    ),
    RecognitionStatus.ambiguous => const OverlayStyle(
      color: TaroColors.amber,
      dashed: false,
    ),
    RecognitionStatus.lost => OverlayStyle(
      color: TaroColors.mist.withValues(alpha: 0.4),
      dashed: true,
      strokeWidth: 1.4,
    ),
    RecognitionStatus.unknown => OverlayStyle(
      color: TaroColors.lavender.withValues(alpha: 0.5),
      dashed: true,
      strokeWidth: 1.6,
    ),
  };
}

/// Maps a normalized 0..1 box into viewfinder pixel coordinates. Defensively
/// clamps the source box first, so an out-of-range engine box never paints
/// off-canvas.
Rect normalizedToView(NormalizedRect box, Size size) {
  final b = box.clamped();
  return Rect.fromLTRB(
    b.left * size.width,
    b.top * size.height,
    b.right * size.width,
    b.bottom * size.height,
  );
}

/// The pixel rect for a candidate, from its [NormalizedRect] bounding box or
/// its corners (whichever is present). Returns null when the candidate
/// carries no geometry at all — the painter then draws NOTHING for it, so an
/// absent provider never invents a bounding box.
Rect? rectForCandidate(VisionCardCandidate c, Size size) {
  final box = c.boundingBox;
  if (box != null) return normalizedToView(box, size);
  final corners = c.corners;
  if (corners != null && corners.length >= 2) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in corners) {
      final q = p.clamped();
      minX = math.min(minX, q.x);
      minY = math.min(minY, q.y);
      maxX = math.max(maxX, q.x);
      maxY = math.max(maxY, q.y);
    }
    return Rect.fromLTRB(
      minX * size.width,
      minY * size.height,
      maxX * size.width,
      maxY * size.height,
    );
  }
  return null;
}

/// Paints the viewfinder lock-on overlay for [candidates] (recognized/
/// recognizing regions) and [observations] (raw detections). The caller wraps
/// this in a [RepaintBoundary] and passes a [Listenable] so 120 FPS tracking
/// updates repaint only this layer, never the whole camera tree.
class CardOverlayPainter extends CustomPainter {
  CardOverlayPainter({
    required this.candidates,
    this.observations = const [],
    super.repaint,
  });

  final List<VisionCardCandidate> candidates;

  /// Raw detections without recognition — drawn as the faintest outline.
  final List<VisionObservation> observations;

  @override
  void paint(Canvas canvas, Size size) {
    final detectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = TaroColors.lavender.withValues(alpha: 0.4);
    for (final o in observations) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          normalizedToView(o.boundingBox, size),
          const Radius.circular(10),
        ),
        detectionPaint,
      );
    }

    for (final c in candidates) {
      final rect = rectForCandidate(c, size);
      if (rect == null) continue; // no geometry -> draw nothing
      _paintStyledRect(canvas, rect, overlayStyleFor(c));
    }
  }

  void _paintStyledRect(Canvas canvas, Rect rect, OverlayStyle style) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.strokeWidth
      ..color = style.color;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    if (style.dashed) {
      _drawDashed(canvas, Path()..addRRect(rrect), paint);
    } else {
      canvas.drawRRect(rrect, paint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CardOverlayPainter oldDelegate) =>
      !listEquals(oldDelegate.candidates, candidates) ||
      !listEquals(oldDelegate.observations, observations);
}
