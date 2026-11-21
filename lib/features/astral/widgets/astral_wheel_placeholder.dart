import 'package:flutter/material.dart';

import '../astral_copy.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// Phase 3 slot — the animated CustomPainter natal wheel will live here.
/// For now it renders the ring silhouette and, once a profile exists, the
/// three luminaries (Sun · Moon · Ascendant) plus birth metadata.
class AstralWheelPlaceholder extends StatelessWidget {
  const AstralWheelPlaceholder({required this.chart, super.key});

  final NatalChart? chart;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('natal-wheel-placeholder'),
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              TaroColors.lavender.withValues(alpha: 0.14),
              TaroColors.background.withValues(alpha: 0.0),
            ],
            radius: 0.9,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TaroColors.mist.withValues(
                    alpha: TaroOpacity.borderStrong,
                  ),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 26, color: TaroColors.lavender),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.astralText('natalWheel'),
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 1.0,
                color: TaroColors.textPrimary,
              ),
            ),
            if (chart != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Body(chart: chart!, planet: PlanetId.sun),
                  _Body(chart: chart!, planet: PlanetId.moon),
                  _Body(chart: chart!, planet: PlanetId.ascendant),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${chart!.cityName} · ${chart!.houseSystem.label}',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  color: TaroColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.chart, required this.planet});

  final NatalChart chart;
  final PlanetId planet;

  @override
  Widget build(BuildContext context) {
    NatalPlanetPosition? position;
    for (final p in chart.planets) {
      if (p.planet == planet) position = p;
    }
    return Column(
      children: [
        Text(
          '${planet.glyph} ${planet.title}',
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.7,
            color: TaroColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          position == null
              ? '—'
              : '${position.sign.glyph} ${position.formattedDegree}',
          style: const TextStyle(fontSize: 14, color: TaroColors.textPrimary),
        ),
      ],
    );
  }
}
