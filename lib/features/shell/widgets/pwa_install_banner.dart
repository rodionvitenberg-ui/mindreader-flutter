import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/pwa_install_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

const String kPwaInstallDismissedKey = 'pwa_install_dismissed_v1';

/// Gentle, non-intrusive PWA Add-to-Home-Screen card shown on Web ONLY after
/// the reader has completed at least one reading or daily card.
class PwaInstallBanner extends StatelessWidget {
  const PwaInstallBanner({
    super.key,
    required this.mode,
    required this.onInstall,
    required this.onDismiss,
  });

  final PwaInstallMode mode;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  static Future<bool> isDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kPwaInstallDismissedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPwaInstallDismissedKey, true);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final isIos = mode == PwaInstallMode.iosManualHint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TaroGlassPanel(
        key: const ValueKey('pwa-install-banner'),
        radius: 20,
        tint: TaroColors.lavender.withValues(alpha: 0.16),
        borderColor: TaroColors.lavender.withValues(alpha: 0.45),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TaroColors.lavender.withValues(alpha: 0.2),
                    border: Border.all(
                      color: TaroColors.lavender.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    isIos ? Icons.ios_share_rounded : Icons.install_mobile_rounded,
                    size: 18,
                    color: TaroColors.lavender,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(lang, 'pwa.install.title'),
                        style: AppTypography.heading(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: TaroColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.t(
                          lang,
                          isIos ? 'pwa.install.iosBody' : 'pwa.install.body',
                        ),
                        style: AppTypography.body(
                          fontSize: 11.5,
                          height: 1.38,
                          color: TaroColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('pwa-install-close'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: TaroColors.textSecondary,
                  ),
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('pwa-install-later'),
                  onPressed: onDismiss,
                  child: Text(
                    AppStrings.t(lang, 'pwa.install.later'),
                    style: AppTypography.label(
                      fontSize: 11,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                ),
                if (!isIos) ...[
                  const SizedBox(width: 6),
                  TaroGlassButton(
                    key: const ValueKey('pwa-install-cta'),
                    icon: Icons.download_rounded,
                    label: AppStrings.t(lang, 'pwa.install.cta'),
                    onPressed: onInstall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
