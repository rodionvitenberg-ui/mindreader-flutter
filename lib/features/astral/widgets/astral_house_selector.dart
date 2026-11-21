import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../astral_copy.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Shared PLACIDUS / KOCH / WHOLE SIGN selector used by both the ASTRAL
/// screen and the birth-data form. A switch never re-generates a chart.
class AstralHouseSelector extends StatelessWidget {
  const AstralHouseSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final HouseSystem value;
  final ValueChanged<HouseSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final system in HouseSystem.values)
          _HousePill(
            label: context.astroHouseSystem(system),
            selected: value == system,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(system);
            },
          ),
      ],
    );
  }
}

class _HousePill extends StatelessWidget {
  const _HousePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.8,
            color: selected ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
