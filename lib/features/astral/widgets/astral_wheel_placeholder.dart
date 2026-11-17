import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';

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
          gradient: const RadialGradient(
            colors: [Color(0x1FA78BFA), Color(0x0009090D)],
            radius: 0.9,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Center(
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 26, color: AppColors.lavender),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NATAL WHEEL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PHASE 3 · ANIMATED PAINTER',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.4,
                color: AppColors.textMuted,
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  letterSpacing: 1.4,
                  color: AppColors.textMuted,
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
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          position == null
              ? '—'
              : '${position.sign.glyph} ${position.formattedDegree}',
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
