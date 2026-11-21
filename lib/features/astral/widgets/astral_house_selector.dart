import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../design_system/taro.dart';
import '../astral_copy.dart';

/// Shared PLACIDUS / KOCH / WHOLE SIGN selector used by both the ASTRAL
/// screen and the birth-data form (Phase G5: [TaroGlassSegmentedControl]).
/// A switch never re-generates a chart.
class AstralHouseSelector extends StatelessWidget {
  const AstralHouseSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final HouseSystem value;
  final ValueChanged<HouseSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaroGlassSegmentedControl<HouseSystem>(
      segments: [
        for (final system in HouseSystem.values)
          TaroGlassSegment<HouseSystem>(
            value: system,
            label: context.astroHouseSystem(system),
          ),
      ],
      value: value,
      onChanged: onChanged,
    );
  }
}
