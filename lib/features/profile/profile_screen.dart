import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/guided_reading_controller.dart';
import '../../state/onboarding_controller.dart';
import '../shell/widgets/language_selector.dart';
import 'widgets/profile_account_card.dart';
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
                        const ProfileAccountCard(),
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
                              if (settings.enabled(ReadingAid.guide))
                                _GuideDetailControls(
                                  lang: lang,
                                  detail: settings.guideDetail,
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: const ValueKey('onboarding-replay'),
                                  icon: const Icon(Icons.replay, size: 16),
                                  label: Text(
                                    AppStrings.t(lang, 'onboarding.restart'),
                                  ),
                                  onPressed: () => context
                                      .read<OnboardingController>()
                                      .restart(),
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

/// The Guided Reading detail level + a way to forget every lesson the mentor
/// has already taught. Shown only while Guided Reading is on.
class _GuideDetailControls extends StatelessWidget {
  const _GuideDetailControls({required this.lang, required this.detail});

  final AppLanguage lang;
  final GuideDetail detail;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettingsController>();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(lang, 'reading.detail').toUpperCase(),
            style: AppTypography.label(
              color: TaroColors.textSecondary,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          TaroGlassSegmentedControl<GuideDetail>(
            key: const ValueKey('guide-detail'),
            segments: [
              for (final value in GuideDetail.values)
                TaroGlassSegment<GuideDetail>(
                  value: value,
                  label: AppStrings.t(lang, 'reading.detail.${value.name}'),
                ),
            ],
            value: detail,
            onChanged: settings.setGuideDetail,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('guide-reset-progress'),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(AppStrings.t(lang, 'reading.resetProgress')),
              onPressed: () =>
                  context.read<GuidedReadingController>().resetLearned(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return const LanguageSelector();
  }
}
