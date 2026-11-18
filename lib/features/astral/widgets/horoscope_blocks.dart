import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';

/// The 0..100 Energy & Resonance bar shared by both Horoscope modes.
class EnergyResonanceBar extends StatelessWidget {
  const EnergyResonanceBar({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? AppColors.harmonyCyan
        : score >= 40
            ? AppColors.lavender
            : AppColors.conflictRose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ENERGY & RESONANCE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              '$score%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: AppColors.canvas,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score.clamp(0, 100) / 100,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// One focus sphere (relationships, career, inner state).
class FocusSphereCard extends StatelessWidget {
  const FocusSphereCard({required this.sphere, super.key});

  final FocusSphere sphere;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('focus-sphere-${sphere.title}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sphere.title.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sphere.text,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
