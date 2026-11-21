import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/astral_controller.dart';
import 'astral_gradient_button.dart';

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
      title: 'ASTRAL PRO',
      subtitle: 'FREE TIER · 2 SAVED NATAL PROFILES',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaroGlassPanel(
            radius: 18,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProFeature('Unlimited natal profiles'),
                _ProFeature('Synastry comparison between any two charts'),
                _ProFeature('Chart regeneration · full house control'),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
