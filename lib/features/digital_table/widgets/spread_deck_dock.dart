import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/runes_data.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/divination_card.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/rune_stone.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import '../../profile/widgets/profile_header.dart';
import 'rune_stone_3d_widget.dart';
import 'shuffle_physics.dart';
import 'tarot_card_3d_widget.dart';

const overviewStackExtent = 20.0;

/// Maximum visible stones rendered simultaneously in the SPREAD VIEW
/// horizontal stone heap. The pile visibly depletes as remaining drops below 12.
const overviewRuneHeapCap = 12;

/// Computes the 3D stepped card-edge metrics for the horizontal deck stack in
/// `SPREAD VIEW` from the top card's short side (`deckWidth * fit`).
({double stepX, double stepY, double depthX, double depthY})
overviewStackMetrics(double cardShort) {
  final stepY = (cardShort * 0.0115).clamp(0.75, 1.15);
  final stepX = (cardShort * 0.0055).clamp(0.35, 0.58);
  const maxUnderlying = fanLayerCount - 1;
  return (
    stepX: stepX,
    stepY: stepY,
    depthX: stepX * maxUnderlying,
    depthY: stepY * maxUnderlying,
  );
}

/// Fixed frosted surface shared by the mode switch and the horizontal deck
/// (or volumetric horizontal stone heap for RUNES).
class SpreadDeckDock extends StatelessWidget {
  const SpreadDeckDock({
    super.key,
    required this.header,
    required this.badge,
    required this.wrapDeck,
    required this.topKey,
    required this.held,
    this.topInset = 0,
    this.cardLongPx,
    this.cardShortPx,
    this.runeSwirl = 0,
  });

  final Widget header;
  final Widget badge;
  final Widget Function(Widget) wrapDeck;
  final GlobalKey topKey;
  final bool held;
  final double topInset;

  /// Rendered dimensions of the horizontal top card in the dock (matched 1:1
  /// to a card on the spread board: `deckHeight * fit` × `deckWidth * fit`).
  final double? cardLongPx;
  final double? cardShortPx;

  /// Horizontal drag travel driving subtle stone rattle/swirl on the rune heap.
  final double runeSwirl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: TaroColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padTop = math.min(constraints.maxHeight, topInset);
          final remaining = constraints.maxHeight - padTop;
          return Column(
            children: [
              if (padTop > 0) SizedBox(height: padTop),
              SizedBox(
                height: math.min(remaining, ProfileHeader.actionSize),
                child: header,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, dock) {
                    final targetCardW = cardLongPx ?? overviewDeckWidth;
                    final targetCardH = cardShortPx ?? overviewDeckHeight;
                    final rawMetrics = overviewStackMetrics(targetCardH);
                    final targetTotalW = targetCardW + rawMetrics.depthX * 2;
                    final targetTotalH = targetCardH + rawMetrics.depthY;
                    final scale = targetTotalH <= 0 || targetTotalW <= 0
                        ? 0.0
                        : math.min(
                            1.0,
                            math.min(
                              (dock.maxHeight - 8).clamp(0.0, double.infinity) /
                                  targetTotalH,
                              (dock.maxWidth - 16).clamp(0.0, double.infinity) /
                                  targetTotalW,
                            ),
                          );
                    final cardW = targetCardW * scale;
                    final cardH = targetCardH * scale;
                    final stepX = rawMetrics.stepX * scale;
                    final stepY = rawMetrics.stepY * scale;
                    final depthX = rawMetrics.depthX * scale;
                    final depthY = rawMetrics.depthY * scale;
                    final badgeWidth = math.max(
                      0.0,
                      (dock.maxWidth - (cardW + depthX * 2)) / 2 - 8,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: wrapDeck(
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                depthX,
                                2,
                                depthX,
                                depthY + 2,
                              ),
                              child: _OverviewDeck(
                                topKey: topKey,
                                held: held,
                                cardWidth: cardW,
                                cardHeight: cardH,
                                stepX: stepX,
                                stepY: stepY,
                                runeSwirl: runeSwirl,
                              ),
                            ),
                          ),
                        ),
                        if (badgeWidth > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: badgeWidth,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: badge,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewDeck extends StatelessWidget {
  const _OverviewDeck({
    required this.cardWidth,
    required this.cardHeight,
    required this.stepX,
    required this.stepY,
    required this.topKey,
    required this.held,
    required this.runeSwirl,
  });

  final double cardWidth;
  final double cardHeight;
  final double stepX;
  final double stepY;
  final GlobalKey topKey;
  final bool held;
  final double runeSwirl;

  @override
  Widget build(BuildContext context) {
    final w = cardWidth;
    final h = cardHeight;
    final ctrl = context.watch<SpreadController>();
    final stackCount = math.max(
      0,
      math.min(fanLayerCount, ctrl.totalCards) -
          (ctrl.totalCards - ctrl.remaining) -
          (held ? 1 : 0),
    );
    if (h <= 4 || w <= 4) {
      return const SizedBox.shrink();
    }
    final label = AppStrings.t(
      context.watch<AppSettingsController>().language,
      'table.deal',
    );
    final cornerRadius = (h * 0.06).clamp(3.5, 10.0);
    const maxDepth = fanLayerCount - 1;
    return Semantics(
      button: true,
      label: label,
      value: ctrl.system == DivinationSystem.runes ? null : '$stackCount',
      child: SizedBox(
        key: const ValueKey('overview-deck'),
        width: w,
        height: h,
        child: ctrl.system == DivinationSystem.runes
            ? _OverviewStonePile(
                width: w,
                height: h,
                topKey: topKey,
                held: held,
                swirl: runeSwirl,
              )
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var depth = stackCount - 1; depth > 0; depth--)
                    _buildEdgeCard(
                      depth: depth,
                      isBottom: depth == stackCount - 1,
                      maxDepth: maxDepth,
                      w: w,
                      h: h,
                      cornerRadius: cornerRadius,
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    width: w,
                    height: h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cornerRadius),
                        boxShadow: stackCount > 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.44),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ]
                            : null,
                      ),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Opacity(
                          key: topKey,
                          opacity: stackCount == 0 ? 0 : 1,
                          child: SpreadCardBack(width: h, height: w),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEdgeCard({
    required int depth,
    required bool isBottom,
    required int maxDepth,
    required double w,
    required double h,
    required double cornerRadius,
  }) {
    // 0.0 at bottom of stack -> 1.0 right underneath the top card.
    final t = 1.0 - (depth / math.max(1, maxDepth)).clamp(0.0, 1.0);
    final isLightSheet = depth.isOdd;
    // Subtle deterministic organic offset so individual card corners peek out.
    final jitterX = (((depth * 7) % 5) - 2) * 0.28;
    final jitterY = (((depth * 11) % 3) - 1) * 0.14;
    final fill = Color.lerp(
      const Color(0xFF1A1926),
      isLightSheet ? const Color(0xFF4B4763) : const Color(0xFF333048),
      0.35 + 0.65 * t,
    )!;
    final border = Color.lerp(
      TaroColors.mist.withValues(alpha: 0.28),
      isLightSheet
          ? TaroColors.textPrimary.withValues(alpha: 0.62)
          : TaroColors.lavender.withValues(alpha: 0.50),
      0.30 + 0.70 * t,
    )!;
    return Positioned(
      key: ValueKey('overview-deck-edge-$depth'),
      left: -depth * stepX + jitterX,
      top: depth * stepY + jitterY,
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(cornerRadius),
          border: Border.all(color: border, width: 0.85),
          boxShadow: isBottom
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.52),
                    blurRadius: 10,
                    offset: const Offset(-2, 5),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// The exact same back is painted on the dock and on the held card.
class SpreadCardBack extends StatelessWidget {
  const SpreadCardBack({super.key, required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final packs = context.watch<DeckPackController>();
    final lenormand =
        context.watch<SpreadController>().system == DivinationSystem.lenormand
        ? packs.activeLenormandPack
        : null;
    return CardBack(
      width: width,
      height: height,
      pack: lenormand == null ? packs.activePack : null,
      styleOverride: lenormand?.backStyle,
      accentOverride: lenormand?.backAccentArgb,
      secondaryOverride: lenormand?.backSecondaryArgb,
    );
  }
}

/// Resting pose for one stone in the SPREAD VIEW horizontal oval mound.
class _HeapSlotPose {
  const _HeapSlotPose(this.nx, this.ny, this.rot, this.scale, this.depthShade);

  /// Horizontal offset as a fraction of the dock width (`-0.4..+0.4`).
  final double nx;

  /// Vertical offset as a fraction of the dock height (`-0.18..+0.18`).
  final double ny;
  final double rot;
  final double scale;
  final double depthShade;
}

/// 12 hand-balanced organic resting slots arranged as a compact horizontal
/// mound from deepest back-outer stones (index 0) to the bright top hero
/// stone (index 11) in the foreground center.
const List<_HeapSlotPose> _overviewHeapPoses = [
  // Back / outer perimeter tier (darkest depth occlusion).
  _HeapSlotPose(-0.37, -0.05, -0.34, 0.84, 0.52),
  _HeapSlotPose(0.37, -0.07, 0.30, 0.84, 0.50),
  _HeapSlotPose(-0.23, -0.15, 0.20, 0.87, 0.44),
  _HeapSlotPose(0.23, -0.14, -0.22, 0.87, 0.42),
  _HeapSlotPose(0.01, -0.16, 0.08, 0.88, 0.38),
  // Middle overlapping tier.
  _HeapSlotPose(-0.29, 0.11, 0.24, 0.90, 0.30),
  _HeapSlotPose(0.29, 0.12, -0.26, 0.90, 0.28),
  _HeapSlotPose(-0.14, 0.05, -0.17, 0.94, 0.20),
  _HeapSlotPose(0.15, 0.06, 0.19, 0.94, 0.18),
  // Foreground crown tier.
  _HeapSlotPose(-0.07, 0.12, 0.12, 0.97, 0.10),
  _HeapSlotPose(0.08, -0.03, -0.13, 0.98, 0.05),
  // Top hero stone (anchor for flight & drag-to-cast).
  _HeapSlotPose(0.0, 0.02, -0.05, 1.00, 0.0),
];

/// Living horizontal volumetric stone heap shown in the SPREAD VIEW dock for
/// RUNES:
/// * Displays up to [overviewRuneHeapCap] real shuffled stones from
///   `remainingDeck`, shaded by depth so upper stones visually rest atop lower
///   ones.
/// * Visibly depletes as runes are cast (`12 → 11 → … → 1 → 0`), shrinking
///   gracefully toward the center.
/// * Reacts to horizontal [swirl] drags with damped stone jitter/rattle.
/// * Anchors [topKey] on the top hero stone at exact board scale (`height` =
///   `deckWidth * fit`), so `SpreadBoard` flies stones cleanly from the mound
///   straight into target slots.
class _OverviewStonePile extends StatelessWidget {
  const _OverviewStonePile({
    required this.width,
    required this.height,
    required this.topKey,
    required this.held,
    required this.swirl,
  });

  final double width;
  final double height;
  final GlobalKey topKey;
  final bool held;
  final double swirl;

  RuneStone _stoneAt(List<DivinationCard> remaining, int depth) {
    if (remaining.isEmpty) return elderFuthark[0];
    final card = remaining[depth.clamp(0, remaining.length - 1)];
    return card is RuneDivinationCard ? card.stone : elderFuthark[0];
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final pack = context.watch<DeckPackController>().activeRunePack;
    final remainingCards = ctrl.remainingDeck;
    final totalVisible = math.min(overviewRuneHeapCap, remainingCards.length);
    final drawnCount = math.max(0, totalVisible - (held ? 1 : 0));

    // Match the board's exact rune stone proportions (deckWidth*0.74 × 1.18)
    // where `height` equals `deckWidth * fit`.
    final baseStoneW = height * 0.74;
    final baseStoneH = baseStoneW * 1.18;
    final centerX = width / 2;
    final centerY = height / 2;
    final topPose = _overviewHeapPoses.last;
    final topCenterX = centerX + topPose.nx * width;
    final topCenterY = centerY + topPose.ny * height;

    // Render stones from back (deepest) to front (topmost). As totalVisible
    // shrinks below 12, we drop outer back poses first so the mound stays
    // centered and balanced right down to the final stone.
    final startPoseIdx = overviewRuneHeapCap - totalVisible;
    final underlyingCount = math.max(0, totalVisible - 1);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Subtle ambient grounding pool beneath the stone cluster.
        if (drawnCount > 0)
          Positioned(
            left: width * 0.08,
            top: height * 0.22,
            width: width * 0.84,
            height: height * 0.68,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: (height * 0.22).clamp(6.0, 20.0),
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

        // Underlying heap stones (always drawn beneath the top stone).
        for (var i = 0; i < underlyingCount; i++)
          _buildHeapStone(
            poseIndex: startPoseIdx + i,
            stone: _stoneAt(remainingCards, totalVisible - 1 - i),
            pack: pack,
            centerX: centerX,
            centerY: centerY,
            baseStoneW: baseStoneW,
            baseStoneH: baseStoneH,
          ),

        // Top hero stone anchor: SizedBox(width: height, height: height) gives
        // _DealPose.measure exact `scale = height / deckWidth = fit` and
        // `angle = 0`, launching stone flights directly from the heap crown.
        Positioned(
          left: topCenterX - height / 2,
          top: topCenterY - height / 2,
          width: height,
          height: height,
          child: Opacity(
            key: topKey,
            opacity: drawnCount == 0 || held ? 0 : 1,
            child: Center(
              child: Transform.rotate(
                angle:
                    topPose.rot +
                    (swirl == 0 ? 0 : math.sin(swirl / 18 + 11) * 0.08),
                child: RuneStoneView(
                  key: const ValueKey('overview-rune-top'),
                  stone: _stoneAt(remainingCards, 0),
                  pack: pack,
                  faceUp: false,
                  ignite: 0,
                  seed: 21 + _stoneAt(remainingCards, 0).id,
                  depthShade: 0,
                  width: baseStoneW,
                  height: baseStoneH,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeapStone({
    required int poseIndex,
    required RuneStone stone,
    required RunePack pack,
    required double centerX,
    required double centerY,
    required double baseStoneW,
    required double baseStoneH,
  }) {
    final pose = _overviewHeapPoses[poseIndex.clamp(0, _overviewHeapPoses.length - 1)];
    final phase = poseIndex * 0.85;
    final orbitX = swirl == 0 ? 0.0 : math.sin(swirl / 22 + phase) * 4.5;
    final orbitY = swirl == 0 ? 0.0 : math.cos(swirl / 26 + phase) * 2.5;
    final rotJitter = swirl == 0 ? 0.0 : math.sin(swirl / 18 + phase) * 0.09;

    final sw = baseStoneW * pose.scale;
    final sh = baseStoneH * pose.scale;
    final cx = centerX + pose.nx * width + orbitX;
    final cy = centerY + pose.ny * height + orbitY;

    return Positioned(
      key: ValueKey('overview-rune-stone-$poseIndex'),
      left: cx - sw / 2,
      top: cy - sh / 2,
      width: sw,
      height: sh,
      child: Transform.rotate(
        angle: pose.rot + rotJitter,
        child: RuneStoneView(
          stone: stone,
          pack: pack,
          faceUp: false,
          ignite: 0,
          seed: 21 + stone.id,
          depthShade: pose.depthShade,
          width: sw,
          height: sh,
        ),
      ),
    );
  }
}
