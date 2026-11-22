import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/onboarding_controller.dart';
import '../digital_table/widgets/wisp_mood.dart';
import 'widgets/onboarding_step_body.dart';

/// G3 — the one-time "guided reading" intro.
///
/// A full-screen glass overlay over the shell: the reader meets the companion,
/// answers one question, and the answer seeds the starting detail level. It
/// never blocks a feature — skipping is always available — and it disappears
/// for good once [OnboardingController.complete] lands (it reappears only when
/// the reader asks to replay it from Profile).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  bool? _tarotFamiliar;

  void _goTo(int step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingController>();
    if (!onboarding.loaded || onboarding.completed) {
      return const SizedBox.shrink();
    }
    final lang = context.watch<AppSettingsController>().language;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : TaroMotion.normal;
    final step = switch (_step) {
      0 => _intro(lang, onboarding, key: const ValueKey('onboarding-intro')),
      1 => _experience(
          lang,
          onboarding,
          key: const ValueKey('onboarding-experience'),
        ),
      _ => _ready(lang, onboarding, key: const ValueKey('onboarding-ready')),
    };

    return Material(
      // The overlay lives in MaterialApp.builder, ABOVE the Navigator — without
      // a Material ancestor Flutter falls back to the yellow error text style.
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TaroDuskBackground(),
          const ColoredBox(color: Color(0xE60A0B12)),
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TaroGlassPanel(
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: step,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(
    AppLanguage lang,
    OnboardingController onboarding, {
    Key? key,
  }) =>
      OnboardingStepBody(
        key: key,
        mood: WispMood.greeting,
        title: AppStrings.t(lang, 'onboarding.intro.title'),
        body: AppStrings.t(lang, 'onboarding.intro.body'),
        lang: lang,
        step: _step,
        actions: [
          TaroGlassButton(
            label: AppStrings.t(lang, 'onboarding.next'),
            onPressed: () => _goTo(1),
          ),
          _skipButton(lang, onboarding),
        ],
      );

  Widget _experience(
    AppLanguage lang,
    OnboardingController onboarding, {
    Key? key,
  }) =>
      OnboardingStepBody(
        key: key,
        mood: WispMood.curious,
        title: AppStrings.t(lang, 'onboarding.experience.title'),
        lang: lang,
        step: _step,
        actions: [
          TaroGlassButton(
            key: const ValueKey('onboarding-beginner'),
            label: AppStrings.t(lang, 'onboarding.beginner'),
            icon: Icons.auto_awesome_outlined,
            onPressed: () {
              _tarotFamiliar = false;
              _goTo(2);
            },
          ),
          Text(
            AppStrings.t(lang, 'onboarding.beginner.hint'),
            textAlign: TextAlign.center,
            style: AppTypography.body(
              fontSize: 12,
              color: TaroColors.textSecondary,
            ),
          ),
          TaroGlassButton(
            key: const ValueKey('onboarding-experienced'),
            label: AppStrings.t(lang, 'onboarding.experienced'),
            variant: TaroGlassButtonVariant.secondary,
            onPressed: () {
              _tarotFamiliar = true;
              _goTo(2);
            },
          ),
          Text(
            AppStrings.t(lang, 'onboarding.experienced.hint'),
            textAlign: TextAlign.center,
            style: AppTypography.body(
              fontSize: 12,
              color: TaroColors.textSecondary,
            ),
          ),
          _skipButton(lang, onboarding),
        ],
      );

  Widget _ready(
    AppLanguage lang,
    OnboardingController onboarding, {
    Key? key,
  }) =>
      OnboardingStepBody(
        key: key,
        mood: WispMood.greeting,
        title: AppStrings.t(lang, 'onboarding.ready.title'),
        body: AppStrings.t(lang, 'onboarding.ready.body'),
        lang: lang,
        step: _step,
        actions: [
          TaroGlassButton(
            label: AppStrings.t(lang, 'onboarding.start'),
            onPressed: () => onboarding.complete(tarotFamiliar: _tarotFamiliar),
          ),
        ],
      );

  Widget _skipButton(AppLanguage lang, OnboardingController onboarding) =>
      TaroGlassButton(
        key: const ValueKey('onboarding-skip'),
        label: AppStrings.t(lang, 'onboarding.skip'),
        variant: TaroGlassButtonVariant.ghost,
        onPressed: () => onboarding.complete(),
      );
}
