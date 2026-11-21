import 'package:flutter/material.dart';

import '../astral_copy.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Horizontal profile switcher: saved natal charts as selectable pills plus
/// the new-chart control (locked behind ASTRAL PRO once the free tier is
/// used up).
class AstralProfileBar extends StatelessWidget {
  const AstralProfileBar({
    required this.profiles,
    required this.activeIndex,
    required this.canCreate,
    required this.onSelect,
    required this.onAdd,
    super.key,
  });

  final List<NatalChart> profiles;
  final int activeIndex;
  final bool canCreate;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < profiles.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ProfilePill(
                glyph: _glyphAt(i),
                label: profiles[i].profileName,
                selected: i == activeIndex,
                onTap: () => onSelect(i),
              ),
            ),
          _AddPill(locked: !canCreate, onTap: onAdd),
        ],
      ),
    );
  }

  String _glyphAt(int index) => switch (index) {
    0 => '👤',
    1 => '☽',
    _ => '✦',
  };
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          '$glyph $label',
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.lavender : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({required this.locked, required this.onTap});

  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = locked ? AppColors.indigo : AppColors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '+ ${context.astralRussian ? 'НОВАЯ КАРТА' : 'NEW CHART'}${locked ? ' · PRO' : ''}',
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.8,
            color: accent,
          ),
        ),
      ),
    );
  }
}
