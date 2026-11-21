import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import 'pro_subscription_sheet.dart';

/// App settings modal sheet (migrated to Tarot Tree glass in Phase G3):
/// EN/RU language toggle via [TaroGlassSegmentedControl] and the PRO card
/// via [TaroGlassPanel]. Persisted via [AppSettingsController].
class AppSettingsSheet extends StatelessWidget {
  const AppSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => const AppSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.language;

    return TaroGlassSheet(
      title: AppStrings.t(lang, 'settings.title'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t(lang, 'settings.language'),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 1.0,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TaroGlassSegmentedControl<AppLanguage>(
            segments: [
              for (final language in AppLanguage.values)
                TaroGlassSegment<AppLanguage>(
                  value: language,
                  label: AppStrings.t(
                    AppLanguage.en,
                    language == AppLanguage.en
                        ? 'settings.english'
                        : 'settings.russian',
                  ),
                ),
            ],
            value: lang,
            onChanged: settings.setLanguage,
          ),
          const SizedBox(height: 22),
          Text(
            AppStrings.t(lang, 'settings.proHint'),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 1.0,
              color: TaroColors.textSecondary,
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
    final title = AppStrings.t(lang, 'pro.title');
    final subtitle = AppStrings.t(
      lang,
      unlocked ? 'pro.active' : 'pro.benefit1',
    );
    return Semantics(
      button: true,
      label: '$title — $subtitle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: TaroGlassPanel(
            radius: 18,
            padding: const EdgeInsets.all(16),
            tint: TaroColors.lavender.withValues(alpha: 0.16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.label(
                          fontSize: 15,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w800,
                          color: TaroColors.lavender,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          fontSize: 11.5,
                          height: 1.35,
                          color: TaroColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
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
