import 'package:flutter/material.dart';

import '../../../core/models/reading_mode.dart';
import '../../../design_system/taro.dart';

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
    return TaroGlassSegmentedControl<ReadingMode>(
      value: value,
      onChanged: onChanged,
      tint: TaroColors.hudScrim,
      fillColor: TaroColors.hudFill,
      borderColor: TaroColors.hudBorder,
      segments: [
        for (final mode in modes)
          TaroGlassSegment<ReadingMode>(
            key: ValueKey('camera-mode-${mode.name}'),
            value: mode,
            label: mode.label,
          ),
      ],
    );
  }
}
