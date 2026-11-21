import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/runes_data.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_colors.dart';
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
    required this.onDeal,
    this.deckWidthPx,
    this.deckHeightPx,
  });

  final Widget header;
  final Widget badge;
  final VoidCallback onDeal;

  /// Optional explicit outer size of the horizontal deck stack so its top card
  /// matches the rendered size of cards on the table.
  final double? deckWidthPx;
  final double? deckHeightPx;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
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
                        child: _OverviewDeck(
                          system: context.watch<SpreadController>().system,
                          pack: context.watch<DeckPackController>().activePack,
                          width: width,
                          height: height,
                          onTap: onDeal,
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

/// Fixed horizontal mini-deck for the Spread Overview mode: tap to
/// deal the next card DIRECTLY into the spread. The deck plays a gentle
/// breathing pulse on every tap while the dealt card materializes in its
/// slot. It stays within reach while the reader moves the board.
class _OverviewDeck extends StatefulWidget {
  const _OverviewDeck({
    required this.system,
    required this.pack,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final DivinationSystem system;
  final TarotDeckPack pack;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_OverviewDeck> createState() => _OverviewDeckState();
}

class _OverviewDeckState extends State<_OverviewDeck>
    with SingleTickerProviderStateMixin {
  /// 420ms soft breathing pulse (1.0 → 1.12 → 1.0) on each tap.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    _pulse.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    if (h <= 4) return const SizedBox.shrink();
    final lenormand = context.watch<DeckPackController>().activeLenormandPack;
    final label = AppStrings.t(
      context.watch<AppSettingsController>().language,
      'table.deal',
    );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: SizedBox(
          key: const ValueKey('overview-deck'),
          width: w + 12,
          height: double.infinity,
          child: Center(
            child: ScaleTransition(
              scale: TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 1, end: 1.05), weight: 1),
                TweenSequenceItem(tween: Tween(begin: 1.05, end: 1), weight: 2),
              ]).animate(_pulse),
              child: SizedBox(
                width: w,
                height: h,
                child: widget.system == DivinationSystem.runes
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
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.lavender.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 4,
                            top: 0,
                            bottom: 4,
                            right: 0,
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: CardBack(
                                width: h - 4,
                                height: w - 4,
                                pack: widget.system == DivinationSystem.tarot
                                    ? widget.pack
                                    : null,
                                styleOverride:
                                    widget.system == DivinationSystem.lenormand
                                    ? lenormand.backStyle
                                    : null,
                                accentOverride:
                                    widget.system == DivinationSystem.lenormand
                                    ? lenormand.backAccentArgb
                                    : null,
                                secondaryOverride:
                                    widget.system == DivinationSystem.lenormand
                                    ? lenormand.backSecondaryArgb
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
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
