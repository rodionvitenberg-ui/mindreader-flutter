import 'package:flutter/material.dart';

/// Minimalist geometric eye icon for Tarot Tree.
///
/// Synchronous CustomPainter so it renders on the very first frame without
/// async SVG decode flicker.
class SeerEyeIcon extends StatelessWidget {
  const SeerEyeIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SeerEyePainter(color: color),
      ),
    );
  }
}

class _SeerEyePainter extends CustomPainter {
  const _SeerEyePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    canvas.save();
    final scale = s / 24.0;
    canvas.scale(scale, scale);

    final strokeWidth = (1.65 * (s < 18 ? 1.1 : 1.0)).clamp(1.4, 1.9);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Clean almond eye outline centered at y = 12
    final eyePath = Path()
      ..moveTo(2.0, 12.0)
      ..cubicTo(5.6, 5.2, 18.4, 5.2, 22.0, 12.0)
      ..cubicTo(18.4, 18.8, 5.6, 18.8, 2.0, 12.0)
      ..close();
    canvas.drawPath(eyePath, stroke);

    // 2. Simple centered iris ring
    canvas.drawCircle(const Offset(12.0, 12.0), 3.2, stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeerEyePainter oldDelegate) => oldDelegate.color != color;
}
