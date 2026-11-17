import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../state/spread_controller.dart';
import 'elemental_threads_painter.dart';
import 'shuffle_physics.dart';
import 'slotted_divination_card.dart';

/// "The Pillar" — a strictly vertical column of DEALT cards inside the
/// unified table scroll view. Every card is 1:1 with the hero deck
/// (220×360, gap 56 — the expanded Phase 2 space that hosts the living
/// Elemental Fate Threads). No inner scrolling, no placeholders: the
/// screen's single scroll controller moves deck + pillar as one canvas.
class BoardPillarView extends StatefulWidget {
  const BoardPillarView({super.key, required this.onTapFaceUp});

  final void Function(int slotIndex) onTapFaceUp;

  @override
  State<BoardPillarView> createState() => _BoardPillarViewState();
}

class _BoardPillarViewState extends State<BoardPillarView>
    with TickerProviderStateMixin {
  static const cardWidth = deckWidth; // 220 — identical to the deck
  static const cardHeight = deckHeight; // 360 — identical to the deck
  static const slotGap = slotGapPx; // 20

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  /// Per-pair ignite flash controllers, keyed by the first card's slot
  /// index ([ElementalThreadSegment.pairKey]). A 480ms bolt shoots the
  /// moment BOTH cards of a pair are face-up (the second/subsequent card
  /// just finished flipping).
  final Map<int, AnimationController> _ignites = {};

  @override
  void dispose() {
    for (final controller in _ignites.values) {
      controller.dispose();
    }
    _ignites.clear();
    _pulse.dispose();
    super.dispose();
  }

  /// Starts the 480ms ignite for every NEW face-up pair and disposes the
  /// controllers of pairs that vanished (table reset). Synchronous removal
  /// from the map makes double-dispose impossible; [Ticker.dispose] is
  /// legal while the ticker is still active.
  void _syncIgnites(List<ElementalThreadSegment> segments) {
    final keys = {for (final segment in segments) segment.pairKey};
    for (final key in keys) {
      _ignites.putIfAbsent(
        key,
        () => AnimationController(
          vsync: this,
          duration: igniteFlashDuration,
        )..forward(),
      );
    }
    final stale = [
      for (final key in _ignites.keys)
        if (!keys.contains(key)) key,
    ];
    for (final key in stale) {
      _ignites.remove(key)?.dispose();
    }
  }

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
    final segments = threadSegmentsFor(dealt, rects);
    _syncIgnites(segments);

    // Nothing is rendered before the first deal — no dashed placeholders.
    if (dealt.isEmpty) return const SizedBox.shrink();

    final totalHeight = dealt.length * (cardHeight + slotGap) - slotGap;
    return RepaintBoundary(
      child: SizedBox(
        width: cardWidth,
        height: totalHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, ..._ignites.values]),
                builder: (context, _) => CustomPaint(
                  painter: ElementalThreadsPainter(
                    segments: segments,
                    pulse: _pulse,
                    ignite: {
                      for (var i = 0; i < segments.length; i++)
                        i: _ignites[segments[i].pairKey]?.value ?? 1.0,
                    },
                  ),
                ),
              ),
            ),
            Column(
              children: [
                for (var i = 0; i < dealt.length; i++) ...[
                  _buildCard(context, dealt[i]),
                  if (i < dealt.length - 1) const SizedBox(height: slotGap),
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
      onTapFaceUp: () => widget.onTapFaceUp(slot.index),
    );
  }
}
