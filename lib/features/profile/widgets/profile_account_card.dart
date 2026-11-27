import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/astral_controller.dart';
import '../../../state/backend_auth_controller.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/store_controller.dart';
import '../../shop/widgets/email_auth_sheet.dart';
import 'profile_card.dart';

/// Account & Cloud Library section on Tab 2 (DATA & LANGUAGE): email sign-in,
/// registration, one-time verification code, and store library sync.
class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final auth = context.watch<BackendAuthController>();
    final decks = context.watch<DeckPackController>();
    final store = context.watch<StoreController>();

    final signedIn = auth.isVerified;
    final emailConfirmed = auth.isEmailConfirmed;
    final installedCount = decks.installedRecords.length;
    final accountName = auth.displayName?.trim();

    return ProfileCard(
      section: SettingsSection.account,
      title: AppStrings.t(lang, 'profile.account.title').toUpperCase(),
      trailing: ProfilePill(
        label: signedIn
            ? AppStrings.t(lang, 'profile.account.verified')
            : AppStrings.t(lang, 'profile.account.guest'),
        active: signedIn,
      ),
      child: signedIn
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TaroPalette.of(context).background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TaroColors.lavender.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        emailConfirmed
                            ? Icons.verified_outlined
                            : Icons.account_circle_outlined,
                        color: emailConfirmed
                            ? TaroColors.emerald
                            : TaroColors.lavender,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (accountName != null && accountName.isNotEmpty)
                              Text(
                                accountName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: TaroColors.textPrimary,
                                ),
                              ),
                            Text(
                              auth.email ?? '',
                              style: TextStyle(
                                fontSize: accountName != null &&
                                        accountName.isNotEmpty
                                    ? 12
                                    : 13.5,
                                fontWeight: accountName != null &&
                                        accountName.isNotEmpty
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: accountName != null &&
                                        accountName.isNotEmpty
                                    ? TaroColors.textSecondary
                                    : TaroColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              emailConfirmed
                                  ? '${AppStrings.t(lang, 'auth.emailConfirmedBadge')} · ${AppStrings.t(lang, 'profile.account.installedCount', {'count': '$installedCount'})}'
                                  : AppStrings.t(
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
                if (!emailConfirmed && (auth.email?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('profile-verify-email'),
                      icon: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 16,
                        color: TaroColors.lavender,
                      ),
                      label: Text(
                        AppStrings.t(lang, 'auth.verifyEmailOptional'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: TaroColors.lavender,
                        ),
                      ),
                      onPressed: () => EmailConfirmSheet.show(
                        context,
                        email: auth.email!,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
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
                    Expanded(
                      child: TaroGlassButton(
                        key: const ValueKey('profile-account-signout'),
                        icon: Icons.logout_outlined,
                        label: AppStrings.t(lang, 'shop.account.signOut'),
                        variant: TaroGlassButtonVariant.secondary,
                        onPressed: () async {
                          final settings = context.read<AppSettingsController>();
                          final astral = context.read<AstralController?>();
                          await auth.signOut();
                          settings.setProUnlocked(false);
                          astral?.setProUnlocked(false);
                          await store.refresh();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('profile-account-delete'),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: TaroColors.error,
                    ),
                    label: Text(
                      AppStrings.t(lang, 'profile.account.delete'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: TaroColors.error,
                      ),
                    ),
                    onPressed: auth.isBusy
                        ? null
                        : () => _confirmDeleteAccount(context, lang),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.t(lang, 'shop.auth.hint'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: TaroColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TaroGlassButton(
                        key: const ValueKey('profile-account-login'),
                        icon: Icons.login_outlined,
                        label: AppStrings.t(lang, 'auth.login'),
                        variant: TaroGlassButtonVariant.secondary,
                        onPressed: () => EmailAuthSheet.show(
                          context,
                          initialMode: AuthFormMode.login,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TaroGlassButton(
                        key: const ValueKey('profile-account-register'),
                        icon: Icons.person_add_outlined,
                        label: AppStrings.t(lang, 'auth.register'),
                        variant: TaroGlassButtonVariant.primary,
                        onPressed: () => EmailAuthSheet.show(
                          context,
                          initialMode: AuthFormMode.register,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppLanguage lang,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: TaroPalette.of(dialogCtx).surface,
        title: Text(
          AppStrings.t(lang, 'profile.account.deleteTitle'),
          style: const TextStyle(color: TaroColors.textPrimary),
        ),
        content: Text(
          AppStrings.t(lang, 'profile.account.deleteBody'),
          style: const TextStyle(color: TaroColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(AppStrings.t(lang, 'common.close')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              AppStrings.t(lang, 'profile.account.deleteConfirm'),
              style: const TextStyle(color: TaroColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final auth = context.read<BackendAuthController>();
    final settings = context.read<AppSettingsController>();
    final astral = context.read<AstralController?>();
    final store = context.read<StoreController>();
    try {
      await auth.deleteAccount();
      settings.setProUnlocked(false);
      astral?.setProUnlocked(false);
      await store.refresh();
      if (context.mounted) {
        showTaroGlassSnackbar(
          context,
          message: AppStrings.t(lang, 'profile.account.deleted'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showTaroGlassSnackbar(
          context,
          message: e.toString(),
          tone: TaroGlassSnackbarTone.error,
        );
      }
    }
  }
}
