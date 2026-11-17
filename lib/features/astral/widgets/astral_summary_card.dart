import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import 'astral_gradient_button.dart';

/// Live summary for the active profile: birth metadata plus today's
/// horoscope (moon phase, transiting house and the tightest transits).
class AstralSummaryCard extends StatelessWidget {
  const AstralSummaryCard({
    required this.chart,
    required this.report,
    super.key,
  });

  final NatalChart chart;
  final DailyHoroscopeReport? report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final day = chart.birthLocalDay.toString().padLeft(2, '0');
    final month = chart.birthLocalMonth.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chart.profileName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$day.$month.${chart.birthLocalYear} · ${chart.cityName} · '
            '${chart.houseSystem.label}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(r.moonPhaseGlyph, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MOON IN HOUSE ${r.transitingMoonHouse} · '
                    '${r.transitingMoonSign.title.toUpperCase()}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: AppColors.lavender,
                    ),
                  ),
                ),
                Text(
                  '${r.energyScore}/100',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.overallTheme,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            for (final transit in r.transits.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✦ ',
                        style: TextStyle(color: AppColors.lavender)),
                    Expanded(
                      child: Text(
                        '${transit.title} — ${transit.advice}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shown before the first profile exists.
class AstralEmptyState extends StatelessWidget {
  const AstralEmptyState({required this.onGenerate, super.key});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NO NATAL PROFILE YET',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.8,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your birth date, time and city to compute your chart. '
            'Everything stays on this device.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          AstralGradientButton(
            label: '✦ ADD FIRST PROFILE',
            onTap: onGenerate,
          ),
        ],
      ),
    );
  }
}
