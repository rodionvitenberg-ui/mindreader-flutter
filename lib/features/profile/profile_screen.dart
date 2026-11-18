import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_settings_controller.dart';
import '../digital_table/widgets/ritual_settings_sheet.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_identity_card.dart';
import 'widgets/profile_migration_card.dart';
import 'widgets/profile_signin_card.dart';

/// Tab 4 — the full-page profile: personal context, optional 1-Click
/// sign-in, device migration, daily rituals and the language selector.
/// Rituals and Settings moved here from the bottom dock.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'profile.title'),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const ProfilePill(
                  label: 'ZERO-KNOWLEDGE',
                  active: true,
                  icon: Icons.shield_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ProfileIdentityCard(),
            const ProfileSignInCard(),
            const ProfileMigrationCard(),
            ProfileCard(
              title: AppStrings.t(lang, 'profile.card.rituals'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LanguageSelector(lang: lang),
                  const SizedBox(height: 16),
                  const RitualSettingsSheet(inline: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettingsController>();
    return Row(
      children: [
        Expanded(
          child: ProfilePill(
            label: AppStrings.t(lang, 'settings.english'),
            active: lang == AppLanguage.en,
            onTap: () => settings.setLanguage(AppLanguage.en),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ProfilePill(
            label: AppStrings.t(lang, 'settings.russian'),
            active: lang == AppLanguage.ru,
            onTap: () => settings.setLanguage(AppLanguage.ru),
          ),
        ),
      ],
    );
  }
}
