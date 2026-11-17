import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Subtle diagonal lavender/indigo specular sheen that slides ACROSS the
/// card as its 3D angle changes — the user feels the card's tilt and weight
/// during shuffle and flip. Pure GPU-friendly gradient overlay.
class FoilGlint extends StatelessWidget {
  const FoilGlint({
    super.key,
    required this.angleY,
    required this.angleX,
    this.intensity = 1.0,
  });

  final double angleY;
  final double angleX;

  /// 0..1 — dims the sheen (deck fan layers use a lower intensity).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    // The light catches the raised edge: the sheen drifts opposite to the
    // card's rotation.
    final u = math.sin(angleY) * 0.9;
    final v = math.sin(angleX) * 0.7;
    final k = intensity.clamp(0.0, 1.0);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(u - 0.7, v - 1.0),
            end: Alignment(u + 0.9, v + 0.8),
            colors: [
              Colors.transparent,
              AppColors.lavender.withValues(alpha: 0.10 * k),
              AppColors.indigo.withValues(alpha: 0.22 * k),
              AppColors.lavender.withValues(alpha: 0.06 * k),
              Colors.transparent,
            ],
            stops: const [0.0, 0.36, 0.50, 0.62, 1.0],
          ),
        ),
      ),
    );
  }
}
