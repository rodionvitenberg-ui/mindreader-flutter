import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../../core/models/divination_system.dart';
import '../../../core/models/tarot_card_model.dart';

bool elementalThreadsVisibleFor(DivinationSystem system) =>
    system == DivinationSystem.tarot;

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

typedef BranchSegment = ({Offset start, Offset end, Element element});

class ElementalBranchPainter extends CustomPainter {
  const ElementalBranchPainter(this.segments, this.progress);
  final List<BranchSegment> segments;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final segment in segments) {
      final delta = segment.end - segment.start;
      if (delta.distance < 1) continue;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance;
      final bend = normal * math.min(12, delta.distance * .12).toDouble();
      final middle = segment.start + delta * .5;
      final tip = segment.end;
      final path = Path()
        ..moveTo(segment.start.dx, segment.start.dy)
        ..quadraticBezierTo(
          middle.dx + bend.dx,
          middle.dy + bend.dy,
          tip.dx,
          tip.dy,
        );
      final metric = path.computeMetrics().first;
      final color = switch (segment.element) {
        Element.fire => const Color(0xffd4a56d),
        Element.water => const Color(0xff83aaca),
        Element.air => const Color(0xffb9b1ce),
        Element.earth => const Color(0xff92ac8d),
      };
      final paint = Paint()
        ..color = color.withValues(alpha: .72)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
      for (final t in [.36, .64]) {
        if (progress <= t) continue;
        final joint = metric.getTangentForOffset(metric.length * t)!;
        final twig = joint.vector * 8 + normal * (t < .5 ? 6 : -6);
        canvas.drawLine(
          joint.position,
          joint.position + twig * ((progress - t) / .2).clamp(0, 1),
          paint..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ElementalBranchPainter old) =>
      old.progress != progress || old.segments != segments;
}
