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

  static const _stemEndProgress = 0.86;
  static const _leafNodes = [
    (0.20, 1.0),
    (0.42, -1.0),
    (0.64, 1.0),
    (0.82, -1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    for (final segment in segments) {
      final delta = segment.end - segment.start;
      final dist = delta.distance;
      if (dist < 1) continue;
      final normal = Offset(-delta.dy, delta.dx) / dist;
      final amp = math.min(14.0, dist * 0.16);
      final cp1 = segment.start + delta * 0.32 + normal * amp;
      final cp2 = segment.start + delta * 0.68 - normal * (amp * 0.75);
      final path = Path()
        ..moveTo(segment.start.dx, segment.start.dy)
        ..cubicTo(
          cp1.dx,
          cp1.dy,
          cp2.dx,
          cp2.dy,
          segment.end.dx,
          segment.end.dy,
        );
      final metric = path.computeMetrics().first;
      final color = switch (segment.element) {
        Element.fire => const Color(0xffd4a56d),
        Element.water => const Color(0xff83aaca),
        Element.air => const Color(0xffb9b1ce),
        Element.earth => const Color(0xff92ac8d),
      };

      final stemFraction = Curves.easeInOutSine.transform(
        (p / _stemEndProgress).clamp(0.0, 1.0),
      );
      final grownLen = metric.length * stemFraction;
      if (grownLen <= 0) continue;

      // Soft elemental aura behind the growing stem.
      final auraPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawPath(metric.extractPath(0, grownLen), auraPaint);

      // Tapered woody stem: fuller at the root, slender at the growing tip.
      const slices = 10;
      for (var i = 0; i < slices; i++) {
        final t0 = i / slices;
        final t1 = (i + 1) / slices;
        final stemPaint = Paint()
          ..color = color.withValues(alpha: 0.84 - 0.10 * t0)
          ..strokeWidth = 3.0 - 1.8 * t0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
          metric.extractPath(grownLen * t0, grownLen * t1),
          stemPaint,
        );
      }

      // Living sprouting tip while the branch is actively extending.
      if (stemFraction > 0.02 && stemFraction < 0.99) {
        final tip = metric.getTangentForOffset(grownLen);
        if (tip != null) {
          final tipAlpha = math
              .min(stemFraction / 0.10, (1 - stemFraction) / 0.12)
              .clamp(0.0, 1.0);
          canvas.drawCircle(
            tip.position,
            4.6,
            Paint()
              ..color = color.withValues(alpha: 0.36 * tipAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
          );
          canvas.drawCircle(
            tip.position,
            2.1,
            Paint()
              ..color = Color.lerp(color, Colors.white, 0.45)!
                  .withValues(alpha: 0.95 * tipAlpha),
          );
        }
      }

      final twigPaint = Paint()
        ..color = color.withValues(alpha: 0.82)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final leafPaint = Paint()
        ..color = color.withValues(alpha: 0.94)
        ..style = PaintingStyle.fill;

      for (final (position, side) in _leafNodes) {
        // Exact progress when the easeInOutSine stem tip reaches this joint.
        final reach =
            (math.acos(1 - 2 * position) / math.pi) * _stemEndProgress;
        final age = ((p - reach) / 0.34).clamp(0.0, 1.0);
        if (age > 0) {
          _paintLeaf(
            canvas,
            metric,
            position,
            side,
            age,
            color,
            twigPaint,
            leafPaint,
          );
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
    Color baseColor,
    Paint wood,
    Paint foliage,
  ) {
    final joint = stem.getTangentForOffset(stem.length * position)!;
    final forward = joint.vector;
    final outward = Offset(-forward.dy, forward.dx) * side;
    final unit = math.max(12.0, math.min(20.0, stem.length * 0.24));
    final sprout = Curves.easeOut.transform((age / 0.36).clamp(0.0, 1.0));
    final root =
        joint.position + (forward * 0.22 + outward * 0.40) * unit * sprout;
    canvas.drawLine(joint.position, root, wood);

    final bloom = Curves.easeOutCubic.transform(
      ((age - 0.18) / 0.82).clamp(0.0, 1.0),
    );
    if (bloom == 0) return;

    // The bud lengthens first, then its two curved edges unfurl sideways.
    final axis = (forward * 0.62 + outward * 0.78) * unit * bloom;
    final width = Offset(-axis.dy, axis.dx) * (0.40 * bloom);
    final tip = root + axis;
    final upper = root + axis * 0.52 + width;
    final lower = root + axis * 0.38 - width;
    canvas.drawPath(
      Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(upper.dx, upper.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(lower.dx, lower.dy, root.dx, root.dy)
        ..close(),
      foliage,
    );

    // Subtle midrib highlight across the unfurling leaf.
    canvas.drawLine(
      root,
      root + axis * 0.72,
      Paint()
        ..color = Color.lerp(baseColor, Colors.white, 0.35)!
            .withValues(alpha: 0.45 * bloom)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ElementalBranchPainter old) =>
      old.progress != progress || !listEquals(old.segments, segments);
}
