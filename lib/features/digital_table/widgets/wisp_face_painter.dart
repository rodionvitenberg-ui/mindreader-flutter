import 'package:flutter/material.dart';

import 'wisp_mood.dart';

/// Wisp's procedural animated face (G2.2/G2.3).
///
/// The luminous orb and cosmic veil come from the mirrored, tightly-cropped
/// `assets/images/wisp_body.png` sprite; every facial expression is painted
/// procedurally on top so mimicry stays razor-sharp from 36 px up to 120 px.
///
/// Eyes: `^ ^` greeting, bright `o o` with catchlight for curiosity, soft
/// tilted arcs for sympathy, uneven arches while thinking, calm closed lines
/// when sleeping.
class WispFacePainter extends CustomPainter {
  WispFacePainter({
    required this.mood,
    required this.blinkProgress,
    required this.gaze,
    required this.pulse,
    this.orbCenterX = defaultOrbCenterX,
    this.orbCenterY = defaultOrbCenterY,
  });

  /// Measured optical center of the warm orb core in `assets/images/wisp_body.png`.
  static const double defaultOrbCenterX = 0.575;
  static const double defaultOrbCenterY = 0.455;

  final WispMood mood;

  /// 0 = eyes open, 1 = fully blinked.
  final double blinkProgress;

  /// Smoothed look direction, each axis in -1..1.
  final Offset gaze;

  /// Wisp's float phase (0..1) — drives the subtle breathing mouth pulse.
  final double pulse;

  final double orbCenterX;
  final double orbCenterY;

  static const _creamCore = Color(0xFFFFFDF7);
  static const _warmGlow = Color(0xFFF3E8FF);
  static const _cheekTint = Color(0xFFF5C2E7);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * orbCenterX + gaze.dx * (size.width * 0.036);
    final cy = size.height * orbCenterY + gaze.dy * (size.height * 0.032);

    Paint glow({double? width}) => Paint()
      ..color = _warmGlow.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width ?? size.width * 0.052
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.026);

    Paint core({double? width}) => Paint()
      ..color = _creamCore
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width ?? size.width * 0.027;

    final eyeOffsetX = size.width * 0.088;
    final eyeY = cy - size.height * 0.014;
    final eyeW = size.width * 0.050;
    final blinkScale = (1.0 - blinkProgress).clamp(0.05, 1.0);

    // Subtle luminous blush under the eyes on warm moods (greeting / empathetic).
    if (mood == WispMood.greeting || mood == WispMood.empathetic) {
      final blushPaint = Paint()
        ..color = _cheekTint.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.032);
      final cheekY = eyeY + size.height * 0.056;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - eyeOffsetX * 1.15, cheekY),
          width: size.width * 0.075,
          height: size.height * 0.042,
        ),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + eyeOffsetX * 1.15, cheekY),
          width: size.width * 0.075,
          height: size.height * 0.042,
        ),
        blushPaint,
      );
    }

    void drawEye(double x, {required bool isLeft}) {
      if (mood == WispMood.sleeping || blinkProgress > 0.85) {
        final path = Path()
          ..moveTo(x - eyeW * 0.85, eyeY)
          ..quadraticBezierTo(x, eyeY + eyeW * 0.22, x + eyeW * 0.85, eyeY);
        canvas.drawPath(path, glow());
        canvas.drawPath(path, core());
        return;
      }
      if (mood == WispMood.curious) {
        final rx = eyeW * 0.50;
        final ry = eyeW * 0.58 * blinkScale;
        final rect = Rect.fromCenter(
          center: Offset(x, eyeY),
          width: rx * 2,
          height: ry * 2,
        );
        canvas.drawOval(rect.inflate(size.width * 0.01), glow()..style = PaintingStyle.fill);
        canvas.drawOval(rect, core()..style = PaintingStyle.fill);
        // Tiny warm-lavender catchlight glint inside open curious eyes.
        if (blinkScale > 0.45) {
          final glint = Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92);
          canvas.drawCircle(
            Offset(x + rx * 0.28, eyeY - ry * 0.28),
            rx * 0.28,
            glint,
          );
        }
        return;
      }
      final path = Path();
      if (mood == WispMood.empathetic) {
        final tiltY = isLeft ? -eyeW * 0.24 : eyeW * 0.24;
        path
          ..moveTo(x - eyeW, eyeY - tiltY)
          ..quadraticBezierTo(
            x,
            eyeY - eyeW * 0.62 * blinkScale,
            x + eyeW,
            eyeY + tiltY,
          );
      } else if (mood == WispMood.thinking) {
        final arch = isLeft ? 0.36 : 0.86;
        path
          ..moveTo(x - eyeW, eyeY + eyeW * 0.12)
          ..quadraticBezierTo(
            x,
            eyeY - eyeW * arch * blinkScale,
            x + eyeW,
            eyeY + eyeW * 0.12,
          );
      } else {
        // greeting: Wisp's signature warm `^ ^` crescents.
        path
          ..moveTo(x - eyeW, eyeY + eyeW * 0.20)
          ..quadraticBezierTo(
            x,
            eyeY - eyeW * 0.78 * blinkScale,
            x + eyeW,
            eyeY + eyeW * 0.20,
          );
      }
      canvas.drawPath(path, glow());
      canvas.drawPath(path, core());
    }

    drawEye(cx - eyeOffsetX, isLeft: true);
    drawEye(cx + eyeOffsetX, isLeft: false);

    final mouthY = cy + size.height * 0.054;
    final mouthW = size.width * 0.028;

    if (mood == WispMood.curious || mood == WispMood.thinking) {
      final r = mouthW * (0.50 + pulse * 0.11);
      final shiftX = mood == WispMood.thinking ? mouthW * 0.35 : 0.0;
      canvas.drawCircle(
        Offset(cx + shiftX, mouthY + r * 0.2),
        r * 1.25,
        glow(width: size.width * 0.030)..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(cx + shiftX, mouthY + r * 0.2),
        r,
        core(width: size.width * 0.020),
      );
      return;
    }

    final mouth = Path();
    if (mood == WispMood.empathetic) {
      mouth
        ..moveTo(cx - mouthW * 0.85, mouthY + mouthW * 0.18)
        ..quadraticBezierTo(
          cx,
          mouthY - mouthW * 0.16,
          cx + mouthW * 0.85,
          mouthY + mouthW * 0.18,
        );
    } else if (mood == WispMood.sleeping) {
      mouth
        ..moveTo(cx - mouthW * 0.65, mouthY)
        ..quadraticBezierTo(
          cx,
          mouthY + mouthW * 0.45,
          cx + mouthW * 0.65,
          mouthY,
        );
    } else {
      mouth
        ..moveTo(cx - mouthW * 1.05, mouthY - mouthW * 0.05)
        ..quadraticBezierTo(
          cx,
          mouthY + mouthW * 0.92,
          cx + mouthW * 1.05,
          mouthY - mouthW * 0.05,
        );
    }
    canvas.drawPath(mouth, glow(width: size.width * 0.036));
    canvas.drawPath(mouth, core(width: size.width * 0.022));
  }

  @override
  bool shouldRepaint(WispFacePainter old) =>
      old.mood != mood ||
      old.blinkProgress != blinkProgress ||
      old.gaze != gaze ||
      old.pulse != pulse ||
      old.orbCenterX != orbCenterX ||
      old.orbCenterY != orbCenterY;
}
