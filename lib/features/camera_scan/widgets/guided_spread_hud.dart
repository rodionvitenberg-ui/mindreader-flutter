import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/live_reading_controller.dart';

/// The viewfinder instruction for each Guided Spread phase, in one place so
/// the Camera and the HUD share a single vocabulary (never hand-rolled).
String guidedInstruction(GuidePhase phase) => switch (phase) {
      GuidePhase.preparing => 'PREPARING YOUR READING',
      GuidePhase.awaitingIntention => 'SET YOUR INTENTION',
      GuidePhase.awaitingCard => 'DRAW A CARD AND PLACE IT',
      GuidePhase.cardDetected => 'CARD DETECTED — HOLD STEADY',
      GuidePhase.awaitingReveal => 'TURN THE CARD FACE-UP',
      GuidePhase.recognizingCard => 'READING THE CARD',
      GuidePhase.awaitingConfirmation => 'CONFIRM THE CARD?',
      GuidePhase.interpretingCard => 'INTERPRETING THE CARD',
      GuidePhase.awaitingUser => 'YOUR TURN',
      GuidePhase.awaitingNextCard => 'READY FOR THE NEXT CARD',
      GuidePhase.spreadCompleted => 'SPREAD COMPLETE',
      GuidePhase.paused => 'PAUSED',
      GuidePhase.completed => 'READING COMPLETE',
      GuidePhase.cancelled => 'CANCELLED',
      GuidePhase.error => 'SOMETHING WENT WRONG',
    };

/// The primary action label for a phase, or null when there is no primary
/// action yet (the reader is still moving cards). Drives the Confirm / Next /
/// Resume button so the button and the FSM can never disagree.
String? guidedPrimaryAction(GuidePhase phase) => switch (phase) {
      GuidePhase.awaitingConfirmation => 'CONFIRM',
      GuidePhase.awaitingNextCard => 'NEXT',
      GuidePhase.paused => 'RESUME',
      _ => null,
    };

/// The bottom HUD for the Guided Physical Spread camera flow.
///
/// Shows the spread name, live progress (`2/3`), the current slot role and the
/// phase-derived instruction, plus flash / pause / exit and a phase-derived
/// Confirm/Next primary action and an "open full chat" affordance.
///
/// It is a PURE presentation widget — every value arrives as a prop — and it
/// draws NO world-anchored AR: positions are visual hints only.
class GuidedSpreadHud extends StatelessWidget {
  const GuidedSpreadHud({
    super.key,
    required this.spreadName,
    required this.filledCount,
    required this.totalSlots,
    required this.currentSlotRole,
    required this.phase,
    required this.flashOn,
    required this.onToggleFlash,
    required this.onPause,
    required this.onExit,
    required this.onConfirm,
    required this.onResume,
    required this.onOpenChat,
  });

  final String spreadName;
  final int filledCount;
  final int totalSlots;
  final String currentSlotRole;
  final GuidePhase phase;
  final bool flashOn;
  final VoidCallback onToggleFlash;
  final VoidCallback onPause;
  final VoidCallback onExit;
  final VoidCallback onConfirm;
  final VoidCallback onResume;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final primary = guidedPrimaryAction(phase);
    final isPaused = phase == GuidePhase.paused;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TaroGlassPanel(
          radius: 18,
          tint: TaroColors.hudScrim,
          fillColor: TaroColors.hudFill,
          borderColor: TaroColors.hudBorder,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      spreadName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TaroGlassPill(
                    label: '$filledCount/$totalSlots',
                    accent: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currentSlotRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 1.0,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      guidedInstruction(phase),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.lavender,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TaroGlassPanel(
          radius: 18,
          tint: TaroColors.hudScrim,
          fillColor: TaroColors.hudFill,
          borderColor: TaroColors.hudBorder,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              TaroGlassIconButton(
                icon: flashOn ? Icons.flash_on : Icons.flash_off_outlined,
                tooltip: flashOn ? 'Turn flash off' : 'Turn flash on',
                active: flashOn,
                size: 44,
                iconSize: 18,
                tint: flashOn ? null : TaroColors.hudScrim,
                fillColor: TaroColors.hudFill,
                borderColor: flashOn ? null : TaroColors.hudBorder,
                onPressed: onToggleFlash,
              ),
              const SizedBox(width: 6),
              TaroGlassIconButton(
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                tooltip: isPaused ? 'Resume reading' : 'Pause reading',
                active: isPaused,
                size: 44,
                iconSize: 18,
                tint: isPaused ? null : TaroColors.hudScrim,
                fillColor: TaroColors.hudFill,
                borderColor: isPaused ? null : TaroColors.hudBorder,
                onPressed: isPaused ? onResume : onPause,
              ),
              const SizedBox(width: 6),
              TaroGlassIconButton(
                icon: Icons.close,
                tooltip: 'Exit guided spread',
                size: 44,
                iconSize: 18,
                tint: TaroColors.hudScrim,
                fillColor: TaroColors.hudFill,
                borderColor: TaroColors.hudBorder,
                onPressed: onExit,
              ),
              const Spacer(),
              if (primary != null) ...[
                Flexible(
                  flex: 2,
                  child: TaroGlassButton(
                    key: ValueKey('guided-primary-$primary'),
                    label: primary,
                    variant: TaroGlassButtonVariant.primary,
                    onPressed: primary == 'RESUME' ? onResume : onConfirm,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              TaroGlassIconButton(
                icon: Icons.chat_bubble_outline,
                tooltip: 'Open full chat',
                size: 44,
                iconSize: 18,
                tint: TaroColors.hudScrim,
                fillColor: TaroColors.hudFill,
                borderColor: TaroColors.hudBorder,
                onPressed: onOpenChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
