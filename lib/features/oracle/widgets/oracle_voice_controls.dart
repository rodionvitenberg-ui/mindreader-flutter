import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/voice_state.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../design_system/taro_tokens.dart';
import 'oracle_presence_indicator.dart';

/// The interactive half of the voice overlay: mic, mute/unmute, pause,
/// interrupt, expand/collapse and end.
///
/// The TTS buttons ([mute], [pause], [interrupt]) drive the shared
/// [OracleVoiceService] directly; the mic / expand / end actions are
/// caller-owned callbacks so this widget never pretends to own the STT half or
/// the session lifecycle it does not manage.
class OracleVoiceControls extends StatelessWidget {
  const OracleVoiceControls({
    super.key,
    required this.voice,
    this.expanded = true,
    this.onMicToggle,
    this.onToggleExpand,
    this.onEnd,
  });

  final OracleVoiceService voice;

  /// Whether the parent view is the full overlay (true) or the compact capsule
  /// (false) — flips the expand/collapse icon.
  final bool expanded;
  final VoidCallback? onMicToggle;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final muted = voice.isMuted;
        final speaking = voice.isSpeaking;
        final listening = voice.state.isListeningHalf;
        final color = oraclePresenceColor(voice.state, muted);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMicToggle != null)
              _ControlButton(
                icon: listening ? Icons.mic : Icons.mic_none,
                tooltip: listening ? 'Stop listening' : 'Start listening',
                active: listening,
                color: color,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onMicToggle!();
                },
              ),
            _ControlButton(
              icon: muted
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
              tooltip: muted ? 'Unmute the Oracle' : 'Mute the Oracle',
              active: !muted,
              color: color,
              onTap: () {
                HapticFeedback.selectionClick();
                voice.setMuted(!muted);
              },
            ),
            if (voice.state == VoiceState.speaking)
              _ControlButton(
                icon: Icons.pause,
                tooltip: 'Pause',
                active: true,
                color: color,
                onTap: () {
                  HapticFeedback.selectionClick();
                  voice.pause();
                },
              ),
            if (speaking)
              _ControlButton(
                icon: Icons.stop,
                tooltip: 'Interrupt',
                active: true,
                color: color,
                onTap: () {
                  HapticFeedback.selectionClick();
                  voice.stop();
                },
              ),
            if (onToggleExpand != null)
              _ControlButton(
                icon: expanded ? Icons.unfold_less : Icons.open_in_full,
                tooltip: expanded ? 'Collapse' : 'Expand',
                active: false,
                color: color,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleExpand!();
                },
              ),
            if (onEnd != null)
              _ControlButton(
                icon: Icons.call_end,
                tooltip: 'End',
                active: false,
                color: color,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onEnd!();
                },
              ),
          ],
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      toggled: active ? true : null,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? color.withValues(alpha: 0.20)
                      : TaroColors.hudFill,
                  border: Border.all(
                    color: active
                        ? color.withValues(alpha: 0.65)
                        : TaroColors.hudBorder,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: active ? color : TaroColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
