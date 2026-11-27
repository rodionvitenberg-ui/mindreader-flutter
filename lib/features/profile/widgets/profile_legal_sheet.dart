import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

/// Matches `version: 0.1.0+1` in `pubspec.yaml`.
const String kProfileAppVersion = '0.1.0 (1)';

/// Legal documents accessible from the bottom footer of the Profile tab.
enum ProfileLegalDoc { terms, privacy }

/// Scrollable glass bottom sheet displaying the full localized Terms of Use or
/// Privacy Policy document.
class ProfileLegalSheet extends StatelessWidget {
  const ProfileLegalSheet({super.key, required this.doc});

  final ProfileLegalDoc doc;

  static Future<void> show(BuildContext context, ProfileLegalDoc doc) {
    HapticFeedback.selectionClick();
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => ProfileLegalSheet(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsController?>()?.language ?? AppStrings.current;
    final prefix = doc == ProfileLegalDoc.terms
        ? 'profile.legal.terms'
        : 'profile.legal.privacy';
    final titleKey = doc == ProfileLegalDoc.terms
        ? 'profile.legal.termsTitle'
        : 'profile.legal.privacyTitle';
    final bodyMaxHeight = (MediaQuery.sizeOf(context).height * 0.54).clamp(
      180.0,
      520.0,
    );

    return TaroGlassSheet(
      key: ValueKey('profile-legal-sheet-${doc.name}'),
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(lang, 'profile.legal.updated'),
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: TaroColors.lavender,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.t(lang, titleKey),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.t(lang, 'common.close'),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: TaroColors.textSecondary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bodyMaxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 1; i <= 5; i++) ...[
                    if (i > 1) const SizedBox(height: 14),
                    Text(
                      AppStrings.t(lang, '$prefix.s$i.title'),
                      style: AppTypography.label(
                        fontSize: 10,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.lavender,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppStrings.t(lang, '$prefix.s$i.body'),
                      style: AppTypography.body(
                        fontSize: 12.5,
                        height: 1.5,
                        color: TaroColors.textPrimary.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TaroGlassLayer(
            useBackdropGroup: false,
            child: TaroGlassButton(
              key: const ValueKey('profile-legal-done'),
              label: AppStrings.t(lang, 'common.done').toUpperCase(),
              variant: TaroGlassButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact legal footer rendered at the bottom of Tab 1 (PROFILE): clickable
/// Terms of Use & Privacy Policy links plus a subtle app version caption.
class ProfileLegalFooter extends StatelessWidget {
  const ProfileLegalFooter({super.key, required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('profile-legal-footer'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              _LegalLink(
                key: const ValueKey('profile-terms-link'),
                label: AppStrings.t(lang, 'profile.legal.termsTitle'),
                onTap: () => ProfileLegalSheet.show(
                  context,
                  ProfileLegalDoc.terms,
                ),
              ),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 12,
                  color: TaroColors.textSecondary.withValues(alpha: 0.65),
                ),
              ),
              _LegalLink(
                key: const ValueKey('profile-privacy-link'),
                label: AppStrings.t(lang, 'profile.legal.privacyTitle'),
                onTap: () => ProfileLegalSheet.show(
                  context,
                  ProfileLegalDoc.privacy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.t(lang, 'profile.legal.version', {
              'version': kProfileAppVersion,
            }),
            key: const ValueKey('profile-app-version'),
            textAlign: TextAlign.center,
            style: AppTypography.label(
              fontSize: 9.5,
              letterSpacing: 0.9,
              color: TaroColors.textSecondary.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      link: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(
            label,
            style: AppTypography.body(
              fontSize: 11.5,
              color: TaroColors.lavender.withValues(alpha: 0.92),
            ).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: TaroColors.lavender.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
