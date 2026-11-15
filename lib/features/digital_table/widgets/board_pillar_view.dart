import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/spread_controller.dart';
import 'elemental_threads_painter.dart';
import 'tarot_card_3d_widget.dart';

/// "The Pillar" — a strictly vertical 2.5D column of card slots.
/// Single-thumb vertical pan + pinch-to-zoom overview (InteractiveViewer),
/// no horizontal table panning.
class BoardPillarView extends StatefulWidget {
  const BoardPillarView({super.key, required this.onTapFaceUp});

  final void Function(int slotIndex) onTapFaceUp;

  @override
  State<BoardPillarView> createState() => _BoardPillarViewState();
}

class _BoardPillarViewState extends State<BoardPillarView>
    with SingleTickerProviderStateMixin {
  static const cardWidth = 140.0;
  static const cardHeight = 233.0;
  static const slotGap = 30.0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpreadController>();
    final slots = controller.slots;
    final threads = computeThreads(slots);
    final totalHeight = slots.length * (cardHeight + slotGap);
    return RepaintBoundary(
      child: InteractiveViewer(
        constrained: false,
        minScale: 0.35,
        maxScale: 1.15,
        alignment: Alignment.topCenter,
        boundaryMargin: const EdgeInsets.symmetric(vertical: 200),
        child: SizedBox(
          width: cardWidth,
          height: totalHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ElementalThreadsPainter(
                    threads: threads,
                    pulse: _pulse,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    gap: slotGap,
                  ),
                ),
              ),
              Column(
                children: [for (final slot in slots) _buildSlot(context, slot)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(BuildContext context, DealtCardSlot slot) {
    final card = slot.card;
    return Padding(
      padding: const EdgeInsets.only(bottom: slotGap),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: card == null
            ? _EmptySlotPlaceholder(index: slot.index, role: slot.role)
            : TarotCard3DWidget(
                // Key changes on state flip → the widget remounts with the
                // face already revealed at rotateY(0), visually continuous
                // with the end of the flip animation.
                key: ValueKey('slot-${slot.index}-${slot.state}'),
                card: card,
                isReversed: slot.isReversed,
                state: slot.state,
                width: cardWidth,
                height: cardHeight,
                onFlip: () =>
                    context.read<SpreadController>().flipSlot(slot.index),
                onTapFaceUp: () => widget.onTapFaceUp(slot.index),
              ),
      ),
    );
  }
}

class _EmptySlotPlaceholder extends StatelessWidget {
  const _EmptySlotPlaceholder({required this.index, required this.role});

  final int index;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${index + 1}',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.55),
              fontSize: 26,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 1.4,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
