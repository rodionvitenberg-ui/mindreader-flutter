import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../digital_table/widgets/guide_mascot.dart';

/// The shared skeleton of one onboarding step: companion, eyebrow, title,
/// optional body, progress dots and the action stack.
///
/// Kept separate from [OnboardingFlow] so the flow only decides *which* step is
/// on screen. The companion reuses the real table mascot — whatever look it
/// gets later shows up here without touching this file.
class OnboardingStepBody extends StatelessWidget {
  const OnboardingStepBody({
    super.key,
    required this.lang,
    required this.mood,
    required this.title,
    required this.step,
    required this.actions,
    this.body,
  });

  final AppLanguage lang;
  final GuideMascotMood mood;
  final String title;
  final String? body;
  final int step;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: GuideMascot(size: 56, mood: mood)),
        const SizedBox(height: 18),
        Text(
          AppStrings.t(lang, 'onboarding.eyebrow'),
          textAlign: TextAlign.center,
          style: AppTypography.label(
            color: TaroColors.mist,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.display(
            fontSize: 23,
            color: TaroColors.textPrimary,
            height: 1.2,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 10),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              color: TaroColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _ProgressDots(active: step),
        const SizedBox(height: 18),
        for (var i = 0; i < actions.length; i++) ...[
          actions[i],
          if (i != actions.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Three dots: where the reader is in the intro. No per-frame animation —
/// only the highlight changes between steps.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: i == active ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == active
                  ? TaroColors.lavender
                  : TaroColors.mist.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
