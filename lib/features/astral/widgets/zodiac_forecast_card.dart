import 'package:flutter/material.dart' hide Element;

import '../astral_copy.dart';
import '../../../core/data/zodiac_almanac_data.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/models/zodiac_forecast.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/element_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'horoscope_blocks.dart';
import '../../../core/l10n/app_strings.dart';

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
        color: TaroColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaroColors.border),
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
                      style: AppTypography.display(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.dateRange,
                      style: AppTypography.label(
                        fontSize: 8.5,
                        letterSpacing: 0.7,
                        color: TaroColors.textSecondary,
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
              color: TaroColors.background,
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
                    '(${AppStrings.g('ui.astral_zodiac_forecast_card.solar_house')} ${forecast.solarMoonHouse})',
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 1.0,
                      color: TaroColors.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            forecast.overallTheme,
            style: AppTypography.body(
              fontSize: 12,
              height: 1.45,
              color: TaroColors.textPrimary,
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
