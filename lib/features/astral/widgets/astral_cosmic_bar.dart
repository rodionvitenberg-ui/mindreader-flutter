import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';

/// Top strip of the ASTRAL screen: today's moon phase, the reading streak
/// and the entry point into the daily-ritual settings.
class AstralCosmicBar extends StatelessWidget {
  const AstralCosmicBar({
    required this.phase,
    required this.streak,
    required this.onRituals,
    super.key,
  });

  final MoonPhase phase;
  final int streak;
  final VoidCallback onRituals;

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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(phase.illumination * 100).round()}% ILLUMINATED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  letterSpacing: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (streak > 0) ...[
          _Pill(label: '🔥 ${streak}D', accent: AppColors.lavender),
          const SizedBox(width: 8),
        ],
        _Pill(label: '🔔 RITUALS', accent: AppColors.textMuted, onTap: onRituals),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.accent, this.onTap});

  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.2,
            color: accent,
          ),
        ),
      ),
    );
  }
}
