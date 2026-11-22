import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../astral_copy.dart';

/// Live summary for the active profile (Phase G5: [TaroGlassPanel]).
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
    return TaroGlassLayer(
      child: TaroGlassPanel(
        radius: 18,
        padding: const EdgeInsets.all(18),
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
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.7,
              color: TaroColors.textSecondary,
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
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 0.9,
                      color: TaroColors.lavender,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: TaroColors.lavender,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 0.8,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${pos.sign.glyph} ${context.astroSign(pos.sign)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TaroColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown before the first profile exists (Phase G5: [TaroGlassEmptyState]).
class AstralEmptyState extends StatelessWidget {
  const AstralEmptyState({required this.onGenerate, super.key});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return TaroGlassLayer(
      child: TaroGlassEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: context.astralRussian
            ? 'НАТАЛЬНОЙ КАРТЫ ПОКА НЕТ'
            : 'NO NATAL PROFILE YET',
        subtitle: context.astralRussian
            ? 'Укажите дату, время и город рождения.'
            : 'Enter your birth date, time and city.',
        actionLabel: '✦ ADD FIRST PROFILE',
        framed: true,
        onAction: onGenerate,
      ),
    );
  }
}
