import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/deck_pack_controller.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';

/// Interactive inspector for one piece of ANY divination system: upright
/// vs reversed/merkstave meanings, keywords, element badge, the reflection
/// question and (Lenormand) the combinatory pair readings.
class CardDetailSheet extends StatefulWidget {
  const CardDetailSheet({super.key, required this.card});

  final DivinationCard card;

  static Future<void> show(BuildContext context, DivinationCard card) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xEB13131A),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.name,
                              style:
                                  Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${card.shortLabel} · ${card.categoryLabel}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                fontSize: 10,
                                letterSpacing: 1.1,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              card.element.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  card.element.accent.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          '${card.element.label.toUpperCase()} '
                          '${card.element.glyph}',
                          style: AppTypography.label(
                            fontSize: 10,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w700,
                            color: card.element.accent,
                          ),
                        ),
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
                        duration: Duration(
                            milliseconds: _dragging ? 0 : 420),
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
                  Row(
                    children: [
                      _MeaningToggle(
                        label: 'UPRIGHT',
                        active: !_reversed,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _reversed = false);
                        },
                      ),
                      if (_canReverse) ...[
                        const SizedBox(width: 8),
                        _MeaningToggle(
                          label: reverseLabel,
                          active: _reversed,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _reversed = true);
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _reversed && card.reversed != null
                        ? card.reversed!
                        : card.upright,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'KEYWORDS',
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.keywords.map((k) => k.toUpperCase()).join(' · '),
                    style: AppTypography.label(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: AppColors.lavender,
                    ),
                  ),
                  if (isLenormand) ...[
                    const SizedBox(height: 18),
                    Text(
                      'COMBINATIONS',
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: AppColors.textMuted,
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                  if (isRune) ...[
                    const SizedBox(height: 18),
                    Text(
                      'LORE',
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (card as RuneDivinationCard).stone.lore,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'THE QUESTION TO SIT WITH',
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.reflection,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: AppColors.lavender,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tiltable preview — each system renders its own artifact.
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

class _MeaningToggle extends StatelessWidget {
  const _MeaningToggle({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.lavender.withValues(alpha: 0.16)
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.lavender : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label(
              fontSize: 10,
              letterSpacing: 0.9,
              color: active ? AppColors.lavender : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
