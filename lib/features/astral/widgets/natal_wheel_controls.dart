import 'package:flutter/material.dart';

import '../astral_copy.dart';
import '../../../core/models/natal_chart.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';

/// Small glass pill for wheel actions (replay, transits overlay).
class NatalWheelPill extends StatelessWidget {
  const NatalWheelPill({
    required this.label,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? TaroColors.lavender.withValues(alpha: 0.14)
              : TaroColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active
                ? TaroColors.lavender.withValues(alpha: 0.6)
                : TaroColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            fontSize: 8.5,
            letterSpacing: 0.7,
            color: active ? TaroColors.lavender : TaroColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Wheel header: `NATAL WHEEL` + location/house-system line and the
/// REPLAY / LIVE TRANSITS controls.
class NatalWheelHeader extends StatelessWidget {
  const NatalWheelHeader({
    required this.subtitle,
    required this.onReplay,
    required this.onToggleTransits,
    required this.transitsActive,
    super.key,
  });

  final String subtitle;
  final VoidCallback onReplay;
  final VoidCallback onToggleTransits;
  final bool transitsActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.astralText('natalWheel'),
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 1.0,
                      color: TaroColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 8,
                      letterSpacing: 0.7,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            NatalWheelPill(
              key: const ValueKey('natal-wheel-replay'),
              label: context.astralText('replay'),
              onTap: onReplay,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: NatalWheelPill(
            key: const ValueKey('natal-wheel-transits'),
            label: context.astralText('overlay'),
            active: transitsActive,
            onTap: onToggleTransits,
          ),
        ),
      ],
    );
  }
}

/// The ten natal bodies as tappable glyph chips.
class NatalPlanetChipBar extends StatelessWidget {
  const NatalPlanetChipBar({
    required this.planets,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<NatalPlanetPosition> planets;
  final PlanetId? selected;
  final ValueChanged<PlanetId?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final position in planets)
          if (position.planet.isBody)
            NatalPlanetChip(
              key: ValueKey('planet-chip-${position.planet.name}'),
              position: position,
              selected: selected == position.planet,
              onTap: () => onSelect(
                selected == position.planet ? null : position.planet,
              ),
            ),
      ],
    );
  }
}

/// Glyph chip for one natal body; selecting it lights up its chords.
class NatalPlanetChip extends StatelessWidget {
  const NatalPlanetChip({
    required this.position,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final NatalPlanetPosition position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final retro = position.isRetrograde ? '·Rx' : '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? TaroColors.lavender.withValues(alpha: 0.16)
              : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? TaroColors.lavender.withValues(alpha: 0.7)
                : TaroColors.border,
          ),
        ),
        child: Text(
          '${position.planet.glyph} ${position.sign.glyph}$retro',
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.6,
            color: selected ? TaroColors.lavender : TaroColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
