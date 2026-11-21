import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/astral_controller.dart';

/// Shared PRO subscription modal (migrated to Tarot Tree glass in Phase G3).
/// Reusable from the Settings sheet, the History pane and the ASTRAL gate.
/// No billing backend is wired: activating unlocks the local PRO flag.
class ProSubscriptionSheet extends StatefulWidget {
  const ProSubscriptionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => const ProSubscriptionSheet(),
    );
  }

  @override
  State<ProSubscriptionSheet> createState() => _ProSubscriptionSheetState();
}

class _ProSubscriptionSheetState extends State<ProSubscriptionSheet> {
  bool _annual = true;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.language;
    final unlocked = settings.isProUnlocked;

    return TaroGlassSheet(
      title: AppStrings.t(lang, 'pro.title'),
      subtitle: AppStrings.t(lang, 'pro.subtitle'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final annual in const [false, true]) ...[
                if (annual) const SizedBox(width: 10),
                Expanded(
                  child: _PlanTile(
                    annual: annual,
                    selected: _annual == annual,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _annual = annual);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TaroGlassPanel(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 1; i <= 4; i++)
                  _Benefit(benefitKey: 'pro.benefit$i'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TaroGlassButton(
            label: AppStrings.t(lang, unlocked ? 'pro.active' : 'pro.activate'),
            variant: unlocked
                ? TaroGlassButtonVariant.secondary
                : TaroGlassButtonVariant.primary,
            onPressed: () {
              if (unlocked) {
                Navigator.of(context).pop();
                return;
              }
              HapticFeedback.mediumImpact();
              context.read<AppSettingsController>().unlockPro();
              // Keep the existing ASTRAL gate + its tests in sync.
              context.read<AstralController>().unlockPro();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.annual,
    required this.selected,
    required this.onTap,
  });

  final bool annual;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppSettingsController, AppLanguage>(
      (c) => c.language,
    );
    final label = AppStrings.t(lang, annual ? 'pro.annual' : 'pro.monthly');
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: TaroGlassPanel(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            tint: selected
                ? TaroColors.lavender.withValues(alpha: 0.22)
                : TaroColors.mist.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.label(
                    fontSize: 9.5,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? TaroColors.lavender
                        : TaroColors.textPrimary,
                  ),
                ),
                if (annual) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [TaroColors.lavender, TaroColors.indigo],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppStrings.t(lang, 'pro.bestValue'),
                      style: AppTypography.label(
                        fontSize: 7.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: TaroColors.background,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.benefitKey});

  final String benefitKey;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppSettingsController, AppLanguage>(
      (c) => c.language,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '✦',
              style: TextStyle(fontSize: 12, color: TaroColors.lavender),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.t(lang, benefitKey),
              style: AppTypography.body(
                fontSize: 12.5,
                height: 1.35,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
