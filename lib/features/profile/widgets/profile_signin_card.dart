import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/user_profile_controller.dart';
import '../../shell/widgets/pro_subscription_sheet.dart';
import 'profile_card.dart';

/// Card 2 — optional 1-Click sign-in and the PRO subscription. No account is
/// required to read: sign-in only protects the PRO purchase across
/// reinstalls and unlocks device migration.
class ProfileSignInCard extends StatelessWidget {
  const ProfileSignInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileController>();
    final pro = context.watch<AppSettingsController>().isProUnlocked;
    return ProfileCard(
      title: '1-CLICK SIGN-IN & PRO',
      trailing: ProfilePill(
        label: pro ? 'PRO ACTIVE' : 'FREE TIER',
        active: pro,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No account is required to use the app. 1-Click Sign-In is used '
            'solely to protect your PRO purchase across reinstalls and help '
            'you move data to a new phone.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.textMuted.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              profile.setGoogleLinked(!profile.isGoogleLinked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.lavender.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    profile.isGoogleLinked
                        ? Icons.verified_outlined
                        : Icons.login_outlined,
                    size: 16,
                    color: AppColors.lavender,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile.isGoogleLinked
                        ? 'LINKED · GOOGLE'
                        : 'CONTINUE WITH GOOGLE / APPLE (1-CLICK)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lavender,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  title: 'PRO MONTHLY',
                  onTap: () => ProSubscriptionSheet.show(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanCard(
                  title: 'PRO ANNUAL',
                  badge: 'BEST VALUE',
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.canvas.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: AppColors.conflictAmber,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
