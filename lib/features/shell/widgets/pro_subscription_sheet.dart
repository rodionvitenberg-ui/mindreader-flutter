import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/astral_controller.dart';

/// Iteration 2 — the shared PRO subscription modal (obsidian-lavender).
/// Reusable from the Settings sheet, the History pane and the ASTRAL gate.
/// No billing backend is wired: activating unlocks the local PRO flag.
class ProSubscriptionSheet extends StatefulWidget {
  const ProSubscriptionSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
                  AppStrings.t(lang, 'pro.title'),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t(lang, 'pro.subtitle'),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.lavender,
                  ),
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
                for (var i = 1; i <= 4; i++)
                  _Benefit(benefitKey: 'pro.benefit$i'),
                const SizedBox(height: 8),
                _ActivateButton(
                  label:
                      AppStrings.t(lang, unlocked ? 'pro.active' : 'pro.activate'),
                  unlocked: unlocked,
                  onTap: () {
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
          ),
        ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lavender.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(lang, annual ? 'pro.annual' : 'pro.monthly'),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.lavender : AppColors.textPrimary,
              ),
            ),
            if (annual) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.lavender, AppColors.indigo],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.t(lang, 'pro.bestValue'),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.canvas,
                  ),
                ),
              ),
            ],
          ],
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
              style: TextStyle(fontSize: 12, color: AppColors.lavender),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.t(lang, benefitKey),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivateButton extends StatelessWidget {
  const _ActivateButton({
    required this.label,
    required this.unlocked,
    required this.onTap,
  });

  final String label;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: unlocked
              ? null
              : const LinearGradient(
                  colors: [AppColors.lavender, AppColors.indigo],
                ),
          color: unlocked ? AppColors.surface.withValues(alpha: 0.7) : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: unlocked ? AppColors.textMuted : AppColors.canvas,
          ),
        ),
      ),
    );
  }
}

