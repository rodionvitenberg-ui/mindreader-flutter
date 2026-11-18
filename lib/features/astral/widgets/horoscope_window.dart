import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/models/zodiac_forecast.dart';
import '../../../core/theme/app_colors.dart';
import 'astral_gradient_button.dart';
import 'daily_horoscope_card.dart';
import 'horoscope_blocks.dart';
import 'zodiac_forecast_card.dart';

/// ASTRAL window 1 — the Horoscope: the active profile's personal daily
/// transit report, or a quick whole-sign solar forecast picked at the top.
class HoroscopeWindow extends StatelessWidget {
  const HoroscopeWindow({
    required this.chart,
    required this.report,
    required this.selectedSign,
    required this.forecast,
    required this.onSelectSign,
    required this.onPersonal,
    required this.onDiscuss,
    super.key,
  });

  final NatalChart? chart;
  final DailyHoroscopeReport? report;

  /// Null = the personal (natal) horoscope; set = a quick zodiac sign.
  final ZodiacSign? selectedSign;
  final ZodiacSignForecast? forecast;
  final ValueChanged<ZodiacSign> onSelectSign;
  final VoidCallback onPersonal;
  final VoidCallback onDiscuss;

  bool get _personal => selectedSign == null && chart != null && report != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('horoscope-window'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SignSelector(
          chart: chart,
          selectedSign: selectedSign,
          onSelectSign: onSelectSign,
          onPersonal: onPersonal,
        ),
        const SizedBox(height: 12),
        if (_personal) ...[
          DailyHoroscopeCard(report: report!),
          const SizedBox(height: 12),
          EnergyResonanceBar(score: report!.energyScore),
          const SizedBox(height: 12),
          for (final f in report!.focusSpheres) ...[
            FocusSphereCard(sphere: f),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          AstralGradientButton(
            label: '✦ DISCUSS HOROSCOPE WITH ORACLE',
            onTap: onDiscuss,
          ),
        ] else if (forecast != null) ...[
          ZodiacForecastCard(forecast: forecast!),
          const SizedBox(height: 12),
          AstralGradientButton(
            label: '✦ DISCUSS HOROSCOPE WITH ORACLE',
            onTap: onDiscuss,
          ),
        ] else
          const _NoHoroscope(),
      ],
    );
  }
}

/// Horizontal chip row: MY CHART (when a profile exists) + the twelve signs.
class _SignSelector extends StatelessWidget {
  const _SignSelector({
    required this.chart,
    required this.selectedSign,
    required this.onSelectSign,
    required this.onPersonal,
  });

  final NatalChart? chart;
  final ZodiacSign? selectedSign;
  final ValueChanged<ZodiacSign> onSelectSign;
  final VoidCallback onPersonal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          if (chart != null)
            _SignChip(
              key: const ValueKey('zodiac-sign-personal'),
              glyph: '☉',
              label: 'MY CHART',
              active: selectedSign == null,
              onTap: () {
                HapticFeedback.selectionClick();
                onPersonal();
              },
            ),
          for (final s in ZodiacSign.values)
            _SignChip(
              key: ValueKey('zodiac-sign-${s.name}'),
              glyph: s.glyph,
              label: s.title.toUpperCase(),
              active: selectedSign == s,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectSign(s);
              },
            ),
        ],
      ),
    );
  }
}

class _SignChip extends StatelessWidget {
  const _SignChip({
    required this.glyph,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String glyph;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.lavender.withValues(alpha: 0.16)
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.lavender : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                glyph,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? AppColors.lavender : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.lavender : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoHoroscope extends StatelessWidget {
  const _NoHoroscope();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No horoscope yet — create a natal profile or pick a sign above.',
        style: GoogleFonts.inter(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
