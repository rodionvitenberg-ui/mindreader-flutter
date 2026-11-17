import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/spread_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/spread_controller.dart';

/// Compact spread switcher opened from the tappable header subtitle
/// (`3 · TRIAD FLOW · 78 IN DECK ▾`) — replaces the old bottom carousel.
class SpreadSelectorSheet extends StatelessWidget {
  const SpreadSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const SpreadSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'SPREAD METHOD',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 2.2,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < SpreadType.values.length; i++) ...[
            _SpreadOption(
              type: SpreadType.values[i],
              active: SpreadType.values[i] == ctrl.spreadType,
            ),
            if (i < SpreadType.values.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SpreadOption extends StatelessWidget {
  const _SpreadOption({required this.type, required this.active});

  final SpreadType type;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<SpreadController>().setSpreadType(type);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              '${type.cardCount} •',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color:
                          active ? AppColors.lavender : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${type.cardCount} CARDS · ${type.focusLine}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.lavender,
              ),
          ],
        ),
      ),
    );
  }
}
