import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/app_settings_controller.dart';
import 'pro_subscription_sheet.dart';

/// Iteration 2 — the app settings sheet: an EN/RU language toggle and the
/// direct PRO subscription window. Persisted via [AppSettingsController].
class AppSettingsSheet extends StatelessWidget {
  const AppSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const AppSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.language;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xEB13131A),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                  AppStrings.t(lang, 'settings.title'),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  AppStrings.t(lang, 'settings.language'),
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 1.0,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final language in AppLanguage.values) ...[
                      if (language == AppLanguage.ru) const SizedBox(width: 10),
                      Expanded(
                        child: _LanguageTile(
                          language: language,
                          active: lang == language,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            settings.setLanguage(language);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  AppStrings.t(lang, 'settings.proHint'),
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 1.0,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _ProCard(
                  key: const ValueKey('settings-pro-card'),
                  unlocked: settings.isProUnlocked,
                  lang: lang,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ProSubscriptionSheet.show(context);
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

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.active,
    required this.onTap,
  });

  final AppLanguage language;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.t(
      AppLanguage.en,
      language == AppLanguage.en ? 'settings.english' : 'settings.russian',
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({
    super.key,
    required this.unlocked,
    required this.lang,
    required this.onTap,
  });

  final bool unlocked;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.lavender.withValues(alpha: 0.18),
              AppColors.indigo.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t(lang, 'pro.title'),
                    style: AppTypography.label(
                      fontSize: 15,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lavender,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.t(lang, unlocked ? 'pro.active' : 'pro.benefit1'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

