import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/guided_reading_controller.dart';
import '../../state/onboarding_controller.dart';
import '../../state/user_profile_controller.dart';
import '../shell/widgets/language_selector.dart';
import 'widgets/profile_account_card.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_identity_card.dart';
import 'widgets/profile_legal_sheet.dart';
import 'widgets/profile_migration_card.dart';
import 'widgets/profile_signin_card.dart';

/// The two swipeable windows of [ProfileScreen].
enum ProfileTab { profile, dataAndLanguage }

/// Full-page Profile & Settings screen organized into two swipe-synchronized
/// tabs (`[ PROFILE | DATA & LANGUAGE ]`), mirroring [AstralScreen].
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileTab _tab = ProfileTab.profile;
  ProfileTab? _animatingToTab;

  late final PageController _pageController = PageController();
  final ScrollController _profileScroll = ScrollController();
  final ScrollController _dataScroll = ScrollController();

  @override
  void dispose() {
    _pageController.dispose();
    _profileScroll.dispose();
    _dataScroll.dispose();
    super.dispose();
  }

  void _selectTab(ProfileTab next) {
    if (_tab == next && _animatingToTab == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tab = next;
      _animatingToTab = next;
    });
    if (_pageController.hasClients) {
      _pageController
          .animateToPage(
            next.index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && _animatingToTab == next) {
              _animatingToTab = null;
            }
          });
    } else {
      _animatingToTab = null;
    }
  }

  void _scrollActiveTabToTop() {
    final controller =
        _tab == ProfileTab.profile ? _profileScroll : _dataScroll;
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileHeader(
                    leading: const BackButton(color: TaroColors.lavender),
                    onProfileTap: _scrollActiveTabToTop,
                    child: const ProfileHeaderTitle('profile.title'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: _ProfileTabSwitcher(
                      lang: lang,
                      tab: _tab,
                      onChanged: _selectTab,
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      key: const ValueKey('profile-page-view'),
                      controller: _pageController,
                      onPageChanged: (index) {
                        final next = ProfileTab.values[index];
                        if (_animatingToTab != null &&
                            next != _animatingToTab) {
                          return;
                        }
                        _animatingToTab = null;
                        if (_tab != next) {
                          setState(() => _tab = next);
                        }
                      },
                      children: [
                        RepaintBoundary(
                          child: _buildProfileTab(context, lang, settings),
                        ),
                        RepaintBoundary(
                          child: _buildDataAndLanguageTab(lang),
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

  Widget _buildProfileTab(
    BuildContext context,
    AppLanguage lang,
    AppSettingsController settings,
  ) {
    return ListView(
      key: const PageStorageKey<String>('profile-tab-main-scroll'),
      controller: _profileScroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
      children: [
        const ProfileIdentityCard(),
        const ProfileSignInCard(),
        ProfileCard(
          section: SettingsSection.readingExperience,
          title: AppStrings.t(lang, 'reading.title').toUpperCase(),
          child: Column(
            children: [
              _SanctuaryThemeRow(lang: lang),
              for (final aid in ReadingAid.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TaroGlassToggle(
                    key: ValueKey(aid),
                    label: AppStrings.t(lang, 'reading.${aid.name}'),
                    subtitle: AppStrings.t(lang, 'reading.${aid.name}.hint'),
                    value: settings.enabled(aid),
                    onChanged: (value) => settings.setAid(aid, value),
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
                  label: Text(AppStrings.t(lang, 'onboarding.restart')),
                  onPressed: () =>
                      context.read<OnboardingController>().restart(),
                ),
              ),
            ],
          ),
        ),
        ProfileLegalFooter(lang: lang),
      ],
    );
  }

  Widget _buildDataAndLanguageTab(AppLanguage lang) {
    return ListView(
      key: const PageStorageKey<String>('profile-tab-data-scroll'),
      controller: _dataScroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
      children: [
        ProfileCard(
          section: SettingsSection.language,
          title: AppStrings.t(lang, 'settings.language').toUpperCase(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t(lang, 'profile.language.hint'),
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: TaroColors.textSecondary.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 10),
              const LanguageSelector(),
            ],
          ),
        ),
        const ProfileAccountCard(),
        const ProfileMigrationCard(),
      ],
    );
  }
}

/// Compact `[ PROFILE | DATA & LANGUAGE ]` switcher synchronized with the
/// horizontal [PageView].
class _ProfileTabSwitcher extends StatelessWidget {
  const _ProfileTabSwitcher({
    required this.lang,
    required this.tab,
    required this.onChanged,
  });

  final AppLanguage lang;
  final ProfileTab tab;
  final ValueChanged<ProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaroGlassSegmentedControl<ProfileTab>(
      key: const ValueKey('profile-tab-switcher'),
      segments: [
        TaroGlassSegment<ProfileTab>(
          key: const ValueKey('profile-tab-profile'),
          value: ProfileTab.profile,
          label: AppStrings.t(lang, 'profile.tab.profile'),
        ),
        TaroGlassSegment<ProfileTab>(
          key: const ValueKey('profile-tab-data'),
          value: ProfileTab.dataAndLanguage,
          label: AppStrings.t(lang, 'profile.tab.dataAndLanguage'),
        ),
      ],
      value: tab,
      onChanged: onChanged,
    );
  }
}

/// Dual dark theme toggle row (`[ 🌘 TWILIGHT | 🏮 MOONLIT NIGHT ]`) inside
/// the `READING EXPERIENCE` section.
class _SanctuaryThemeRow extends StatelessWidget {
  const _SanctuaryThemeRow({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<UserProfileController, SanctuaryThemeMode>(
      (profile) => profile.themeMode,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(lang, 'reading.theme').toUpperCase(),
            style: AppTypography.label(
              color: TaroColors.textSecondary,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          TaroGlassSegmentedControl<SanctuaryThemeMode>(
            key: const ValueKey('sanctuary-theme-switcher'),
            segments: [
              TaroGlassSegment<SanctuaryThemeMode>(
                key: const ValueKey('theme-mode-twilight'),
                value: SanctuaryThemeMode.twilight,
                label: '🌘 ${AppStrings.t(lang, 'reading.theme.twilight')}',
              ),
              TaroGlassSegment<SanctuaryThemeMode>(
                key: const ValueKey('theme-mode-moonlit'),
                value: SanctuaryThemeMode.moonlit,
                label: '🏮 ${AppStrings.t(lang, 'reading.theme.moonlit')}',
              ),
            ],
            value: themeMode,
            onChanged: context.read<UserProfileController>().setThemeMode,
          ),
        ],
      ),
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
