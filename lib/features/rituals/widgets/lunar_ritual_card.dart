import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/custom_spread.dart';
import '../../../core/services/lunar_phase_service.dart';
import '../../../core/services/natal_calculator_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// Compact Moonly-style lunar ritual card: displays today's live Moon phase
/// from the offline Astral ephemeris and launches curated New Moon / Full Moon
/// spreads directly on the Digital Table.
class LunarRitualCard extends StatelessWidget {
  const LunarRitualCard({
    super.key,
    required this.language,
    this.onStartLunarSpread,
    this.nowUtc,
  });

  final AppLanguage language;
  final ValueChanged<CustomSpreadConfig>? onStartLunarSpread;
  final DateTime? nowUtc;

  @override
  Widget build(BuildContext context) {
    final ref = (nowUtc ?? DateTime.now()).toUtc();
    final moon = NatalCalculatorService.computeMoonPhase(ref);
    final window = LunarPhaseService.currentOrNextWindow(nowUtc: ref);
    final spread = LunarPhaseService.lunarSpreadFor(window.phase, language);
    final isNew = window.phase == LunarPhase.newMoon;
    final accent = window.isActiveNow
        ? (isNew ? TaroColors.lavender : TaroColors.dawn)
        : TaroColors.lavender;

    return TaroGlassPanel(
      key: const ValueKey('lunar-ritual-card'),
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(moon.glyph, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spread.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${moon.name}  ·  ${(moon.illumination * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        fontSize: 8.5,
                        letterSpacing: 0.7,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('lunar-ritual-window-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: window.isActiveNow ? 0.22 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: window.isActiveNow ? 0.75 : 0.35,
                    ),
                  ),
                ),
                child: Text(
                  window.isActiveNow
                      ? AppStrings.t(language, 'ritual.lunarRitual.activeNow')
                      : AppStrings.t(language, 'ritual.lunarRitual.inDays', {
                          'days': window.daysUntil,
                        }),
                  style: AppTypography.label(
                    fontSize: 8,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TaroGlassChip(
            key: const ValueKey('lunar-ritual-start-button'),
            label: AppStrings.t(language, 'ritual.lunarRitual.startCta'),
            selected: window.isActiveNow,
            compact: true,
            expanded: true,
            onTap: () {
              HapticFeedback.mediumImpact();
              onStartLunarSpread?.call(spread);
            },
          ),
        ],
      ),
    );
  }
}
