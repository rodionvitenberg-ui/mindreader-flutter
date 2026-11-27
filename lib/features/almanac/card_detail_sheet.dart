import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/element_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/deck_pack_controller.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import '../../core/l10n/app_strings.dart';

/// Full-screen interactive inspector page for one piece of ANY divination system.
/// Keeps the header and card preview top-anchored so flipping UPRIGHT ↔ REVERSED
/// never shifts the header or card while allowing the reading copy below to scroll.
class CardDetailSheet extends StatefulWidget {
  const CardDetailSheet({super.key, required this.card});

  final DivinationCard card;

  static Future<void> show(BuildContext context, DivinationCard card) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CardDetailSheet(card: card)),
    );
  }

  @override
  State<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<CardDetailSheet> {
  bool _reversed = false;
  bool _dragging = false;
  Offset _tilt = Offset.zero;

  bool get _canReverse => widget.card.reversed != null;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final isRune = card.system == DivinationSystem.runes;
    final isLenormand = card.system == DivinationSystem.lenormand;
    final reverseLabel = isRune
        ? AppStrings.g('common.merkstave')
        : AppStrings.g('common.reversedLabel');

    return Stack(
      children: [
        const Positioned.fill(
          child: TaroDuskBackground(imageAsset: TaroBackgroundAssets.forest),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const BackButton(color: TaroColors.lavender),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${card.shortLabel} · ${card.categoryLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                fontSize: 10,
                                letterSpacing: 1.1,
                                color: TaroColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      TaroGlassLayer(
                        useBackdropGroup: false,
                        child: TaroGlassPill(
                          label: card.element.label.toUpperCase(),
                          leading: ElementIcon(card.element, size: 13),
                          accentColor: card.element.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: GestureDetector(
                            onPanStart: (_) => setState(() => _dragging = true),
                            onPanUpdate: (d) => setState(
                              () => _tilt = Offset(
                                (_tilt.dx + d.delta.dx).clamp(-14.0, 14.0),
                                (_tilt.dy + d.delta.dy).clamp(-10.0, 10.0),
                              ),
                            ),
                            onPanEnd: (_) => setState(() {
                              _dragging = false;
                              _tilt = Offset.zero;
                            }),
                            child: AnimatedContainer(
                              duration: Duration(
                                milliseconds: _dragging ? 0 : 420,
                              ),
                              curve: Curves.easeOutCubic,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0012)
                                ..rotateX(_tilt.dy * 0.01)
                                ..rotateY(_tilt.dx * 0.015),
                              child: _Preview(card: card, reversed: _reversed),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TaroGlassLayer(
                          useBackdropGroup: false,
                          child: _canReverse
                              ? TaroGlassSegmentedControl<bool>(
                                  segments: [
                                    TaroGlassSegment<bool>(
                                      value: false,
                                      label: AppStrings.g('common.uprightLabel'),
                                    ),
                                    TaroGlassSegment<bool>(
                                      value: true,
                                      label: reverseLabel,
                                    ),
                                  ],
                                  value: _reversed,
                                  onChanged: (v) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _reversed = v);
                                  },
                                )
                              : TaroGlassChip(
                                  label: AppStrings.g('common.uprightLabel'),
                                  selected: true,
                                  expanded: true,
                                ),
                        ),
                        const SizedBox(height: 14),
                        TaroGlassLayer(
                          useBackdropGroup: false,
                          child: TaroGlassPanel(
                            radius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _reversed && card.reversed != null
                                      ? card.reversed!
                                      : card.upright,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: TaroColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  AppStrings.g('common.keywords'),
                                  style: AppTypography.label(
                                    fontSize: 9,
                                    letterSpacing: 1.1,
                                    color: TaroColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  card.keywords
                                      .map((k) => k.toUpperCase())
                                      .join(' · '),
                                  style: AppTypography.label(
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                    color: TaroColors.lavender,
                                  ),
                                ),
                                if (isLenormand) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    AppStrings.g('common.combinations'),
                                    style: AppTypography.label(
                                      fontSize: 9,
                                      letterSpacing: 1.1,
                                      color: TaroColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final combo
                                      in (card as LenormandDivinationCard)
                                          .card
                                          .combinations)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '· $combo',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          height: 1.45,
                                          color: TaroColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                                if (isRune) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    AppStrings.g('common.lore'),
                                    style: AppTypography.label(
                                      fontSize: 9,
                                      letterSpacing: 1.1,
                                      color: TaroColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (card as RuneDivinationCard).stone.lore,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                      color: TaroColors.textPrimary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Text(
                                  AppStrings.g(
                                    'ui.card_detail_sheet.the_question_to_sit_with',
                                  ),
                                  style: AppTypography.label(
                                    fontSize: 9,
                                    letterSpacing: 1.1,
                                    color: TaroColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  card.reflection,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                    color: TaroColors.dawn,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The tiltable preview — each system renders its own artifact (non-glass).
/// Switching UPRIGHT ↔ REVERSED / MERKSTAVE smoothly rotates the tarot card
/// (or carved rune glyph inside the volumetric stone) by 180°.
class _Preview extends StatelessWidget {
  const _Preview({required this.card, required this.reversed});

  final DivinationCard card;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    return switch (card.system) {
      DivinationSystem.tarot => TweenAnimationBuilder<double>(
          tween: Tween<double>(end: reversed ? math.pi : 0.0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          builder: (context, angle, child) => Transform.rotate(
            angle: angle,
            child: child,
          ),
          child: TarotCard3DWidget(
            card: (card as TarotDivinationCard).card,
            isReversed: false,
            state: SlotState.faceUp,
            width: 170,
            height: 283,
            tilt: false,
            interactive: false,
          ),
        ),
      DivinationSystem.lenormand => LenormandCard3DWidget(
          card: (card as LenormandDivinationCard).card,
          isReversed: false,
          state: SlotState.faceUp,
          width: 170,
          height: 283,
          tilt: false,
          interactive: false,
        ),
      DivinationSystem.runes => TweenAnimationBuilder<double>(
          tween: Tween<double>(end: reversed ? math.pi : 0.0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          builder: (context, angle, _) {
            final lift = math.sin(angle).abs();
            return Transform.scale(
              scale: 1.0 + 0.035 * lift,
              child: SizedBox(
                width: 176,
                height: 206,
                child: RuneStoneView(
                  stone: (card as RuneDivinationCard).stone,
                  pack: context.watch<DeckPackController>().activeRunePack,
                  faceUp: true,
                  ignite: 1,
                  merkstave: reversed,
                  glyphRotation: angle,
                  lift: lift * 0.5,
                  seed: card.id + 9,
                ),
              ),
            );
          },
        ),
    };
  }
}
