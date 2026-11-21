import 'package:flutter/material.dart';

import '../../../core/services/oracle_voice_service.dart';
import '../../../design_system/taro.dart';
import 'oracle_presence_indicator.dart';
import 'oracle_voice_controls.dart';

/// The Compact Oracle: a floating Tarot Tree glass capsule that docks to an
/// edge without covering the viewfinder. It shows the presence indicator plus
/// a minimal set of voice controls, and expands to the full
/// [OracleVoiceOverlay].
///
/// Shares the SAME [OracleVoiceService] as the overlay and the full chat, so
/// switching views never resets the voice session.
class CompactOracle extends StatelessWidget {
  const CompactOracle({
    super.key,
    required this.voice,
    this.onMicToggle,
    this.onExpand,
    this.onEnd,
  });

  final OracleVoiceService voice;
  final VoidCallback? onMicToggle;
  final VoidCallback? onExpand;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return TaroGlassPanel(
      radius: TaroRadii.pill,
      tint: TaroColors.hudScrim,
      fillColor: TaroColors.hudFill,
      borderColor: TaroColors.hudBorder,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OraclePresenceIndicator(voice: voice),
          const SizedBox(width: 4),
          OracleVoiceControls(
            voice: voice,
            expanded: false,
            onMicToggle: onMicToggle,
            onToggleExpand: onExpand,
            onEnd: onEnd,
          ),
        ],
      ),
    );
  }
}
