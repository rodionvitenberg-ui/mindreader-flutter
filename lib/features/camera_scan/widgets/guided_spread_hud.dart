import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassPanel(
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
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$filledCount/$totalSlots',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      letterSpacing: 1.6,
                      color: AppColors.lavender,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                currentSlotRole,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          child: Row(
            children: [
              _CircleIconButton(
                icon: flashOn ? Icons.flash_on : Icons.flash_off_outlined,
                onTap: onToggleFlash,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: phase == GuidePhase.paused
                    ? Icons.play_arrow
                    : Icons.pause,
                onTap: phase == GuidePhase.paused ? onResume : onPause,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(icon: Icons.close, onTap: onExit),
              const Spacer(),
              Expanded(
                child: Text(
                  guidedInstruction(phase),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              if (primary != null)
                _PrimaryButton(
                  label: primary,
                  onTap: primary == 'RESUME' ? onResume : onConfirm,
                ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.chat_bubble_outline,
                onTap: onOpenChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.canvas.withValues(alpha: 0.55),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('guided-primary-$label'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}
