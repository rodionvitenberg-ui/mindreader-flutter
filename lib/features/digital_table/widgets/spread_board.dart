import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/spread_type.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/element_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import '../../profile/widgets/profile_header.dart';
import 'elemental_threads_painter.dart';
import 'shuffle_physics.dart';
import 'slotted_divination_card.dart';
import 'reading_bottom_sheet.dart';
import 'spread_deck_dock.dart';
import 'spread_threads_layer.dart';
import 'spread_viewport.dart';

class SpreadBoard extends StatelessWidget {
  const SpreadBoard({
    super.key,
    required this.header,
    required this.badge,
    required this.onDeal,
  });

  final Widget header;
  final Widget badge;
  final VoidCallback onDeal;

  /// Solves the coupled dock height and viewport fit scale so the horizontal
  /// deck's top card in [SpreadDeckDock] matches the rendered size of each
  /// card on the table (`deckHeight * fit` × `deckWidth * fit`) without moving
  /// the deck out of its centered top-dock position.
  static ({double dockHeight, double deckWidthPx, double deckHeightPx})
      _dockSizingFor(Size area, Size boardSize) {
    const headerH = ProfileHeader.actionSize;
    const deckPad = 12.0;
    const stackEdge = 4.0;
    if (area.height <= headerH + deckPad + stackEdge || area.width <= 0) {
      return (
        dockHeight: math.min(area.height, headerH),
        deckWidthPx: 0,
        deckHeightPx: 0,
      );
    }
    var inset = 12.0;
    var fit = 1.0;
    for (var i = 0; i < 3; i++) {
      final availW = math.max(1.0, area.width - 2 * inset);
      final availH = math.max(
        1.0,
        area.height - headerH - deckPad - stackEdge - 2 * inset,
      );
      final fitW = availW / boardSize.width;
      final fitH = availH / (boardSize.height + deckWidth);
      fit = math.min(1.0, math.min(fitW, fitH)).clamp(0.0, 1.0);
      final dockH = headerH + deckPad + stackEdge + deckWidth * fit;
      final vpH = math.max(0.0, area.height - dockH);
      inset = math.min(12.0, math.min(area.width, vpH) / 8);
    }
    final cardShort = deckWidth * fit;
    final cardLong = deckHeight * fit;
    return (
      dockHeight: math.min(area.height, headerH + deckPad + stackEdge + cardShort),
      deckWidthPx: cardLong + stackEdge,
      deckHeightPx: cardShort + stackEdge,
    );
  }

  SpreadBoardGeometry _geometryFor(SpreadController ctrl) {
    final loveBridge =
        !ctrl.isCustomSpread &&
        ctrl.system == DivinationSystem.tarot &&
        ctrl.spreadType == SpreadType.loveBridge;
    return ctrl.isCustomSpread
        ? spreadBoardGeometryForCustom(
            ctrl.spreadCardCount,
            totalSlots: ctrl.slots.length,
          )
        : spreadBoardGeometryForCount(
            ctrl.spreadCardCount,
            totalSlots: ctrl.slots.length,
            loveBridge: loveBridge,
          );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final geometry = _geometryFor(ctrl);
    return LayoutBuilder(
      builder: (context, area) {
        final sizing = _dockSizingFor(area.biggest, geometry.canvasSize);
        return Column(
          children: [
            SizedBox(
              height: sizing.dockHeight,
              width: double.infinity,
              child: SpreadDeckDock(
                header: header,
                badge: badge,
                onDeal: onDeal,
                deckWidthPx: sizing.deckWidthPx,
                deckHeightPx: sizing.deckHeightPx,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) =>
                    _canvas(context, ctrl, geometry, c.biggest),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _canvas(
    BuildContext context,
    SpreadController ctrl,
    SpreadBoardGeometry geometry,
    Size viewport,
  ) {
    if (viewport.isEmpty) return const SizedBox.shrink();
    final design = geometry.canvasSize;
    final dealt = [
      for (final s in ctrl.slots)
        if (s.card != null) s,
    ];

    final rects = geometry.slotRects;

    final designCanvas = SizedBox(
      width: design.width,
      height: design.height,
      child: Stack(
        children: [
          // The living Elemental Fate Threads across the spread geometry —
          // TAROT ONLY. Runes keep their rim glow, Lenormand its pair pills.
          if (elementalThreadsVisibleFor(ctrl.system))
            SpreadThreadsLayer(dealt: dealt, rects: rects),
          for (var i = 0; i < rects.length; i++)
            Positioned(
              left: rects[i].left,
              top: rects[i].top,
              width: deckWidth,
              height: deckHeight,
              child: _OverviewSlot(slot: ctrl.slots[i], slotIndex: i),
            ),
        ],
      ),
    );

    return SpreadViewport(
      key: ValueKey(ctrl.readingRevision),
      viewport: viewport,
      boardSize: design,
      fitLabel: AppStrings.t(
        context.watch<AppSettingsController>().language,
        'table.fit',
      ),
      child: designCanvas,
    );
  }
}

/// One spread slot on the overview canvas: a subtle hairline placeholder
/// (with its role) while empty; once dealt, the card MATERIALIZES directly
/// inside the slot — a short fade-in 0→1 + scale 0.88→1.0 with an
/// elemental rim shimmer (no flying overlay card). Tapping a face-down
/// card reveals it; a face-up card opens the lightbox.
class _OverviewSlot extends StatefulWidget {
  const _OverviewSlot({required this.slot, required this.slotIndex});

  final DealtCardSlot slot;
  final int slotIndex;

  @override
  State<_OverviewSlot> createState() => _OverviewSlotState();
}

class _OverviewSlotState extends State<_OverviewSlot>
    with SingleTickerProviderStateMixin {
  /// Materialization entrance; starts completed when the view opens with
  /// already-dealt cards (no replay).
  late final AnimationController _entrance;
  late bool _occupied;

  @override
  void initState() {
    super.initState();
    _occupied = widget.slot.card != null;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: _occupied ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _OverviewSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_occupied && widget.slot.card != null) {
      _entrance.forward(from: 0);
    }
    _occupied = widget.slot.card != null;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final card = slot.card;
    if (card == null) {
      final shorts = context.read<SpreadController>().spreadSlotRoleShorts;
      final shortRole = widget.slotIndex < shorts.length
          ? shorts[widget.slotIndex]
          : 'Clarifier';
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(deckWidth * 0.06),
          border: Border.all(color: TaroColors.border),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Text(
          '${widget.slotIndex + 1} · $shortRole',
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.8,
            color: TaroColors.textSecondary.withValues(alpha: 0.65),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _entrance,
      child: SlottedDivinationCard(
        slot: slot,
        width: deckWidth,
        height: deckHeight,
        onFlip: () => context.read<SpreadController>().flipSlot(slot.index),
        onTapFaceUp: () =>
            ReadingBottomSheet.show(context, cardIndex: slot.index),
      ),
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_entrance.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: v,
              child: Transform.scale(scale: 0.88 + 0.12 * v, child: child),
            ),
            // Elemental rim shimmer fading out as the card settles.
            if (v < 1)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(deckWidth * 0.06),
                    border: Border.all(
                      color: card.element.accent.withValues(
                        alpha: (1 - v) * 0.85,
                      ),
                      width: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
