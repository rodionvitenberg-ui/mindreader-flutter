import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design_system/taro.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/user_profile_controller.dart';
import '../../shell/widgets/pro_subscription_sheet.dart';
import 'profile_card.dart';

/// Card 2 — optional 1-Click sign-in and the PRO subscription (Phase G5:
/// [ProfileCard] + [TaroGlassButton]).
class ProfileSignInCard extends StatelessWidget {
  const ProfileSignInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileController>();
    final settings = context.watch<AppSettingsController>();
    final pro = settings.isProUnlocked;
    return ProfileCard(
      section: SettingsSection.subscription,
      title: AppStrings.t(settings.language, 'profile.card.signIn'),
      trailing: ProfilePill(
        label: pro ? AppStrings.g('ui.profile_signin_card.pro_active') : AppStrings.g('ui.profile_signin_card.free_tier'),
        active: pro,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.g('profile.signIn.disclaimer'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: TaroColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          TaroGlassButton(
            icon: profile.isGoogleLinked
                ? Icons.verified_outlined
                : Icons.login_outlined,
            label: profile.isGoogleLinked
                ? AppStrings.g('ui.profile_signin_card.linked_google') : AppStrings.g('ui.profile_signin_card.continue_with_google_apple_1_click'),
            variant: TaroGlassButtonVariant.primary,
            onPressed: () => profile.setGoogleLinked(!profile.isGoogleLinked),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  title: AppStrings.g('ui.profile_signin_card.pro_monthly'),
                  onTap: () => ProSubscriptionSheet.show(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanCard(
                  title: AppStrings.g('ui.profile_signin_card.pro_annual'),
                  badge: AppStrings.g('pro.bestValue'),
                  onTap: () => ProSubscriptionSheet.show(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.onTap, this.badge});

  final String title;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badge == null ? title : '$title ($badge)',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TaroColors.background.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.textPrimary,
                  ),
                ),
                if (badge != null)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(AppStrings.g('ui.profile_signin_card.best_value'),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
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
