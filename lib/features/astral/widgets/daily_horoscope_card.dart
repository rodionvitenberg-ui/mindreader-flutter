import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../astral_copy.dart';
import '../../../core/l10n/app_strings.dart';

/// ASTRAL Phase 4 — today's cosmic weather for the active profile: the
/// moon house, the day theme and the live transit cards tagged by register.
class DailyHoroscopeCard extends StatelessWidget {
  const DailyHoroscopeCard({
    required this.report,
    this.onDiscussTransit,
    super.key,
  });

  final ValueChanged<DailyTransitItem>? onDiscussTransit;

  final DailyHoroscopeReport report;

  @override
  Widget build(BuildContext context) {
    final d = report.date.toLocal();
    final stamp = '${_two(d.day)}.${_two(d.month)}.${d.year}';
    return Container(
      key: const ValueKey('daily-horoscope-card'),
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
              Text(report.moonPhaseGlyph, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stamp,
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 1.0,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context
                          .astroPhase(
                            report.moonPhaseName,
                            report.moonPhaseGlyph,
                          )
                          .toUpperCase(),
                      style: AppTypography.display(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              _EnergyBadge(score: report.energyScore),
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
                  report.transitingMoonSign.glyph,
                  style: const TextStyle(
                    fontSize: 14,
                    color: TaroColors.lavender,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.astroPlanet(PlanetId.moon).toUpperCase()}'
                    '${report.transitingMoonHouse == null ? '' : ' ${AppStrings.g('ui.astral_daily_horoscope_card.in_house')} ${report.transitingMoonHouse}'} · '
                    '${context.astroSign(report.transitingMoonSign).toUpperCase()}',
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 0.7,
                      color: TaroColors.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.overallTheme,
            style: AppTypography.body(
              fontSize: 13,
              height: 1.45,
              color: TaroColors.textPrimary,
            ),
          ),
          if (report.transits.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              AppStrings.g('ui.astral_daily_horoscope_card.live_transits'),
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.0,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (final transit in report.transits)
              _TransitTile(
                transit: transit,
                onDiscuss: onDiscussTransit == null
                    ? null
                    : () => onDiscussTransit!(transit),
              ),
          ],
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// The day energy score, tinted by register (cyan / lavender / rose).
class _EnergyBadge extends StatelessWidget {
  const _EnergyBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? TaroColors.cyan
        : score >= 40
        ? TaroColors.lavender
        : TaroColors.conflictRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: AppTypography.display(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            AppStrings.g('ui.astral_daily_horoscope_card.energy'),
            style: AppTypography.label(
              fontSize: 7.5,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One live transit: the canonical pair label, its register and the orb,
/// plus the grounded psychological advice for the day.
class _TransitTile extends StatelessWidget {
  const _TransitTile({required this.transit, this.onDiscuss});

  final VoidCallback? onDiscuss;

  final DailyTransitItem transit;

  @override
  Widget build(BuildContext context) {
    final color = _harmonyColor(transit.harmony);
    final material = MaterialLocalizations.of(context);
    String dateTime(DateTime value) {
      final local = value.toLocal();
      final russian = context.astralRussian;
      final date = russian
          ? '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}'
          : material.formatCompactDate(local);
      return '$date ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: russian)}';
    }

    final transitBody = transit.transitingBody;
    final natalBody = transit.natalBody;
    final label =
        transitBody == null || natalBody == null || transit.aspectType == null
        ? transit.transitLabel
        : '${context.astroPlanet(transitBody)} ${transit.aspectType!.glyph} '
              '${context.astroPlanet(natalBody)} ${AppStrings.g('ui.astral_daily_horoscope_card.natal')}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        key: ValueKey('transit-${transit.transitLabel}'),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: TaroColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: TaroColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${transit.orb.toStringAsFixed(1)}°',
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 0.6,
                    color: TaroColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (transit.closestAt case final closest?) ...[
              const SizedBox(height: 6),
              Text(
                '${context.astralText(transit.reachesExact ? 'exact' : 'closest')} · ${dateTime(closest)}',
              ),
              const SizedBox(height: 4),
              Text(
                '${context.astralText('activePeriod')} · '
                '${transit.activeFrom == null ? '…' : dateTime(transit.activeFrom!)} → '
                '${transit.activeUntil == null ? '…' : dateTime(transit.activeUntil!)}',
              ),
            ],
            const SizedBox(height: 5),
            Text(
              transit.advice,
              style: AppTypography.body(
                fontSize: 11.5,
                height: 1.4,
                color: TaroColors.textSecondary,
              ),
            ),
            if (onDiscuss != null)
              TextButton(
                onPressed: onDiscuss,
                child: Text(context.astralText('discussTransit')),
              ),
          ],
        ),
      ),
    );
  }

  static Color _harmonyColor(AspectHarmony harmony) => switch (harmony) {
    AspectHarmony.harmonious => TaroColors.cyan,
    AspectHarmony.tense => TaroColors.conflictRose,
    AspectHarmony.intense => TaroColors.lavender,
  };
}
