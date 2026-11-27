import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// Empty-state placeholder for the natal wheel slot before a profile exists.
/// Renders the natal chart blueprint artwork (`assets/icons/natmap.png`) tinted
/// to match the Dark Obsidian Sanctuary palette.
class AstralWheelPlaceholder extends StatelessWidget {
  const AstralWheelPlaceholder({required this.chart, super.key});

  final NatalChart? chart;

  static const String wheelAssetPath = 'assets/icons/natmap.png';

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('natal-wheel-placeholder'),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 216,
                  maxHeight: 216,
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    wheelAssetPath,
                    fit: BoxFit.contain,
                    color: TaroColors.lavender.withValues(alpha: 0.86),
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
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
