import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/astral_controller.dart';
import 'astral_gradient_button.dart';
import '../../../core/l10n/app_strings.dart';

/// ASTRAL PRO gate (Phase G5: migrated to [TaroGlassSheet] + [TaroGlassPanel]
/// + [TaroGlassButton]).
class AstralProPaywallSheet extends StatelessWidget {
  const AstralProPaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => const AstralProPaywallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TaroGlassSheet(
      title: AppStrings.g('ui.astral_pro_paywall_sheet.astral_pro'),
      subtitle: AppStrings.g('ui.astral_pro_paywall_sheet.free_tier_2_saved_natal_profiles'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaroGlassPanel(
            radius: 18,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProFeature(AppStrings.g('pro.feature.unlimitedProfiles')),
                _ProFeature(AppStrings.g('pro.feature.synastry')),
                _ProFeature(AppStrings.g('pro.feature.chartRegeneration')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AstralGradientButton(
            label: AppStrings.g('ui.astral_pro_paywall_sheet.unlock_pro'),
            onTap: () {
              HapticFeedback.mediumImpact();
              context.read<AstralController>().unlockPro();
              Navigator.of(context).pop();
            },
          ),
        ],
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
              style: TextStyle(fontSize: 13, color: TaroColors.lavender),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                fontSize: 13,
                height: 1.4,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
