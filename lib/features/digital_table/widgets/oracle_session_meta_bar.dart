import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/reading_mode.dart';
import '../../../core/models/reading_source.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/oracle_session_controller.dart';

/// The label of the physical-flow call-to-action, or null for a plain digital
/// STANDARD reading (where no camera/guided CTA belongs). Pure — no Flutter.
String? oraclePhysicalCtaLabel(ReadingSource source, ReadingMode mode) {
  if (source == ReadingSource.digital && mode == ReadingMode.standard) {
    return null;
  }
  return switch (mode) {
    ReadingMode.quickScan => 'RESUME CAMERA',
    ReadingMode.liveOracle => 'RESUME CAMERA',
    ReadingMode.guidedSpread => 'CONTINUE GUIDED SESSION',
    ReadingMode.standard => 'RETURN TO PHYSICAL SPREAD',
  };
}

/// The thin session bar under the chat header: the DIGITAL/PHYSICAL source
/// badge, the mode badge (QUICK SCAN / GUIDED SPREAD / LIVE ORACLE), the
/// Oracle voice toggle, and — for physical flows — the resume/return
/// call-to-action. Collapses to nothing for a plain digital STANDARD reading
/// with no TTS, so the chat stays uncluttered.
class OracleSessionMetaBar extends StatelessWidget {
  const OracleSessionMetaBar({
    super.key,
    required this.session,
    required this.voice,
    required this.onResumeCamera,
  });

  final OracleSessionController session;
  final OracleVoiceService voice;
  final VoidCallback onResumeCamera;

  @override
  Widget build(BuildContext context) {
    final ctaLabel = oraclePhysicalCtaLabel(
      session.readingSource,
      session.readingMode,
    );
    final showBadges = session.readingSource == ReadingSource.physical ||
        session.readingMode != ReadingMode.standard;

    if (!showBadges && ctaLabel == null && !voice.isAvailable) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(
        children: [
          if (showBadges) ...[
            _MetaBadge(label: session.readingSource.label),
            const SizedBox(width: 6),
            _MetaBadge(label: session.readingMode.label, accent: true),
          ],
          const Spacer(),
          if (voice.isAvailable)
            ListenableBuilder(
              listenable: voice,
              builder: (context, _) => _VoiceToggle(voice: voice),
            ),
          if (voice.isAvailable && ctaLabel != null) const SizedBox(width: 6),
          if (ctaLabel != null)
            _PhysicalCta(label: ctaLabel, onTap: onResumeCamera),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.lavender : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (accent ? AppColors.lavender : AppColors.textMuted)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _VoiceToggle extends StatelessWidget {
  const _VoiceToggle({required this.voice});

  final OracleVoiceService voice;

  @override
  Widget build(BuildContext context) {
    final muted = voice.isMuted;
    final speaking = voice.isSpeaking;
    final IconData icon = muted
        ? Icons.volume_off_outlined
        : speaking
            ? Icons.graphic_eq
            : Icons.volume_up_outlined;
    final color = muted
        ? AppColors.textMuted
        : speaking
            ? AppColors.conflictRose
            : AppColors.lavender;
    return Tooltip(
      message: muted ? 'Unmute the Oracle' : 'Mute the Oracle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          voice.setMuted(!muted);
        },
        child: Container(
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _PhysicalCta extends StatelessWidget {
  const _PhysicalCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 13, color: AppColors.lavender),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

