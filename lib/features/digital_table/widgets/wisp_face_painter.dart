import 'package:flutter/material.dart';

import 'wisp_mood.dart';

/// The wisp's procedural face (G2.2).
///
/// The body and veil come from the authored sprite; every expression is drawn
/// here so the mimicry stays crisp at any size and needs no extra sprites.
/// Eyes: `^ ^` greeting, wide `o o` curiosity, soft tilted arcs for sympathy,
/// uneven arches while thinking, closed lines when sleeping.
class WispFacePainter extends CustomPainter {
  WispFacePainter({
    required this.mood,
    required this.blinkProgress,
    required this.gaze,
    required this.pulse,
  });

  final WispMood mood;

  /// 0 = eyes open, 1 = fully blinked.
  final double blinkProgress;

  /// Smoothed look direction, each axis in -1..1.
  final Offset gaze;

  /// The companion's float phase (0..1) — only used for the tiny mouth pulse.
  final double pulse;

  static const _creamCore = Color(0xFFFFFBF2);
  static const _warmGlow = Color(0xFFF3E8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.44 + gaze.dx * (size.width * 0.045);
    final cy = size.height * 0.50 + gaze.dy * (size.height * 0.045);

    Paint glow({double? width}) => Paint()
      ..color = _warmGlow.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width ?? size.width * 0.055
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.03);

    Paint core({double? width}) => Paint()
      ..color = _creamCore
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width ?? size.width * 0.028;

    final eyeOffsetX = size.width * 0.088;
    final eyeY = cy - size.height * 0.015;
    final eyeW = size.width * 0.052;
    final blinkScale = (1.0 - blinkProgress).clamp(0.05, 1.0);

    void drawEye(double x, {required bool isLeft}) {
      if (mood == WispMood.sleeping || blinkProgress > 0.85) {
        final path = Path()
          ..moveTo(x - eyeW * 0.85, eyeY)
          ..quadraticBezierTo(x, eyeY + eyeW * 0.18, x + eyeW * 0.85, eyeY);
        canvas.drawPath(path, glow());
        canvas.drawPath(path, core());
        return;
      }
      if (mood == WispMood.curious) {
        final r = eyeW * 0.52 * blinkScale;
        canvas.drawCircle(
          Offset(x, eyeY),
          r,
          glow()..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, eyeY),
          r * 0.72,
          core()..style = PaintingStyle.fill,
        );
        return;
      }
      final path = Path();
      if (mood == WispMood.empathetic) {
        final tiltY = isLeft ? -eyeW * 0.22 : eyeW * 0.22;
        path
          ..moveTo(x - eyeW, eyeY - tiltY)
          ..quadraticBezierTo(
            x,
            eyeY - eyeW * 0.65 * blinkScale,
            x + eyeW,
            eyeY + tiltY,
          );
      } else if (mood == WispMood.thinking) {
        final arch = isLeft ? 0.45 : 0.85;
        path
          ..moveTo(x - eyeW, eyeY + eyeW * 0.1)
          ..quadraticBezierTo(
            x,
            eyeY - eyeW * arch * blinkScale,
            x + eyeW,
            eyeY + eyeW * 0.1,
          );
      } else {
        // greeting: the signature `^ ^` crescents.
        path
          ..moveTo(x - eyeW, eyeY + eyeW * 0.18)
          ..quadraticBezierTo(
            x,
            eyeY - eyeW * 0.72 * blinkScale,
            x + eyeW,
            eyeY + eyeW * 0.18,
          );
      }
      canvas.drawPath(path, glow());
      canvas.drawPath(path, core());
    }

    drawEye(cx - eyeOffsetX, isLeft: true);
    drawEye(cx + eyeOffsetX, isLeft: false);

    final mouthY = cy + size.height * 0.048;
    final mouthW = size.width * 0.026;

    if (mood == WispMood.curious || mood == WispMood.thinking) {
      final r = mouthW * (0.55 + pulse * 0.12);
      canvas.drawCircle(Offset(cx, mouthY + r * 0.3), r, core());
      return;
    }

    final mouth = Path();
    if (mood == WispMood.empathetic) {
      mouth
        ..moveTo(cx - mouthW * 0.8, mouthY + mouthW * 0.2)
        ..quadraticBezierTo(
          cx,
          mouthY - mouthW * 0.15,
          cx + mouthW * 0.8,
          mouthY + mouthW * 0.2,
        );
    } else {
      mouth
        ..moveTo(cx - mouthW, mouthY)
        ..quadraticBezierTo(cx, mouthY + mouthW * 0.85, cx + mouthW, mouthY);
    }
    canvas.drawPath(mouth, glow(width: size.width * 0.035));
    canvas.drawPath(mouth, core(width: size.width * 0.02));
  }

  @override
  bool shouldRepaint(WispFacePainter old) =>
      old.mood != mood ||
      old.blinkProgress != blinkProgress ||
      old.gaze != gaze ||
      old.pulse != pulse;
}
