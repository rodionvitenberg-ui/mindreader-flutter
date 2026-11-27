import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../taro_tokens.dart';

/// Vector zodiac wheel emblem rendered from the exact 24×24 geometry of
/// `assets/icons/astral_zodiac.svg`: concentric zodiac & ecliptic rings,
/// 12 sign divisions, and an inner celestial crescent with star dot.
class AstralZodiacIcon extends StatelessWidget {
  const AstralZodiacIcon({
    super.key,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? TaroColors.lavender;
    final widget = SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AstralZodiacPainter(effectiveColor),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: widget);
    return Semantics(label: semanticLabel, image: true, child: widget);
  }
}

class _AstralZodiacPainter extends CustomPainter {
  const _AstralZodiacPainter(this.color);

  final Color color;

  static final Path _crescentPath = Path()
    ..moveTo(14.641, 13.423)
    ..arcToPoint(
      const Offset(11.533, 8.902),
      radius: const Radius.circular(3.25),
      largeArc: true,
      clockwise: true,
    )
    ..arcToPoint(
      const Offset(14.641, 13.423),
      radius: const Radius.circular(2.75),
      largeArc: false,
      clockwise: false,
    )
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24.0;
    canvas.save();
    canvas.translate(
      (size.width - 24.0 * scale) / 2.0,
      (size.height - 24.0 * scale) / 2.0,
    );
    canvas.scale(scale, scale);

    const center = Offset(12, 12);
    const rOuter = 9.75;
    const rInner = 6.25;

    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = color
      ..isAntiAlias = true;
    canvas.drawCircle(center, rOuter, outerRingPaint);

    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..color = color
      ..isAntiAlias = true;
    canvas.drawCircle(center, rInner, innerRingPaint);

    final cardinalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..color = color
      ..isAntiAlias = true;

    final minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: color.a * 0.72)
      ..isAntiAlias = true;

    for (var i = 0; i < 12; i++) {
      final rad = i * math.pi / 6.0;
      final cosA = math.cos(rad);
      final sinA = math.sin(rad);
      final p0 = Offset(12.0 + rInner * cosA, 12.0 + rInner * sinA);
      final p1 = Offset(12.0 + rOuter * cosA, 12.0 + rOuter * sinA);
      canvas.drawLine(p0, p1, i % 3 == 0 ? cardinalPaint : minorPaint);
    }

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;
    canvas.drawPath(_crescentPath, fillPaint);
    canvas.drawCircle(const Offset(13.75, 10.55), 0.9, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AstralZodiacPainter oldDelegate) =>
      oldDelegate.color != color;
}
