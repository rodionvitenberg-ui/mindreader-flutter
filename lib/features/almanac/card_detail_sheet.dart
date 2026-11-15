import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';

/// Interactive 3D tiltable card inspector: upright vs reversed meanings,
/// archetype keywords, element badge, Socratic question.
class CardDetailSheet extends StatefulWidget {
  const CardDetailSheet({super.key, required this.card});

  final TarotCard card;

  static Future<void> show(BuildContext context, TarotCard card) {
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

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
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
                              '${card.positionLabel} \u00b7 ${card.arcana == Arcana.major ? 'MAJOR ARCANA' : card.suit!.label.toUpperCase()}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final k in card.keywords)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface
                                          .withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      k.toLowerCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: card.element.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: card.element.accent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              card.element.glyph,
                              style: TextStyle(
                                fontSize: 20,
                                color: card.element.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.element.label.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8,
                                letterSpacing: 1.2,
                                color: card.element.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() {
                        _dragging = true;
                        _tilt += Offset(d.delta.dx, d.delta.dy);
                      }),
                      onPanEnd: (_) => setState(() {
                        _dragging = false;
                        _tilt = Offset.zero;
                      }),
                      child: TweenAnimationBuilder<Offset>(
                        tween: Tween(end: _tilt),
                        duration: _dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        builder: (context, value, _) => Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, perspectiveEntry)
                            ..rotateX(value.dy * 0.004)
                            ..rotateY(value.dx * 0.004),
                          child: TarotCard3DWidget(
                            card: card,
                            isReversed: _reversed,
                            state: SlotState.faceUp,
                            width: 170,
                            height: 283,
                            tilt: false,
                          ),
                        ),
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
                      const SizedBox(width: 8),
                      _MeaningToggle(
                        label: 'REVERSED',
                        active: _reversed,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _reversed = true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _reversed ? card.reversed : card.upright,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'THE QUESTION TO SIT WITH',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.socratic,
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
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              letterSpacing: 1.6,
              color: active ? AppColors.lavender : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
