import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/reading_mode.dart';
import '../../../core/theme/app_colors.dart';

/// Segmented physical reading-mode switch shown at the top of the Camera.
/// Only the three camera-driven modes are offered — [ReadingMode.standard]
/// is the digital-table reading and never appears here.
class CameraModeSelector extends StatelessWidget {
  const CameraModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ReadingMode value;
  final ValueChanged<ReadingMode> onChanged;

  static const modes = <ReadingMode>[
    ReadingMode.quickScan,
    ReadingMode.guidedSpread,
    ReadingMode.liveOracle,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final mode in modes) ...[
            Expanded(
              child: _Segment(
                mode: mode,
                active: mode == value,
                onTap: () => onChanged(mode),
              ),
            ),
            if (mode != modes.last) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.mode,
    required this.active,
    required this.onTap,
  });

  final ReadingMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('camera-mode-${mode.name}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          mode.label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.2,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
