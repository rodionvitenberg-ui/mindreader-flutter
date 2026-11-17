import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';

/// ASTRAL Phase 4 — today's cosmic weather for the active profile: the
/// moon house, the day theme and the live transit cards tagged by register.
class DailyHoroscopeCard extends StatelessWidget {
  const DailyHoroscopeCard({required this.report, super.key});

  final DailyHoroscopeReport report;

  @override
  Widget build(BuildContext context) {
    final d = report.date.toLocal();
    final stamp = '${_two(d.day)}.${_two(d.month)}.${d.year}';
    return Container(
      key: const ValueKey('daily-horoscope-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.moonPhaseGlyph, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COSMIC WEATHER · $stamp',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 1.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.moonPhaseName.toUpperCase(),
                      style: GoogleFonts.cinzel(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              _EnergyBadge(score: report.energyScore),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  report.transitingMoonSign.glyph,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.lavender,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MOON IN HOUSE ${report.transitingMoonHouse} · '
                    '${report.transitingMoonSign.title.toUpperCase()}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: AppColors.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.overallTheme,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          if (report.transits.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'LIVE TRANSITS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.8,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            for (final transit in report.transits.take(4))
              _TransitTile(transit: transit),
          ],
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// The day energy score, tinted by register (cyan / lavender / rose).
class _EnergyBadge extends StatelessWidget {
  const _EnergyBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? AppColors.harmonyCyan
        : score >= 40
            ? AppColors.lavender
            : AppColors.conflictRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            'ENERGY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 7,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One live transit: the canonical pair label, its register and the orb,
/// plus the grounded psychological advice for the day.
class _TransitTile extends StatelessWidget {
  const _TransitTile({required this.transit});

  final DailyTransitItem transit;

  @override
  Widget build(BuildContext context) {
    final color = _harmonyColor(transit.harmony);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        key: ValueKey('transit-${transit.transitLabel}'),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transit.transitLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  transit.harmony.name.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${transit.orb.toStringAsFixed(1)}°',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              transit.advice,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _harmonyColor(AspectHarmony harmony) => switch (harmony) {
        AspectHarmony.harmonious => AppColors.harmonyCyan,
        AspectHarmony.tense => AppColors.conflictRose,
        AspectHarmony.intense => AppColors.lavender,
      };
}
