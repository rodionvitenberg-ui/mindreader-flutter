import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../astral_copy.dart';

/// The 0..100 Energy & Resonance bar shared by both Horoscope modes.
class EnergyResonanceBar extends StatelessWidget {
  const EnergyResonanceBar({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? AppColors.harmonyCyan
        : score >= 40
        ? AppColors.lavender
        : AppColors.conflictRose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.astralRussian ? 'ЭНЕРГИЯ ДНЯ' : 'ENERGY & RESONANCE',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
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
            color: AppColors.canvas,
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
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (context.astralRussian
                    ? sphere.titleRu ?? sphere.title
                    : sphere.title)
                .toUpperCase(),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.astralRussian ? sphere.textRu ?? sphere.text : sphere.text,
            style: AppTypography.body(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textMuted,
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
    final weekdays = context.astralRussian
        ? ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
            final color = selected ? AppColors.lavender : AppColors.textMuted;
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
                          ? AppColors.lavender.withValues(alpha: 0.16)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.lavender : AppColors.border,
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
