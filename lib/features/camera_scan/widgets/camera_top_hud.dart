import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/theme/app_colors.dart';

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
        Row(
          children: [
            for (final s in DivinationSystem.values) ...[
              _SystemChip(
                label: s.label,
                active: s == system,
                onTap: () => onSystemChanged(s),
              ),
              if (s != DivinationSystem.values.last) const SizedBox(width: 4),
            ],
          ],
        ),
        if (showActions)
          Row(
            children: [
              _CircleIconButton(
                icon: flashOn ? Icons.flash_on : Icons.flash_off_outlined,
                onTap: onToggleFlash,
              ),
              _CircleIconButton(
                icon: Icons.photo_library_outlined,
                onTap: onPickGallery,
              ),
            ],
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.2)
              : AppColors.canvas.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.canvas.withValues(alpha: 0.55),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}
