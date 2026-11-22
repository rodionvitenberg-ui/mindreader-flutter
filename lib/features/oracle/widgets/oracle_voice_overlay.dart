import 'package:flutter/material.dart';

import '../../../core/services/oracle_voice_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import 'oracle_presence_indicator.dart';
import 'oracle_subtitles.dart';
import 'oracle_voice_controls.dart';
import '../../../core/l10n/app_strings.dart';

/// The full Voice Overlay: a Tarot Tree glass panel meant to dock to the
/// bottom edge BELOW the camera viewfinder — it never covers the viewfinder
/// itself. It carries the presence indicator, the live subtitles and the voice
/// controls.
///
/// Presentation-only: the voice session lives in the shared
/// [OracleVoiceService], so Full ↔ Overlay ↔ Compact transitions never reset
/// it.
class OracleVoiceOverlay extends StatelessWidget {
  const OracleVoiceOverlay({
    super.key,
    required this.voice,
    required this.subtitle,
    this.onMicToggle,
    this.onCollapse,
    this.onEnd,
  });

  final OracleVoiceService voice;
  final String subtitle;
  final VoidCallback? onMicToggle;
  final VoidCallback? onCollapse;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: TaroGlassPanel(
          radius: TaroRadii.panel,
          tint: TaroColors.hudScrim,
          fillColor: TaroColors.hudFill,
          borderColor: TaroColors.hudBorder,
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  OraclePresenceIndicator(voice: voice),
                  const SizedBox(width: 10),
                  Expanded(child: OracleSubtitles(text: subtitle)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(AppStrings.g('ui.oracle_voice_overlay.live_oracle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.lavender,
                      ),
                    ),
                  ),
                  OracleVoiceControls(
                    voice: voice,
                    expanded: true,
                    onMicToggle: onMicToggle,
                    onToggleExpand: onCollapse,
                    onEnd: onEnd,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
