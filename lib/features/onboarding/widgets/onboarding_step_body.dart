import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../digital_table/widgets/wisp_mascot.dart';
import '../../digital_table/widgets/wisp_mood.dart';

/// The shared skeleton of one onboarding step: Wisp floating above a unified
/// speech bubble, eyebrow, title, progress dots and the action stack.
///
/// Kept separate from [OnboardingFlow] so the flow only decides *which* step is
/// on screen. Wisp introduces himself from the very first moment using the same
/// speech-bubble aesthetic he uses on the Digital Table.
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
  final WispMood mood;
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
        Center(
          child: WispMascot(
            size: 96,
            mood: mood,
            gazeTarget: const Offset(0.05, 0.12),
          ),
        ),
        const SizedBox(height: 2),
        CustomPaint(
          painter: _TopSpeechBubblePainter(
            tailHeight: 9,
            radius: 18,
            fill: TaroColors.lavender.withValues(alpha: 0.10),
            border: TaroColors.lavender.withValues(alpha: 0.30),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.t(lang, 'onboarding.eyebrow'),
                  textAlign: TextAlign.center,
                  style: AppTypography.label(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.lavender,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      fontSize: 13.5,
                      color: TaroColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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

/// Unified speech bubble with an integrated top-center tail pointing up to Wisp
/// (zero seam line across the tail base).
class _TopSpeechBubblePainter extends CustomPainter {
  const _TopSpeechBubblePainter({
    required this.tailHeight,
    required this.radius,
    required this.fill,
    required this.border,
  });

  final double tailHeight;
  final double radius;
  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final top = tailHeight;
    final right = size.width;
    final bottom = size.height;
    final r = radius.clamp(0.0, (bottom - top) / 2);
    final midX = right * 0.5;
    const tailHalf = 9.0;

    final path = Path()
      ..moveTo(r, top)
      ..lineTo(midX - tailHalf, top)
      ..quadraticBezierTo(midX - tailHalf * 0.25, top * 0.35, midX, 0)
      ..quadraticBezierTo(midX + tailHalf * 0.25, top * 0.35, midX + tailHalf, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(r, bottom)
      ..arcToPoint(Offset(0, bottom - r), radius: Radius.circular(r))
      ..lineTo(0, top + r)
      ..arcToPoint(Offset(r, top), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_TopSpeechBubblePainter old) =>
      old.tailHeight != tailHeight ||
      old.radius != radius ||
      old.fill != fill ||
      old.border != border;
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
