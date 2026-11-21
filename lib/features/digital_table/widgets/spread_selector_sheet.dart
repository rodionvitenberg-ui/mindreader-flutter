import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_spread.dart';
import '../../../core/models/rune_cast.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/spread_controller.dart';

/// Compact spread switcher opened from the spread picker when needed (Phase G4:
/// migrated to [TaroGlassSheet] + Tarot Tree tokens) — all preset schemas
/// across Tarot, Lenormand and Runes are open without subscription.
class SpreadSelectorSheet extends StatelessWidget {
  const SpreadSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showTaroGlassSheet<void>(
      context: context,
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
    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.label(
              fontSize: 9.5,
              letterSpacing: 1.2,
              color: TaroColors.lavender,
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
    return Semantics(
      button: true,
      selected: active,
      label: '$label ($count cards)',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? TaroColors.lavender.withValues(alpha: 0.16)
                  : TaroColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(TaroRadii.button),
              border: Border.all(
                color: active
                    ? TaroColors.lavender
                    : TaroColors.mist.withValues(alpha: TaroOpacity.border),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '$count •',
                  style: AppTypography.label(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.lavender,
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
                          color: active
                              ? TaroColors.lavender
                              : TaroColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count CARDS · $focusLine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          fontSize: 9.5,
                          color: TaroColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: TaroColors.lavender,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
