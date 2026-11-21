import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';

/// "Sent to Cosmos" — the submitted thought/chip rises from the input
/// capsule and dissolves into luminous stardust drifting toward the deck
/// and cards. Pure overlay: `IgnorePointer`, `RepaintBoundary` — never
/// blocks gestures, never triggers full-screen rebuilds.
class CosmosSendBurst extends StatelessWidget {
  const CosmosSendBurst({
    super.key,
    required this.animation,
    required this.label,
  });

  final Animation<double> animation;

  /// The thought being sent (rendered as a rising pill that dissolves).
  final String label;

  static const double height = 150;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(animation.value);
            final pillOpacity = ((1 - t) * 2.4).clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(double.infinity, height),
                    painter: _StardustPainter(progress: t),
                  ),
                ),
                if (pillOpacity > 0.02)
                  Opacity(
                    opacity: pillOpacity,
                    child: Transform.translate(
                      offset: Offset(0, -104 * t),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TaroColors.lavender.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                TaroColors.lavender.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            fontSize: 11,
                            color: TaroColors.lavender,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Deterministic stardust: 26 particles rising and dissolving with the
/// eased progress. Seeded — no jitter between frames at 120 FPS.
class _StardustPainter extends CustomPainter {
  const _StardustPainter({required this.progress});

  final double progress;

  static const _count = 26;
  static const _seed = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(_seed);
    final centerX = size.width / 2;
    final baseY = size.height - 14;
    final fade =
        progress < 0.72 ? 1.0 : 1 - (progress - 0.72) / 0.28;
    const palette = [
      TaroColors.lavender,
      TaroColors.indigo,
      TaroColors.cyan,
      TaroColors.textPrimary,
    ];
    for (var i = 0; i < _count; i++) {
      final t = progress;
      final spread = (rng.nextDouble() - 0.5) * 200;
      final rise = 44 + rng.nextDouble() * 100;
      final drift = (rng.nextDouble() - 0.5) * 28 * t;
      final x = centerX + spread * (0.55 + 0.45 * t) + drift;
      final y = baseY - rise * t - 6 * (1 - t);
      if (y < -4) continue;
      final alpha = (fade * (1 - t * 0.85)).clamp(0.0, 1.0);
      final r = 1.0 + rng.nextDouble() * 1.8;
      final color = palette[i % palette.length];
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = color.withValues(alpha: alpha),
      );
      if (i % 5 == 0) {
        canvas.drawCircle(
          Offset(x, y),
          r * 3.4,
          Paint()
            ..color = TaroColors.lavender.withValues(alpha: alpha * 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StardustPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
