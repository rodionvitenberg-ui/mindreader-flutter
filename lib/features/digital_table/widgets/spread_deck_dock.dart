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

/// Fixed frosted surface shared by the mode switch and the horizontal deck.
class SpreadDeckDock extends StatelessWidget {
  const SpreadDeckDock({
    super.key,
    required this.header,
    required this.badge,
    required this.wrapDeck,
    required this.topKey,
    required this.lifted,
    this.deckWidthPx,
    this.deckHeightPx,
  });

  final Widget header;
  final Widget badge;
  final Widget Function(Widget) wrapDeck;
  final GlobalKey topKey;
  final bool lifted;

  /// Optional explicit outer size of the horizontal deck stack so its top card
  /// matches the rendered size of cards on the table.
  final double? deckWidthPx;
  final double? deckHeightPx;

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
                  final targetH = deckHeightPx ?? overviewDeckHeight;
                  final targetW = deckWidthPx ?? overviewDeckWidth;
                  final scale = targetH <= 0 || targetW <= 0
                      ? 0.0
                      : math.min(
                          1.0,
                          math.min(
                            (dock.maxHeight - 8).clamp(0.0, double.infinity) /
                                targetH,
                            (dock.maxWidth - 16).clamp(0.0, double.infinity) /
                                targetW,
                          ),
                        );
                  final height = targetH * scale;
                  final width = targetW * scale;
                  final badgeWidth = math.max(
                    0.0,
                    (dock.maxWidth - width) / 2 - 8,
                  );
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: wrapDeck(
                          _OverviewDeck(
                            system: context.watch<SpreadController>().system,
                            topKey: topKey,
                            lifted: lifted,
                            width: width,
                            height: height,
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
    required this.system,
    required this.width,
    required this.height,
    required this.topKey,
    required this.lifted,
  });

  final DivinationSystem system;
  final double width;
  final double height;
  final GlobalKey topKey;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;
    if (h <= 4) return const SizedBox.shrink();
    final label = AppStrings.t(
      context.watch<AppSettingsController>().language,
      'table.deal',
    );
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        key: const ValueKey('overview-deck'),
        width: w + 12,
        height: double.infinity,
        child: Center(
          child: SizedBox(
            width: w,
            height: h,
            child: system == DivinationSystem.runes
                ? const FittedBox(
                    child: SizedBox(
                      width: 76,
                      height: 68,
                      child: _OverviewStonePile(),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final inset in [0.0, 2.0])
                        Positioned(
                          left: inset,
                          top: 4 - inset,
                          right: 4 - inset,
                          bottom: inset,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: TaroColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: TaroColors.lavender.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (lifted)
                        Positioned(
                          left: 2,
                          top: 2,
                          right: 2,
                          bottom: 2,
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: SpreadCardBack(width: h - 4, height: w - 4),
                          ),
                        ),
                      Positioned(
                        left: 4,
                        top: 0,
                        bottom: 4,
                        right: 0,
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Opacity(
                            key: topKey,
                            opacity: lifted ? 0 : 1,
                            child: SpreadCardBack(width: h - 4, height: w - 4),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The exact same back is painted on the dock and on the lifted card.
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
