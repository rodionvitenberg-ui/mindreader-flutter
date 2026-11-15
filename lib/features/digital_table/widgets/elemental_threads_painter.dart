import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';

/// Animated glowing bezier threads connecting adjacent face-up cards in the
/// pillar: cyan/emerald pulses for elemental harmony, rose/amber for
/// conflict, indigo glow for neutral.
class ElementalThreadsPainter extends CustomPainter {
  ElementalThreadsPainter({
    required this.threads,
    required this.pulse,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
  });

  final List<ThreadInfo> threads;
  final Animation<double> pulse;
  final double cardWidth;
  final double cardHeight;
  final double gap;

  Offset _centerOf(int slotIndex) =>
      Offset(cardWidth / 2, slotIndex * (cardHeight + gap) + cardHeight / 2);

  Color _toneColor(ThreadTone tone, int i) => switch (tone) {
        ThreadTone.harmony =>
          i.isEven ? AppColors.harmonyCyan : AppColors.harmonyEmerald,
        ThreadTone.conflict =>
          i.isEven ? AppColors.conflictRose : AppColors.conflictAmber,
        ThreadTone.neutral => AppColors.indigo,
      };

  static Offset _cubicPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return Offset(
      u * u * u * p0.dx + 3 * u * u * t * p1.dx + 3 * u * t * t * p2.dx + t * t * t * p3.dx,
      u * u * u * p0.dy + 3 * u * u * t * p1.dy + 3 * u * t * t * p2.dy + t * t * t * p3.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = pulse.value;
    for (var i = 0; i < threads.length; i++) {
      final th = threads[i];
      final start = _centerOf(th.from);
      final end = _centerOf(th.to);
      final midY = (start.dy + end.dy) / 2;
      final sway = 46 + 16 * math.sin(t * 2 * math.pi + i * 1.7);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + sway, midY, end.dx + sway, midY, end.dx, end.dy);
      final color = _toneColor(th.tone, i);
      final phase = math.sin(t * 2 * math.pi + i * 1.3);

      // Pulsing glow underlay.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.26 + 0.16 * phase)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Crisp core thread.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = color.withValues(alpha: 0.85),
      );
      // Traveling energy particle.
      final dot = _cubicPoint(start, Offset(start.dx + sway, midY),
          Offset(end.dx + sway, midY), end, (t + i * 0.23) % 1.0);
      canvas.drawCircle(
        dot,
        3,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ElementalThreadsPainter oldDelegate) =>
      oldDelegate.threads != threads;
}
