import 'dart:math' as math;

import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show listEquals;
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
      final stem = (progress / .9).clamp(0.0, 1.0);
      canvas.drawPath(metric.extractPath(0, metric.length * stem), paint);
      final leafPaint = Paint()..color = color.withValues(alpha: .94);
      for (final (position, side) in const [
        (.23, 1.0),
        (.49, -1.0),
        (.76, 1.0),
      ]) {
        // Each bud starts only after the growing tip reaches its joint.
        final age = ((progress - position * .9) / .30).clamp(0.0, 1.0);
        if (age > 0) {
          _paintLeaf(canvas, metric, position, side, age, paint, leafPaint);
        }
      }
    }
  }

  void _paintLeaf(
    Canvas canvas,
    PathMetric stem,
    double position,
    double side,
    double age,
    Paint wood,
    Paint foliage,
  ) {
    final joint = stem.getTangentForOffset(stem.length * position)!;
    final forward = joint.vector;
    final outward = Offset(-forward.dy, forward.dx) * side;
    final unit = math.min(15.0, stem.length * .18);
    final sprout = (age / .4).clamp(0.0, 1.0);
    final root =
        joint.position + (forward * .24 + outward * .38) * unit * sprout;
    canvas.drawLine(joint.position, root, wood);
    final bloom = Curves.easeOut.transform(((age - .24) / .76).clamp(0.0, 1.0));
    if (bloom == 0) return;
    // The bud lengthens first, then its two curved edges unfurl sideways.
    final axis = (forward * .66 + outward * .75) * unit * bloom;
    final width = Offset(-axis.dy, axis.dx) * (.36 * bloom);
    final tip = root + axis;
    final upper = root + axis * .52 + width;
    final lower = root + axis * .40 - width;
    canvas.drawPath(
      Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(upper.dx, upper.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(lower.dx, lower.dy, root.dx, root.dy)
        ..close(),
      foliage,
    );
  }

  @override
  bool shouldRepaint(ElementalBranchPainter old) =>
      old.progress != progress || !listEquals(old.segments, segments);
}
