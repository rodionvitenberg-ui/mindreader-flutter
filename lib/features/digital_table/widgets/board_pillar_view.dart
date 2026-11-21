import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_card.dart';
import '../../../core/models/divination_system.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/spread_controller.dart';
import 'spread_threads_layer.dart';
import '../../../state/app_settings_controller.dart';
import 'shuffle_physics.dart';
import 'slotted_divination_card.dart';

/// "The Pillar" — a strictly vertical column of DEALT cards inside the
/// unified table scroll view. Every card is 1:1 with the hero deck
/// (220×360, gap 56 — the expanded Phase 2 space that hosts the living
/// Elemental Fate Threads). No inner scrolling, no placeholders: the
/// screen's single scroll controller moves deck + pillar as one canvas.
class BoardPillarView extends StatelessWidget {
  const BoardPillarView({super.key, this.selected, required this.onTapFaceUp});

  final void Function(int slotIndex) onTapFaceUp;

  final int? selected;
  static const cardWidth = deckWidth;
  static const cardHeight = deckHeight;
  static const slotGap = slotGapPx;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpreadController>();
    final dealt = [
      for (final s in controller.slots)
        if (s.card != null) s,
    ];
    // Parallel card rects in the pillar's local coordinates (dealt slots
    // are contiguous in reading order).
    final rects = [
      for (var i = 0; i < dealt.length; i++)
        Rect.fromLTWH(
          0,
          i * (cardHeight + slotGap),
          cardWidth,
          cardHeight,
        ),
    ];
    // Elemental Fate Threads exist for TAROT only: runes keep their chiseled
    // rim glow, Lenormand reads through pair combinations instead.
    final isLenormand = controller.system == DivinationSystem.lenormand &&
        context.watch<AppSettingsController>().enabled(ReadingAid.relationships);
    // Nothing is rendered before the first deal — no dashed placeholders.
    if (dealt.isEmpty) return const SizedBox.shrink();

    final totalHeight = dealt.length * (cardHeight + slotGap) - slotGap;
    return RepaintBoundary(
      child: SizedBox(
        width: cardWidth,
        height: totalHeight,
        child: Stack(
          children: [
            Positioned.fill(child: SpreadThreadsLayer(selected:selected,rects:{
              for(var i=0;i<dealt.length;i++) dealt[i].index:rects[i],
            })),
            Column(
              children: [
                for (var i = 0; i < dealt.length; i++) ...[
                  _buildCard(context, dealt[i]),
                  if (i < dealt.length - 1)
                    SizedBox(
                      height: slotGap,
                      child: isLenormand
                          ? Center(
                              child: _LenormandPairPill(
                                first: dealt[i],
                                second: dealt[i + 1],
                              ),
                            )
                          : null,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, DealtCardSlot slot) {
    return SlottedDivinationCard(
      // Key changes on state flip → the widget remounts with the face
      // already revealed at rotateY(0), visually continuous with the flip.
      slot: slot,
      width: cardWidth,
      height: cardHeight,
      onFlip: () => context.read<SpreadController>().flipSlot(slot.index),
      onTapFaceUp: () => onTapFaceUp(slot.index),
    );
  }
}

/// The Lenormand replacement for elemental threads: one compact obsidian
/// pill between adjacent FACE-UP cards carrying their traditional pair
/// combination ("With the Letter, the message arrives in writing.").
class _LenormandPairPill extends StatelessWidget {
  const _LenormandPairPill({required this.first, required this.second});

  final DealtCardSlot first;
  final DealtCardSlot second;

  String? _combination() {
    final a = first.card;
    final b = second.card;
    if (a is! LenormandDivinationCard || b is! LenormandDivinationCard) {
      return null;
    }
    final needle = 'with the ${b.card.name.toLowerCase()}';
    for (final line in a.card.combinations) {
      if (line.toLowerCase().startsWith(needle)) return line;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (first.state != SlotState.faceUp || second.state != SlotState.faceUp) {
      return const SizedBox.shrink();
    }
    final a = first.card;
    final b = second.card;
    if (a == null || b == null) return const SizedBox.shrink();
    final hint = _combination();
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaroColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${a.name.toUpperCase()} + ${b.name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(
              fontSize: 8,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: TaroColors.lavender,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  height: 1.25,
                  color: TaroColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

