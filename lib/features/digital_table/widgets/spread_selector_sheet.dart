import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_spread.dart';
import '../../../core/models/rune_cast.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import '../../shell/widgets/pro_subscription_sheet.dart';

/// Compact spread switcher opened from the header's spread picker pill
/// (`3 · TRIAD FLOW ▾`) — the options are ALWAYS the active system's
/// canonical spreads: 4 tarot templates, 4 Lenormand spreads or 4 rune
/// casts. Replaces the old bottom carousel.
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
    final proUnlocked = context.watch<AppSettingsController>().isProUnlocked;
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
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 2.2,
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
                    isPro: SpreadType.values[i].isPro,
                    locked: SpreadType.values[i].isPro && !proUnlocked,
                    active: SpreadType.values[i] == ctrl.spreadType,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (SpreadType.values[i].isPro && !proUnlocked) {
                        ProSubscriptionSheet.show(context);
                        return;
                      }
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
                    isPro: LenormandSpread.values[i].isPro,
                    locked: LenormandSpread.values[i].isPro && !proUnlocked,
                    active: LenormandSpread.values[i] == ctrl.lenormandSpread,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (LenormandSpread.values[i].isPro && !proUnlocked) {
                        ProSubscriptionSheet.show(context);
                        return;
                      }
                      context.read<SpreadController>().setLenormandSpread(
                          LenormandSpread.values[i]);
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
                    isPro: RuneCast.values[i].isPro,
                    locked: RuneCast.values[i].isPro && !proUnlocked,
                    active: RuneCast.values[i] == ctrl.runeCast,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (RuneCast.values[i].isPro && !proUnlocked) {
                        ProSubscriptionSheet.show(context);
                        return;
                      }
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
    required this.isPro,
    required this.locked,
    required this.active,
    required this.onTap,
  });

  final int count;
  final String label;
  final String focusLine;
  final bool isPro;
  final bool locked;
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
              style: GoogleFonts.jetBrainsMono(
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.lavender
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(width: 6),
                        Text(
                          locked ? '🔒 PRO' : 'PRO',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: locked
                                ? AppColors.textMuted
                                : AppColors.lavender,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count CARDS · $focusLine',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
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

