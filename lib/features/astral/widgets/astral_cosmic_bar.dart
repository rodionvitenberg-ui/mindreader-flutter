import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Top strip of the ASTRAL screen: today's moon phase and the reading
/// streak. The daily-ritual settings now live in the bottom dock.
class AstralCosmicBar extends StatelessWidget {
  const AstralCosmicBar({
    required this.phase,
    required this.streak,
    super.key,
  });

  final MoonPhase phase;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(phase.glyph, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase.name.toUpperCase(),
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 1.0,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(phase.illumination * 100).round()}% ILLUMINATED',
                style: AppTypography.label(
                  fontSize: 8.5,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (streak > 0) ...[
          _Pill(label: '🔥 ${streak}D', accent: AppColors.lavender),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          fontSize: 9,
          letterSpacing: 0.7,
          color: accent,
        ),
      ),
    );
  }
}
