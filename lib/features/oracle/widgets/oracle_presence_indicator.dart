import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/voice_state.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../core/theme/app_colors.dart';

/// The single palette decision for the Oracle's "aliveness": which accent
/// color the presence ring, waveform and controls share for a given voice
/// state. Pure — no widgets, so it is trivially unit-testable.
Color oraclePresenceColor(VoiceState state, bool muted) {
  if (muted) return AppColors.textMuted;
  return switch (state) {
    VoiceState.speaking || VoiceState.paused => AppColors.lavender,
    VoiceState.listening || VoiceState.transcribing => AppColors.indigo,
    VoiceState.thinking => AppColors.harmonyCyan,
    VoiceState.error => AppColors.conflictRose,
    VoiceState.idle || VoiceState.unavailable || VoiceState.muted =>
      AppColors.textMuted,
  };
}

/// True while the Oracle is audibly alive — drives the pulse + waveform
/// motion. Pure.
bool oraclePresenceActive(VoiceState state) =>
    state == VoiceState.speaking ||
    state == VoiceState.listening ||
    state == VoiceState.transcribing ||
    state == VoiceState.thinking;

/// A compact "the Oracle is here" marker: a pulsing lavender glow plus a
/// subtle animated waveform. GPU-composited only — the pulse is an opacity
/// fade + a scale on a `Transform`, the waveform is a `CustomPainter` inside a
/// `RepaintBoundary`; nothing here touches layout properties per frame.
class OraclePresenceIndicator extends StatefulWidget {
  const OraclePresenceIndicator({super.key, required this.voice, this.size = 20});

  final OracleVoiceService voice;
  final double size;

  @override
  State<OraclePresenceIndicator> createState() => _OraclePresenceIndicatorState();
}

class _OraclePresenceIndicatorState extends State<OraclePresenceIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    widget.voice.addListener(_onVoiceChanged);
    _syncTicker();
  }

  @override
  void dispose() {
    widget.voice.removeListener(_onVoiceChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    _syncTicker();
  }

  /// The pulse only runs while the Oracle is alive; idle leaves a static,
  /// dim ring so the ticker is never wasting frames on silence.
  void _syncTicker() {
    if (oraclePresenceActive(widget.voice.state)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.voice,
      builder: (context, _) {
        final muted = widget.voice.isMuted;
        final color = oraclePresenceColor(widget.voice.state, muted);
        final active = oraclePresenceActive(widget.voice.state);
        final size = widget.size;
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final pulse = active ? _pulse.value : 0.0;
            return SizedBox(
              width: size + 12,
              height: size + 12,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1.0 + 0.4 * pulse,
                    child: Opacity(
                      opacity: active ? 0.12 + 0.4 * pulse : 0.10,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(size, size * 0.55),
                      painter: _WaveformPainter(color: color, phase: _pulse.value),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Subtle five-bar waveform; bar heights follow a traveling sine so the motion
/// reads as "speaking", never as a loud equalizer.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.color, required this.phase});

  final Color color;
  final double phase;

  static const int _bars = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final gap = size.width / (_bars * 2);
    final maxHeight = size.height;
    for (var i = 0; i < _bars; i++) {
      final t = (math.sin(phase * math.pi * 2 + i * 0.9) + 1) / 2;
      final h = maxHeight * (0.25 + 0.75 * t);
      final x = gap + i * gap * 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color || old.phase != phase;
}
