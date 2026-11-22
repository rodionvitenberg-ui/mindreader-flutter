import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/backend_auth_controller.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/store_controller.dart';
import '../../shop/widgets/email_auth_sheet.dart';
import 'profile_card.dart';

/// Account Registration & Sign-In card on [ProfileScreen].
/// Links the reader's email account with the Django backend so purchases made
/// on the promo website and free gifts sync across browsers and devices.
class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final auth = context.watch<BackendAuthController>();
    final decks = context.watch<DeckPackController>();
    final store = context.watch<StoreController>();

    final verified = auth.isVerified;
    final installedCount = decks.installedRecords.length;

    return ProfileCard(
      section: SettingsSection.account,
      title: AppStrings.t(lang, 'profile.account.title').toUpperCase(),
      trailing: ProfilePill(
        label: verified
            ? AppStrings.t(lang, 'profile.account.verified')
            : AppStrings.t(lang, 'profile.account.guest'),
        active: verified,
      ),
      child: verified
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TaroColors.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TaroColors.lavender.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: TaroColors.emerald,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.email ?? '',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: TaroColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.t(
                                lang,
                                'profile.account.installedCount',
                                {'count': '$installedCount'},
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: TaroColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TaroGlassButton(
                        key: const ValueKey('profile-account-sync'),
                        icon: Icons.sync_outlined,
                        label: store.loading
                            ? AppStrings.t(lang, 'shop.state.processing')
                            : AppStrings.t(lang, 'profile.account.sync'),
                        variant: TaroGlassButtonVariant.secondary,
                        onPressed: store.loading
                            ? null
                            : () async {
                                await store.refresh();
                                if (context.mounted) {
                                  showTaroGlassSnackbar(
                                    context,
                                    message: AppStrings.t(
                                      lang,
                                      'profile.account.synced',
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    TaroGlassButton(
                      key: const ValueKey('profile-account-signout'),
                      icon: Icons.logout_outlined,
                      label: AppStrings.t(lang, 'shop.account.signOut'),
                      variant: TaroGlassButtonVariant.secondary,
                      onPressed: () async {
                        await auth.signOut();
                        await store.refresh();
                      },
                    ),
                  ],
                ),
              ],
            )
          : const EmailAuthForm(),
    );
  }
}
