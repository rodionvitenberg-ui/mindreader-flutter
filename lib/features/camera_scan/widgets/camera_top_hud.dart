import 'package:flutter/material.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// Top overlay row for the Camera: the active divination system (what the
/// scan will feed), plus flash and gallery actions. The system switch is an
/// honest affordance — the scan always targets the system selected here.
class CameraTopHud extends StatelessWidget {
  const CameraTopHud({
    super.key,
    required this.system,
    required this.onSystemChanged,
    required this.flashOn,
    required this.onToggleFlash,
    required this.onPickGallery,
    required this.showActions,
  });

  final DivinationSystem system;
  final ValueChanged<DivinationSystem> onSystemChanged;
  final bool flashOn;
  final VoidCallback onToggleFlash;
  final VoidCallback onPickGallery;

  /// Flash/gallery are camera-driven; on the simulated viewfinder they are
  /// hidden (same behavior as before the redesign).
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: TaroGlassSurface(
            radius: TaroRadii.pill,
            tint: TaroColors.hudScrim,
            fillColor: TaroColors.hudFill,
            borderColor: TaroColors.hudBorder,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in DivinationSystem.values) ...[
                    Flexible(
                      child: _SystemChip(
                        label: s.label,
                        active: s == system,
                        onTap: () => onSystemChanged(s),
                      ),
                    ),
                    if (s != DivinationSystem.values.last)
                      const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showActions) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaroGlassIconButton(
                icon: flashOn ? Icons.flash_on : Icons.flash_off_outlined,
                tooltip: flashOn ? 'Turn flash off' : 'Turn flash on',
                active: flashOn,
                size: 44,
                iconSize: 18,
                tint: flashOn ? null : TaroColors.hudScrim,
                fillColor: TaroColors.hudFill,
                borderColor: flashOn ? null : TaroColors.hudBorder,
                onPressed: onToggleFlash,
              ),
              const SizedBox(width: 8),
              TaroGlassIconButton(
                icon: Icons.photo_library_outlined,
                tooltip: 'Pick from gallery',
                size: 44,
                iconSize: 18,
                tint: TaroColors.hudScrim,
                fillColor: TaroColors.hudFill,
                borderColor: TaroColors.hudBorder,
                onPressed: onPickGallery,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TaroMotion.fast,
          constraints: const BoxConstraints(minHeight: 38),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? TaroColors.lavender.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(TaroRadii.pill - 4),
            border: active
                ? Border.all(
                    color: TaroColors.lavender.withValues(
                      alpha: TaroOpacity.borderStrong,
                    ),
                  )
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.label(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? TaroColors.textPrimary : TaroColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
