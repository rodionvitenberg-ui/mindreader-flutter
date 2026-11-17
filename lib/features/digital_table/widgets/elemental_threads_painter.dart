import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/services/oracle_synthesis_service.dart';

/// Ignite flash duration: the thread shoots like a bolt of elemental energy
/// from Card N down into Card N+1 the moment both cards are face-up —
/// 480ms, with a brief bright flare (2.0x glow settling to 1.0x).
const igniteFlashDuration = Duration(milliseconds: 480);

/// Elemental thread gradient pairs (start → end):
/// Fire = amber-crimson, Water = cyan-indigo, Air = silver-violet,
/// Earth = emerald-gold.
List<Color> elementalThreadColors(Element e) => switch (e) {
      Element.fire => const [Color(0xFFF59E0B), Color(0xFFDC2626)],
      Element.water => const [Color(0xFF38BDF8), Color(0xFF6366F1)],
      Element.air => const [Color(0xFFCBD5E1), Color(0xFFA78BFA)],
      Element.earth => const [Color(0xFF34D399), Color(0xFFFBBF24)],
    };

/// One living Elemental Fate Thread: a smooth, oscillating string from the
/// inside of card A's edge to the inside of card B's edge, colored by the
/// elemental pairing of the two cards.
class ElementalThreadSegment {
  const ElementalThreadSegment({
    required this.from,
    required this.to,
    required this.elementA,
    required this.elementB,
    required this.tone,
    this.pairKey = 0,
  });

  final Offset from;
  final Offset to;
  final Element elementA;
  final Element elementB;
  final ThreadTone tone;

  /// Stable identity of the connected pair = the slot index of the FIRST
  /// card of the pair. Hosts key their per-pair ignite animations by it.
  final int pairKey;
}

/// The point where the ray from [rect]'s center toward [target] exits the
/// rect — i.e. the anchor where a thread leaves/enters a card. With
/// [inset] > 0 the anchor sits that many pixels INSIDE the facing edge, so
/// the cord physically reaches into both cards (zero visible gap).
Offset rectEdgeToward(Rect rect, Offset target, {double inset = 0}) {
  final r = inset > 0 ? rect.deflate(inset) : rect;
  final c = r.center;
  final d = target - c;
  if (d.dx.abs() < 1e-6 && d.dy.abs() < 1e-6) return c;
  var t = double.infinity;
  if (d.dx.abs() > 1e-6) {
    final tx = (d.dx > 0 ? (r.right - c.dx) : (r.left - c.dx)) / d.dx;
    if (tx > 0) t = math.min(t, tx);
  }
  if (d.dy.abs() > 1e-6) {
    final ty = (d.dy > 0 ? (r.bottom - c.dy) : (r.top - c.dy)) / d.dy;
    if (ty > 0) t = math.min(t, ty);
  }
  return c + d * t;
}

/// Builds the thread segments between each pair of ADJACENT face-up cards:
/// [dealt] is the list of cards in reading order, [rects] their parallel
/// card rectangles (same order). Every anchor sits 8 px INSIDE the facing
/// edge of its card — a full card-to-card connection with zero gap.
List<ElementalThreadSegment> threadSegmentsFor(
  List<DealtCardSlot> dealt,
  List<Rect> rects,
) {
  final segments = <ElementalThreadSegment>[];
  for (var i = 0; i < dealt.length - 1; i++) {
    final a = dealt[i];
    final b = dealt[i + 1];
    final bothUp = a.state == SlotState.faceUp && b.state == SlotState.faceUp;
    if (!bothUp || a.card == null || b.card == null) continue;
    segments.add(ElementalThreadSegment(
      from: rectEdgeToward(rects[i], rects[i + 1].center, inset: 8.0),
      to: rectEdgeToward(rects[i + 1], rects[i].center, inset: 8.0),
      elementA: a.card!.element,
      elementB: b.card!.element,
      tone: dignityBetweenElements(a.card!.element, b.card!.element),
      pairKey: a.index,
    ));
  }
  return segments;
}

/// Animated glowing elemental strings connecting adjacent face-up cards:
/// a TAUT, nearly straight cord — maximum transverse deviation 3.0 logical
/// px (2.5–3.5 spec), a single gentle sine with a slow MEDITATIVE
/// wall-clock wave period of 4.5–5.0 s (no deep S-curves, no rubber-noodle
/// bends), 4 slow-gliding luminous particles that traverse the whole cord
/// in the same period, and a gradient that color-blends the elemental
/// pairing of the two connected cards. Tension threads breathe slightly
/// faster than harmonious ones. The host's repeating controller is wired
/// through `super(repaint:)`, so the painter repaints EVERY tick at frame
/// rate — the cords never freeze.
///
/// CORD SPEC: a 4.5 px crisp core over a 14.0 px blurred aura
/// (`MaskFilter.blur(BlurStyle.normal, 10.0)`).
///
/// IGNITE: while [ignite] is below 1.0 for a segment, the cord is drawn
/// progressively — it shoots like a bolt of elemental energy from Card N
/// down into Card N+1 with a bright head flare at 2.0x glow settling to
/// 1.0x once fully lit.
class ElementalThreadsPainter extends CustomPainter {
  ElementalThreadsPainter({
    required this.segments,
    required this.pulse,
    this.ignite,
  }) : super(repaint: pulse);

  final List<ElementalThreadSegment> segments;
  final Animation<double> pulse;

  /// Segment index → ignite progress (0 = not yet shot, 1 = fully lit).
  /// A missing entry renders the segment fully ignited.
  final Map<int, double>? ignite;

  /// Monotonic wall-clock shared by every painter instance — the wave
  /// period is exact seconds regardless of the host's pulse duration.
  static final Stopwatch _clock = Stopwatch()..start();

  /// The maximum transverse deviation of the taut cord: 3.0 logical px.
  static const tautAmplitude = 3.0;

  /// One full sine breath in seconds per tone: 4.5–5.0 s (meditative).
  /// Tension runs marginally faster than harmony.
  static double _periodSeconds(ThreadTone tone) => switch (tone) {
        ThreadTone.harmony => 5.0,
        ThreadTone.conflict => 4.5,
        ThreadTone.neutral => 4.75,
      };

  static Offset _pointAt(
    ElementalThreadSegment seg,
    double s,
    double phase,
  ) {
    final d = seg.to - seg.from;
    final dir = d / d.distance;
    final normal = Offset(-dir.dy, dir.dx);
    // One gentle sine breathing — the cord stays taut and nearly
    // straight between the two cards (max 3.0 px, never deep S-curves).
    final wobble = tautAmplitude * math.sin(2 * math.pi * s + phase);
    return seg.from + d * s + normal * wobble;
  }

  void _paintSegment(
    Canvas canvas,
    ElementalThreadSegment seg,
    int i,
    double ignite,
  ) {
    final d = seg.to - seg.from;
    if (d.distance < 2) return;
    final ig = ignite.clamp(0.0, 1.0);
    if (ig <= 0) return;

    // Slow meditative breathing: one full sine wave takes 4.5–5.0 s of
    // wall-clock time (3x slower than the old fast oscillation).
    final elapsed = _clock.elapsedMicroseconds / 1e6;
    final period = _periodSeconds(seg.tone);
    final phase = 2 * math.pi * elapsed / period + i * 1.7;

    final path = Path()..moveTo(seg.from.dx, seg.from.dy);
    const steps = 24;
    for (var k = 1; k <= steps; k++) {
      final p = _pointAt(seg, k / steps, phase);
      path.lineTo(p.dx, p.dy);
    }

    // Ignite: the bolt shoots from Card N toward Card N+1 — only the
    // traveled fraction of the cord is drawn, headed by a bright flare.
    var drawPath = path;
    Offset? boltHead;
    if (ig < 1.0) {
      for (final metric in path.computeMetrics()) {
        drawPath = metric.extractPath(0, metric.length * ig);
        boltHead = metric.getTangentForOffset(metric.length * ig)?.position;
      }
    }

    // Color-blend the gradient across the elemental pairing.
    final colorsA = elementalThreadColors(seg.elementA);
    final colorsB = elementalThreadColors(seg.elementB);
    final mid = Color.lerp(colorsA[1], colorsB[0], 0.5)!;
    final shader = LinearGradient(
      colors: [colorsA[0], mid, colorsB[1]],
      transform: GradientRotation(math.atan2(d.dy, d.dx)),
    ).createShader(Rect.fromPoints(seg.from, seg.to));

    // Gentle 6-second breathing of the aura's brightness — calm, slow.
    final breath =
        0.30 + 0.14 * math.sin(2 * math.pi * elapsed / 6.0 + i * 1.3);
    // Brief bright flare while igniting: 2.0x glow settling to 1.0x.
    final flare = 1.0 + (1.0 - ig);

    // Outer luminous aura — 14.0 px, blur 10.0.
    canvas.drawPath(
      drawPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..shader = shader
        ..color = Colors.white.withValues(alpha: (0.16 + 0.14 * breath) * flare)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
    );
    // Crisp 4.5 px core cord.
    canvas.drawPath(
      drawPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..shader = shader
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    // Four luminous energy particles SLOWLY gliding along the string —
    // each takes the full 4.5–5.0 s breath to cross the cord.
    for (final offset in const [0.0, 0.25, 0.5, 0.75]) {
      final s = (elapsed / period + i * 0.23 + offset) % 1.0;
      if (s > ig) continue; // never run ahead of an igniting bolt
      final dot = _pointAt(seg, s, phase);
      final dotColor = Color.lerp(colorsA[0], colorsB[1], s)!;
      canvas.drawCircle(
        dot,
        3.5,
        Paint()
          ..color = dotColor.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // The bolt head: a bright elemental flare while the cord is shooting.
    if (boltHead != null && ig < 1.0) {
      canvas.drawCircle(
        boltHead,
        5.0 + 3.0 * (1.0 - ig),
        Paint()
          ..color = Color.lerp(colorsA[1], colorsB[0], ig)!
              .withValues(alpha: 0.95 * (1.0 - ig))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < segments.length; i++) {
      _paintSegment(canvas, segments[i], i, ignite?[i] ?? 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant ElementalThreadsPainter oldDelegate) {
    if (oldDelegate.pulse != pulse) return true;
    if (oldDelegate.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      final a = oldDelegate.segments[i];
      final b = segments[i];
      if (a.from != b.from ||
          a.to != b.to ||
          a.elementA != b.elementA ||
          a.elementB != b.elementB ||
          a.tone != b.tone ||
          a.pairKey != b.pairKey) {
        return true;
      }
    }
    final oldIgnite = oldDelegate.ignite;
    final newIgnite = ignite;
    if ((oldIgnite == null) != (newIgnite == null)) return true;
    if (oldIgnite != null && newIgnite != null) {
      if (oldIgnite.length != newIgnite.length) return true;
      for (final entry in oldIgnite.entries) {
        if (newIgnite[entry.key] != entry.value) return true;
      }
    }
    return false;
  }
}
