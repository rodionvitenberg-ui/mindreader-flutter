import 'package:flutter/material.dart' hide Element;
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/deck_pack_controller.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';

/// Interactive inspector for one piece of ANY divination system (Phase G5:
/// migrated to [TaroGlassSheet] + [TaroGlassPanel] + [TaroGlassSegmentedControl]).
class CardDetailSheet extends StatefulWidget {
  const CardDetailSheet({super.key, required this.card});

  final DivinationCard card;

  static Future<void> show(BuildContext context, DivinationCard card) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => CardDetailSheet(card: card),
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
    final reverseLabel = isRune ? 'MERKSTAVE' : 'REVERSED';

    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${card.shortLabel} · ${card.categoryLabel}',
                      maxLines: 2,
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
              const SizedBox(width: 12),
              TaroGlassPill(
                label: '${card.element.label.toUpperCase()} ${card.element.glyph}',
                accentColor: card.element.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                duration: Duration(milliseconds: _dragging ? 0 : 420),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX(_tilt.dy * 0.01)
                  ..rotateY(_tilt.dx * 0.015),
                child: _Preview(card: card),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_canReverse)
            TaroGlassSegmentedControl<bool>(
              segments: [
                const TaroGlassSegment<bool>(value: false, label: 'UPRIGHT'),
                TaroGlassSegment<bool>(value: true, label: reverseLabel),
              ],
              value: _reversed,
              onChanged: (v) => setState(() => _reversed = v),
            )
          else
            const TaroGlassChip(label: 'UPRIGHT', selected: true, expanded: true),
          const SizedBox(height: 14),
          TaroGlassPanel(
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
                  'KEYWORDS',
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 1.1,
                    color: TaroColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  card.keywords.map((k) => k.toUpperCase()).join(' · '),
                  style: AppTypography.label(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: TaroColors.lavender,
                  ),
                ),
                if (isLenormand) ...[
                  const SizedBox(height: 14),
                  Text(
                    'COMBINATIONS',
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final combo
                      in (card as LenormandDivinationCard).card.combinations)
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
                    'LORE',
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
                  'THE QUESTION TO SIT WITH',
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
        ],
      ),
    );
  }
}

/// The tiltable preview — each system renders its own artifact (non-glass).
class _Preview extends StatelessWidget {
  const _Preview({required this.card});

  final DivinationCard card;

  @override
  Widget build(BuildContext context) {
    return switch (card.system) {
      DivinationSystem.tarot => TarotCard3DWidget(
          card: (card as TarotDivinationCard).card,
          isReversed: false,
          state: SlotState.faceUp,
          width: 170,
          height: 283,
          tilt: false,
          interactive: false,
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
      DivinationSystem.runes => SizedBox(
          width: 170,
          height: 200,
          child: CustomPaint(
            painter: RuneStonePainter(
              stone: (card as RuneDivinationCard).stone,
              pack: context.watch<DeckPackController>().activeRunePack,
              faceUp: true,
              ignite: 1,
              seed: card.id + 9,
            ),
          ),
        ),
    };
  }
}
