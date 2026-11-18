import 'package:flutter/material.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_card.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/rune_stone.dart';
import 'lenormand_card_3d_widget.dart';
import 'rune_stone_3d_widget.dart';
import 'tarot_card_3d_widget.dart';

/// The system-aware slot renderer: one dealt piece of ANY divination system
/// drawn in the unified 220×360 slot footprint. Tarot and Lenormand render
/// as full cards; a rune renders as a carved stone (~0.72× footprint)
/// centered in the slot with its role floating above.
class SlottedDivinationCard extends StatelessWidget {
  const SlottedDivinationCard({
    super.key,
    required this.slot,
    required this.width,
    required this.height,
    this.tilt = true,
    this.interactive = true,
    required this.onFlip,
    required this.onTapFaceUp,
  });

  final DealtCardSlot slot;
  final double width;
  final double height;
  final bool tilt;
  final bool interactive;
  final VoidCallback onFlip;
  final VoidCallback onTapFaceUp;

  @override
  Widget build(BuildContext context) {
    final card = slot.card;
    if (card == null) {
      return SizedBox(width: width, height: height);
    }
    // The key MUST stay stable across the flip: it changes only when the
    // slot's identity changes (index + card id), never on state/isFaceUp.
    // A state-keyed slot would remount the 3D widget and skip the 750ms
    // mist materialization entirely.
    final stableKey = ValueKey('slot_${slot.index}_${card.id}');
    return switch (card.system) {
      DivinationSystem.tarot => TarotCard3DWidget(
          key: stableKey,
          card: (card as TarotDivinationCard).card,
          isReversed: slot.isReversed,
          state: slot.state,
          width: width,
          height: height,
          tilt: tilt,
          interactive: interactive,
          onFlip: onFlip,
          onTapFaceUp: onTapFaceUp,
        ),
      DivinationSystem.lenormand => LenormandCard3DWidget(
          key: stableKey,
          card: (card as LenormandDivinationCard).card,
          isReversed: false,
          state: slot.state,
          width: width,
          height: height,
          tilt: tilt,
          interactive: interactive,
          onFlip: onFlip,
          onTapFaceUp: onTapFaceUp,
        ),
      DivinationSystem.runes => _RuneSlot(
          key: stableKey,
          slotIndex: slot.index,
          stone: (card as RuneDivinationCard).stone,
          isMerkstave: slot.isReversed,
          state: slot.state,
          width: width,
          height: height,
          interactive: interactive,
          onFlip: onFlip,
          onTapFaceUp: onTapFaceUp,
        ),
    };
  }
}

/// A rune cast into a card-sized slot: the carved stone centered with the
/// slot's role label floating above it (threads still anchor to the full
/// slot rectangle).
class _RuneSlot extends StatelessWidget {
  const _RuneSlot({
    super.key,
    required this.slotIndex,
    required this.stone,
    required this.isMerkstave,
    required this.state,
    required this.width,
    required this.height,
    required this.interactive,
    required this.onFlip,
    required this.onTapFaceUp,
  });

  final int slotIndex;
  final RuneStone stone;
  final bool isMerkstave;
  final SlotState state;
  final double width;
  final double height;
  final bool interactive;
  final VoidCallback onFlip;
  final VoidCallback onTapFaceUp;

  @override
  Widget build(BuildContext context) {
    final stoneSize = width * 0.74;
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: stoneSize,
            height: stoneSize * 1.18,
            child: RuneStone3DWidget(
              stone: stone,
              isMerkstave: isMerkstave,
              state: state,
              slotIndex: slotIndex,
              tilt: true,
              width: stoneSize,
              height: stoneSize * 1.18,
              interactive: interactive,
              onFlip: onFlip,
              onTapFaceUp: onTapFaceUp,
            ),
          ),
        ],
      ),
    );
  }
}
