import 'package:flutter/material.dart';

import '../../../core/models/reading_mode.dart';
import '../../../core/models/reading_source.dart';
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

/// Source and resume action for physical readings.
class OracleSessionMetaBar extends StatelessWidget {
  const OracleSessionMetaBar({
    super.key,
    required this.session,
    required this.onResumeCamera,
  });

  final OracleSessionController session;
  final VoidCallback onResumeCamera;

  @override
  Widget build(BuildContext context) {
    final ctaLabel = oraclePhysicalCtaLabel(
      session.readingSource,
      session.readingMode,
    );
    final showBadges =
        session.readingSource == ReadingSource.physical ||
        session.readingMode != ReadingMode.standard;

    if (!showBadges && ctaLabel == null) {
      return const SizedBox.shrink();
    }

    return TaroGlassLayer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Row(
          children: [
            if (showBadges) ...[
              TaroGlassPill(label: session.readingSource.label),
              const SizedBox(width: 6),
              TaroGlassPill(label: session.readingMode.label, accent: true),
            ],
            const Spacer(),
            if (ctaLabel != null)
              _PhysicalCta(label: ctaLabel, onTap: onResumeCamera),
          ],
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
