import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/spread_type.dart';
import '../../core/theme/app_colors.dart';
import '../../state/spread_controller.dart';
import 'widgets/board_pillar_view.dart';
import 'widgets/interactive_deck_widget.dart';
import 'widgets/reading_bottom_sheet.dart';

/// The Digital Table: header + vertical pillar + spread selector pill +
/// tactile deck (the core 120 FPS loop of the app).
class DigitalTableScreen extends StatelessWidget {
  const DigitalTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TableHeader(ctrl: ctrl),
          Expanded(
            child: BoardPillarView(
              onTapFaceUp: (slotIndex) =>
                  ReadingBottomSheet.show(context, cardIndex: slotIndex),
            ),
          ),
          const _SpreadSelectorPill(),
          const InteractiveDeckWidget(),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.ctrl});

  final SpreadController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIGITAL TABLE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ctrl.spreadType.label.toUpperCase()} · ${ctrl.remaining} IN DECK · PINCH TO OVERVIEW',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    letterSpacing: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _GlassPill(
            label: 'SYNTHESIZE',
            onTap: () => ReadingBottomSheet.show(context),
          ),
        ],
      ),
    );
  }
}

/// Spread method selector — sits right above the bottom navigation bar.
class _SpreadSelectorPill extends StatelessWidget {
  const _SpreadSelectorPill();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        itemCount: SpreadType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = SpreadType.values[i];
          final active = type == ctrl.spreadType;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<SpreadController>().setSpreadType(type);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.lavender.withValues(alpha: 0.16)
                    : AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.lavender : AppColors.border,
                ),
              ),
              child: Text(
                type.label.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: active ? AppColors.lavender : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small glass capsule used for header actions.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.4,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}
