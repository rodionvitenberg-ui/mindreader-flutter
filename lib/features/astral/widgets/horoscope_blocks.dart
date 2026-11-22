import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/l10n/app_strings.dart';

/// The 0..100 Energy & Resonance bar shared by both Horoscope modes.
class EnergyResonanceBar extends StatelessWidget {
  const EnergyResonanceBar({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? TaroColors.cyan
        : score >= 40
        ? TaroColors.lavender
        : TaroColors.conflictRose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppStrings.g('ui.astral_horoscope_blocks.energy_resonance'),
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                color: TaroColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$score%',
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: TaroColors.background,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score.clamp(0, 100) / 100,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// One focus sphere (relationships, career, inner state).
class FocusSphereCard extends StatelessWidget {
  const FocusSphereCard({required this.sphere, super.key});

  final FocusSphere sphere;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('focus-sphere-${sphere.title}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sphere.title.toUpperCase(),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: TaroColors.lavender,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sphere.text,
            style: AppTypography.body(
              fontSize: 12,
              height: 1.4,
              color: TaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selects a local calendar day and leaves the report below it readable.
class SevenDayForecastCard extends StatelessWidget {
  const SevenDayForecastCard({
    required this.days,
    required this.selectedDay,
    required this.onSelect,
    super.key,
  });

  final List<DateTime> days;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const weekdayKeys = [
      'astral.weekday.mon',
      'astral.weekday.tue',
      'astral.weekday.wed',
      'astral.weekday.thu',
      'astral.weekday.fri',
      'astral.weekday.sat',
      'astral.weekday.sun',
    ];
    final weekdays = [for (final key in weekdayKeys) AppStrings.g(key)];
    return SizedBox(
      key: const ValueKey('seven-day-forecast'),
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView.builder(
          scrollDirection: Axis.horizontal,
          itemExtent: math.max(constraints.maxWidth / days.length, 44),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final weekday = weekdays[day.weekday - 1];
            final selected = i == selectedDay;
            final color = selected ? TaroColors.lavender : TaroColors.textSecondary;
            return Semantics(
              selected: selected,
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: InkWell(
                  key: ValueKey('astral-day-$i'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(i),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? TaroColors.lavender.withValues(alpha: 0.16)
                          : TaroColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? TaroColors.lavender : TaroColors.border,
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekday,
                              style: AppTypography.label(
                                color: color,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: AppTypography.label(
                                color: color,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
