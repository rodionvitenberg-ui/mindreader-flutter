import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/models/zodiac_forecast.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';
import 'astral_gradient_button.dart';
import 'daily_horoscope_card.dart';
import 'horoscope_blocks.dart';
import 'zodiac_forecast_card.dart';
import '../astral_copy.dart';
import '../../../core/l10n/app_strings.dart';

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
    required this.days,
    required this.showWeek,
    required this.selectedDay,
    required this.onToggleWeek,
    required this.onSelectDay,
    super.key,
  });

  final NatalChart? chart;
  final DailyHoroscopeReport? report;

  /// Null = the personal (natal) horoscope; set = a quick zodiac sign.
  final ZodiacSign? selectedSign;
  final ZodiacSignForecast? forecast;
  final ValueChanged<ZodiacSign> onSelectSign;
  final VoidCallback onPersonal;
  final ValueChanged<DailyTransitItem?> onDiscuss;

  final List<DateTime> days;
  final bool showWeek;
  final int selectedDay;
  final ValueChanged<bool> onToggleWeek;
  final ValueChanged<int> onSelectDay;

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
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.astralText('today')),
                selected: !showWeek,
                onSelected: (_) => onToggleWeek(false),
              ),
              ChoiceChip(
                key: const ValueKey('astral-show-week'),
                label: Text(context.astralText('week')),
                selected: showWeek,
                onSelected: (_) => onToggleWeek(true),
              ),
            ],
          ),
          if (showWeek)
            SevenDayForecastCard(
              days: days,
              selectedDay: selectedDay,
              onSelect: onSelectDay,
            ),
          const SizedBox(height: 12),
          DailyHoroscopeCard(report: report!, onDiscussTransit: onDiscuss),
          const SizedBox(height: 12),
          for (final f in report!.focusSpheres) ...[
            FocusSphereCard(sphere: f),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          AstralGradientButton(
            label: context.astralRussian
                ? context.astralText('discuss')
                : AppStrings.g('astral.discussHoroscope'),
            onTap: () => onDiscuss(null),
          ),
        ] else if (forecast != null) ...[
          ZodiacForecastCard(forecast: forecast!),
          const SizedBox(height: 12),
          AstralGradientButton(
            label: context.astralRussian
                ? context.astralText('discuss')
                : AppStrings.g('astral.discussHoroscope'),
            onTap: () => onDiscuss(null),
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
              label: context.astralText('myChart'),
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
              label: context.astroSign(s).toUpperCase(),
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
                ? TaroColors.lavender.withValues(alpha: 0.16)
                : TaroColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? TaroColors.lavender : TaroColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                glyph,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? TaroColors.lavender : TaroColors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: active ? TaroColors.lavender : TaroColors.textSecondary,
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
        color: TaroColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaroColors.border),
      ),
      child: Text(AppStrings.g('ui.horoscope_window.no_horoscope_yet_create_a_natal_profile_or_pick_'),
        style: AppTypography.body(
          fontSize: 12,
          height: 1.4,
          color: TaroColors.textSecondary,
        ),
      ),
    );
  }
}
