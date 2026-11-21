import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/astral_controller.dart';
import 'astral_gradient_button.dart';

/// ASTRAL PRO gate — shown when a free-tier user attempts a 3rd natal
/// profile. Explains the 2-profile free tier and what PRO unlocks.
class AstralProPaywallSheet extends StatelessWidget {
  const AstralProPaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const AstralProPaywallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xEB13131A),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ASTRAL PRO',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'FREE TIER · 2 SAVED NATAL PROFILES',
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 1.0,
                    color: AppColors.lavender,
                  ),
                ),
                const SizedBox(height: 18),
                const _ProFeature('Unlimited natal profiles'),
                const _ProFeature('Synastry comparison between any two charts'),
                const _ProFeature('Chart regeneration · full house control'),
                const SizedBox(height: 22),
                AstralGradientButton(
                  label: 'UNLOCK PRO',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.read<AstralController>().unlockPro();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  const _ProFeature(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '✦',
              style: TextStyle(fontSize: 13, color: AppColors.lavender),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
