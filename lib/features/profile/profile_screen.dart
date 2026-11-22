import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_identity_card.dart';
import 'widgets/profile_migration_card.dart';
import 'widgets/profile_signin_card.dart';

/// The full-page profile (Phase G5: migrated to Tarot Tree with
/// [TaroDuskBackground], [TaroGlassLayer], [TaroGlassPanel] cards and
/// [TaroGlassSegmentedControl] for language).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.language;
    return Stack(
      children: [
        const Positioned.fill(child: TaroDuskBackground()),
        TaroGlassLayer(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  ProfileHeader(
                    leading: const BackButton(color: TaroColors.lavender),
                    onProfileTap: () {
                      final scroll = PrimaryScrollController.maybeOf(context);
                      if (scroll != null && scroll.hasClients) {
                        scroll.animateTo(
                          0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: const ProfileHeaderTitle('profile.title'),
                  ),
                  Expanded(
                    child: ListView(
                      primary: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        const ProfileIdentityCard(),
                        ProfileCard(
                          section: SettingsSection.readingExperience,
                          title: AppStrings.t(
                            lang,
                            'reading.title',
                          ).toUpperCase(),
                          child: Column(
                            children: [
                              for (final aid in ReadingAid.values)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: TaroGlassToggle(
                                    key: ValueKey(aid),
                                    label: AppStrings.t(
                                      lang,
                                      'reading.${aid.name}',
                                    ),
                                    subtitle: AppStrings.t(
                                      lang,
                                      'reading.${aid.name}.hint',
                                    ),
                                    value: settings.enabled(aid),
                                    onChanged: (value) =>
                                        settings.setAid(aid, value),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const ProfileSignInCard(),
                        const ProfileMigrationCard(),
                        ProfileCard(
                          section: SettingsSection.language,
                          title: AppStrings.t(lang, 'settings.language'),
                          child: _LanguageSelector(lang: lang),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettingsController>();
    return TaroGlassSegmentedControl<AppLanguage>(
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
    );
  }
}
