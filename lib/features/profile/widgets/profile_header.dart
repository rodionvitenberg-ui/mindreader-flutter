import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/user_profile_controller.dart';
import '../profile_screen.dart';

/// Places the profile action at the same right inset on every page.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.onProfileTap,
  });

  static const double edgeInset = 12;
  static const double actionSize = 48;

  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: edgeInset),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox.square(dimension: actionSize, child: leading),
            const SizedBox(width: 4),
          ],
          Expanded(child: child),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
          const SizedBox(width: 4),
          _ProfileAvatarButton(onTap: onProfileTap),
        ],
      ),
    );
  }
}

class ProfileHeaderTitle extends StatelessWidget {
  const ProfileHeaderTitle(this.labelKey, {super.key});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final language = context.select(
      (AppSettingsController settings) => settings.language,
    );
    return Text(
      AppStrings.t(language, labelKey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.display(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: TaroColors.textPrimary,
      ),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (UserProfileController? profile) => profile?.displayName.trim() ?? '',
    );
    final settings = context.watch<AppSettingsController>();
    final initial = name.isEmpty
        ? '✦'
        : String.fromCharCode(name.runes.first).toUpperCase();
    return IconButton(
      key: const ValueKey('profile-avatar-button'),
      tooltip: AppStrings.t(settings.language, 'header.profile'),
      constraints: const BoxConstraints.tightFor(
        width: ProfileHeader.actionSize,
        height: ProfileHeader.actionSize,
      ),
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        if (onTap != null) {
          onTap!();
        } else if (ModalRoute.isCurrentOf(context) != false) {
          Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
      icon: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TaroColors.surface.withValues(alpha: 0.86),
          border: Border.all(
            color: settings.isProUnlocked
                ? TaroColors.lavender
                : TaroColors.mist.withValues(alpha: TaroOpacity.borderStrong),
            width: settings.isProUnlocked ? 1.6 : 1,
          ),
          boxShadow: settings.isProUnlocked
              ? TaroGlow.soft(TaroColors.lavender, alpha: 0.25, blur: 12)
              : null,
        ),
        child: ExcludeSemantics(
          child: Text(
            initial,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: AppTypography.display(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: TaroColors.lavender,
            ),
          ),
        ),
      ),
    );
  }
}
