import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/services/oracle_voice_service.dart';
import '../../../core/theme/app_colors.dart';
import 'oracle_presence_indicator.dart';
import 'oracle_voice_controls.dart';

/// The Compact Oracle: a floating capsule that docks to an edge without
/// covering the viewfinder. It shows the presence indicator plus a minimal set
/// of voice controls, and expands to the full [OracleVoiceOverlay].
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ),
      ),
    );
  }
}
