import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_spread.dart';
import '../../../core/models/rune_cast.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/spread_controller.dart';

/// Compact spread switcher opened from the spread picker when needed — all
/// preset schemas across Tarot, Lenormand and Runes are open without
/// subscription (no locks, no paywall).
class SpreadSelectorSheet extends StatelessWidget {
  const SpreadSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const SpreadSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final title = switch (ctrl.system) {
      DivinationSystem.tarot => 'SPREAD METHOD',
      DivinationSystem.lenormand => 'LENORMAND SPREAD',
      DivinationSystem.runes => 'RUNE CAST',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.2,
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(height: 10),
            ...switch (ctrl.system) {
              DivinationSystem.tarot => [
                  for (var i = 0; i < SpreadType.values.length; i++) ...[
                    _SpreadOption(
                      count: SpreadType.values[i].cardCount,
                      label: SpreadType.values[i].label,
                      focusLine: SpreadType.values[i].focusLine,
                      active: !ctrl.isCustomSpread &&
                          SpreadType.values[i] == ctrl.spreadType,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context
                            .read<SpreadController>()
                            .setSpreadType(SpreadType.values[i]);
                        Navigator.of(context).pop();
                      },
                    ),
                    if (i < SpreadType.values.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              DivinationSystem.lenormand => [
                  for (var i = 0; i < LenormandSpread.values.length; i++) ...[
                    _SpreadOption(
                      count: LenormandSpread.values[i].cardCount,
                      label: LenormandSpread.values[i].label,
                      focusLine: LenormandSpread.values[i].focusLine,
                      active: !ctrl.isCustomSpread &&
                          LenormandSpread.values[i] == ctrl.lenormandSpread,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.read<SpreadController>().setLenormandSpread(
                              LenormandSpread.values[i],
                            );
                        Navigator.of(context).pop();
                      },
                    ),
                    if (i < LenormandSpread.values.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              DivinationSystem.runes => [
                  for (var i = 0; i < RuneCast.values.length; i++) ...[
                    _SpreadOption(
                      count: RuneCast.values[i].cardCount,
                      label: RuneCast.values[i].label,
                      focusLine: RuneCast.values[i].focusLine,
                      active: !ctrl.isCustomSpread &&
                          RuneCast.values[i] == ctrl.runeCast,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context
                            .read<SpreadController>()
                            .setRuneCast(RuneCast.values[i]);
                        Navigator.of(context).pop();
                      },
                    ),
                    if (i < RuneCast.values.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
            },
          ],
        ),
      ),
    );
  }
}

class _SpreadOption extends StatelessWidget {
  const _SpreadOption({
    required this.count,
    required this.label,
    required this.focusLine,
    required this.active,
    required this.onTap,
  });

  final int count;
  final String label;
  final String focusLine;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              '$count •',
              style: AppTypography.label(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.lavender : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count CARDS · $focusLine',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.lavender,
              ),
          ],
        ),
      ),
    );
  }
}
