import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/runes_data.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/divination_system.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import '../../profile/widgets/profile_header.dart';
import 'rune_stone_3d_widget.dart';
import 'shuffle_physics.dart';
import 'tarot_card_3d_widget.dart';

const overviewStackExtent = 20.0;

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

/// Fixed frosted surface shared by the mode switch and the horizontal deck.
class SpreadDeckDock extends StatelessWidget {
  const SpreadDeckDock({
    super.key,
    required this.header,
    required this.badge,
    required this.wrapDeck,
    required this.topKey,
    required this.held,
    this.cardLongPx,
    this.cardShortPx,
  });

  final Widget header;
  final Widget badge;
  final Widget Function(Widget) wrapDeck;
  final GlobalKey topKey;
  final bool held;

  /// Rendered dimensions of the horizontal top card in the dock (matched 1:1
  /// to a card on the spread board: `deckHeight * fit` × `deckWidth * fit`).
  final double? cardLongPx;
  final double? cardShortPx;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: TaroColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            SizedBox(
              height: math.min(constraints.maxHeight, ProfileHeader.actionSize),
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
        ),
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
  });

  final double cardWidth;
  final double cardHeight;
  final double stepX;
  final double stepY;
  final GlobalKey topKey;
  final bool held;

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
            ? const FittedBox(
                child: SizedBox(
                  width: 76,
                  height: 68,
                  child: _OverviewStonePile(),
                ),
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

/// The mini stone pile shown in the overview deck corner for RUNES — a
/// small heap of face-down stones instead of a paper card deck.
class _OverviewStonePile extends StatelessWidget {
  const _OverviewStonePile();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Positioned(
            left: 4.0 + i * 5,
            top: 10.0 - i * 4,
            child: CustomPaint(
              size: const Size(48, 57),
              painter: RuneStonePainter(
                stone: elderFuthark[0],
                pack: context.watch<DeckPackController>().activeRunePack,
                faceUp: false,
                ignite: 0,
                seed: 21 + i,
              ),
            ),
          ),
      ],
    );
  }
}
