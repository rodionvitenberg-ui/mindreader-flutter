import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/services/oracle_voice_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'oracle_presence_indicator.dart';
import 'oracle_subtitles.dart';
import 'oracle_voice_controls.dart';

/// The full Voice Overlay: a translucent obsidian glass panel meant to dock to
/// the bottom edge BELOW the camera viewfinder — it never covers the
/// viewfinder itself. It carries the presence indicator, the live subtitles
/// and the voice controls.
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'LIVE ORACLE',
                          style: AppTypography.label(
                            fontSize: 9,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lavender,
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
        ),
      ),
    );
  }
}
