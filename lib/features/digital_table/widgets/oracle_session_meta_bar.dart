import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/reading_mode.dart';
import '../../../core/models/reading_source.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../design_system/taro.dart';
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
            TaroGlassPill(label: session.readingSource.label),
            const SizedBox(width: 6),
            TaroGlassPill(label: session.readingMode.label, accent: true),
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
        ? TaroColors.textSecondary
        : speaking
            ? TaroColors.rose
            : TaroColors.lavender;
    return Semantics(
      button: true,
      toggled: !muted,
      label: muted ? 'Unmute the Oracle' : 'Mute the Oracle',
      child: Tooltip(
        message: muted ? 'Unmute the Oracle' : 'Mute the Oracle',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            voice.setMuted(!muted);
          },
          child: Container(
            width: 34,
            height: 28,
            decoration: BoxDecoration(
              color: TaroColors.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
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
    return TaroGlassChip(
      label: label,
      icon: Icons.camera_alt_outlined,
      selected: true,
      compact: true,
      onTap: onTap,
    );
  }
}

