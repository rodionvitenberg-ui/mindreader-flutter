import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import 'astral_gradient_button.dart';
import '../astral_copy.dart';

/// Live summary for the active profile: birth metadata, the Big Three and a
/// shortcut into the full natal profile sheet.
class AstralSummaryCard extends StatelessWidget {
  const AstralSummaryCard({
    required this.chart,
    required this.onOpenProfile,
    super.key,
  });

  final NatalChart chart;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final sun = chart.planets.firstWhere((p) => p.planet == PlanetId.sun);
    final moon = chart.planets.firstWhere((p) => p.planet == PlanetId.moon);
    final asc = chart.planets
        .where((p) => p.planet == PlanetId.ascendant)
        .firstOrNull;
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
            '${chart.timeKnown ? chart.houseSystem.label : context.astralText('unknownTime')}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BigThreeChip(label: 'SUN', pos: sun),
              const SizedBox(width: 8),
              if (!chart.moonSignUncertain)
                _BigThreeChip(label: 'MOON', pos: moon),
              if (asc != null) ...[
                const SizedBox(width: 8),
                _BigThreeChip(label: 'RISING', pos: asc),
              ],
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    context.astralText('details'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 1.6,
                      color: AppColors.lavender,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.lavender,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigThreeChip extends StatelessWidget {
  const _BigThreeChip({required this.label, required this.pos});

  final String label;
  final NatalPlanetPosition pos;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.astralRussian
                ? context.astroPlanet(pos.planet).toUpperCase()
                : label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${pos.sign.glyph} ${context.astroSign(pos.sign)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
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
            context.astralRussian
                ? 'НАТАЛЬНОЙ КАРТЫ ПОКА НЕТ'
                : 'NO NATAL PROFILE YET',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.8,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.astralRussian
                ? 'Укажите дату, время и город рождения.'
                : 'Enter your birth date, time and city.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          AstralGradientButton(label: '✦ ADD FIRST PROFILE', onTap: onGenerate),
        ],
      ),
    );
  }
}
