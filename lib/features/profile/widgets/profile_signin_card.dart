import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_build_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/backend_auth_controller.dart';
import '../../shell/widgets/pro_subscription_sheet.dart';
import '../../shop/widgets/email_auth_sheet.dart';
import 'profile_card.dart';

/// Unified Email Sign-In and PRO subscription card on Tab 1 (PROFILE).
class ProfileSignInCard extends StatelessWidget {
  const ProfileSignInCard({super.key});

  static String _fmtUsd(int minor) => '\$${(minor / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final auth = context.watch<BackendAuthController?>();
    final lang = settings.language;
    final pro = settings.isProUnlocked;
    final signedInEmail = auth != null && auth.isVerified ? auth.email : null;
    final showPrices = showPricingCards;
    final isWeb = isWebCheckoutMode;
    final offer = isWeb ? auth?.proOffer : null;
    final hasEarly = isWeb && (offer?.hasEarlySlots ?? true);
    final monthlyPrice = _fmtUsd(
      hasEarly
          ? (offer?.earlyMonthlyMinor ?? 499)
          : (offer?.standardMonthlyMinor ?? 499),
    );
    final monthlyOldPrice = hasEarly
        ? _fmtUsd(offer?.standardMonthlyMinor ?? 699)
        : null;
    final annualPrice = _fmtUsd(
      hasEarly
          ? (offer?.annualMinor ?? 3999)
          : (offer?.standardAnnualMinor ?? 3999),
    );
    final annualOldPrice = hasEarly
        ? _fmtUsd(offer?.standardAnnualMinor ?? 5999)
        : null;

    return ProfileCard(
      section: SettingsSection.subscription,
      title: AppStrings.t(
        lang,
        showPrices ? 'profile.card.signIn' : 'pro.reader.title',
      ).toUpperCase(),
      trailing: ProfilePill(
        label: pro
            ? AppStrings.t(lang, 'ui.profile_signin_card.pro_active')
            : AppStrings.t(lang, 'ui.profile_signin_card.free_tier'),
        active: pro,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t(
              lang,
              showPrices ? 'profile.signIn.disclaimer' : 'pro.reader.body',
            ),
            key: showPrices
                ? null
                : const ValueKey('profile-reader-account-sync'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: TaroColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          if (signedInEmail != null && signedInEmail.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: TaroPalette.of(context).background.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: TaroColors.lavender.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    auth!.isEmailConfirmed
                        ? Icons.verified_outlined
                        : Icons.account_circle_outlined,
                    size: 18,
                    color: auth.isEmailConfirmed
                        ? TaroColors.emerald
                        : TaroColors.lavender,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedInEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (auth != null) ...[
            TaroGlassButton(
              key: const ValueKey('profile-signin-email'),
              icon: Icons.mail_outline_rounded,
              label: AppStrings.t(lang, 'profile.signIn.emailButton'),
              variant: TaroGlassButtonVariant.primary,
              onPressed: () => EmailAuthSheet.show(
                context,
                initialMode: AuthFormMode.login,
              ),
            ),
          ],
          if (showPrices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PlanCard(
                    title: AppStrings.t(
                      lang,
                      'ui.profile_signin_card.pro_monthly',
                    ),
                    price: monthlyPrice,
                    oldPrice: monthlyOldPrice,
                    badge: hasEarly
                        ? AppStrings.t(lang, 'pro.first100Badge')
                        : null,
                    onTap: () => ProSubscriptionSheet.show(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlanCard(
                    title: AppStrings.t(
                      lang,
                      'ui.profile_signin_card.pro_annual',
                    ),
                    price: annualPrice,
                    oldPrice: annualOldPrice,
                    badge: AppStrings.t(
                      lang,
                      'ui.profile_signin_card.best_value',
                    ),
                    onTap: () => ProSubscriptionSheet.show(
                      context,
                      initialAnnual: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!pro) ...[
            const SizedBox(height: 10),
            TaroGlassButton(
              key: const ValueKey('profile-check-pro-status'),
              icon: Icons.sync_rounded,
              label: AppStrings.t(
                lang,
                isWeb
                    ? 'pro.checkStatusCta'
                    : isStoreIapMode
                    ? 'pro.iap.restoreCta'
                    : 'pro.reader.refreshCta',
              ),
              variant: TaroGlassButtonVariant.secondary,
              onPressed: () => syncEntitlements(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.onTap,
    this.price,
    this.oldPrice,
    this.badge,
  });

  final String title;
  final String? price;
  final String? oldPrice;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = TaroPalette.of(context);
    return Semantics(
      button: true,
      label: badge == null ? title : '$title ($badge)',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.textPrimary,
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        price!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: TaroColors.lavender,
                        ),
                      ),
                      if (oldPrice != null)
                        Text(
                          oldPrice!,
                          style: TextStyle(
                            fontSize: 10,
                            color: TaroColors.textSecondary.withValues(alpha: 0.72),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ],
                if (badge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 1.0,
                        color: TaroColors.dawn,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
