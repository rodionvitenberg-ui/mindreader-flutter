import 'package:flutter/material.dart' hide Element;
import 'package:google_fonts/google_fonts.dart';

import '../astral_copy.dart';
import '../../../core/data/zodiac_almanac_data.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/models/zodiac_forecast.dart';
import '../../../core/theme/app_colors.dart';
import 'horoscope_blocks.dart';

/// The quick-sign Horoscope card: a whole-sign solar forecast with no natal
/// chart required.
class ZodiacForecastCard extends StatelessWidget {
  const ZodiacForecastCard({required this.forecast, super.key});

  final ZodiacSignForecast forecast;

  @override
  Widget build(BuildContext context) {
    final entry = zodiacEntryFor(forecast.sign);
    final element = entry.element;
    return Container(
      key: const ValueKey('zodiac-forecast-card'),
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
              Text(
                entry.glyph,
                style: TextStyle(fontSize: 30, color: element.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.astroSign(forecast.sign).toUpperCase(),
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.dateRange,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
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
                  forecast.moonPhaseGlyph,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.astroPhase(forecast.moonPhaseName, forecast.moonPhaseGlyph).toUpperCase()} · '
                    '${(forecast.moonIllumination * 100).round()}% · '
                    '${context.astroPlanet(PlanetId.moon).toUpperCase()} · ${context.astroSign(forecast.transitingMoonSign).toUpperCase()} '
                    '(${context.astralRussian ? 'СОЛНЕЧНЫЙ ДОМ' : 'SOLAR HOUSE'} ${forecast.solarMoonHouse})',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      letterSpacing: 1.0,
                      color: AppColors.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.astralRussian
                ? forecast.overallThemeRu ?? forecast.overallTheme
                : forecast.overallTheme,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          EnergyResonanceBar(score: forecast.energyScore),
          const SizedBox(height: 12),
          for (final f in forecast.focusSpheres) ...[
            FocusSphereCard(sphere: f),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
