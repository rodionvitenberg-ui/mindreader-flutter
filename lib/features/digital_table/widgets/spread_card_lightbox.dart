import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/deck_pack_controller.dart';
import 'reading_bottom_sheet.dart';
import 'shuffle_physics.dart' show deckWidth, deckHeight;
import 'slotted_divination_card.dart';

/// Zooms from the tapped card's current screen position. The table camera
/// stays in place underneath, including when the route is dismissed by Back.
Future<void> showSpreadCardLightbox(
  BuildContext context,
  DealtCardSlot slot,
) async {
  if (slot.state != SlotState.faceUp) return;
  final box = context.findRenderObject()! as RenderBox;
  final center = box.localToGlobal(box.size.center(Offset.zero));
  final packs = context.read<DeckPackController>();
  final lang = context.read<AppSettingsController>().language;
  final details = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 230),
    pageBuilder: (context, _, _) => ChangeNotifierProvider.value(
      value: packs,
      child: _CardLightbox(slot: slot, lang: lang),
    ),
    transitionBuilder: (context, animation, _, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      final screenCenter = MediaQuery.sizeOf(context).center(Offset.zero);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: (center - screenCenter) * (1 - t),
          child: Transform.scale(scale: 0.35 + 0.65 * t, child: child),
        ),
      );
    },
  );
  if (details == true && context.mounted) {
    ReadingBottomSheet.show(context, cardIndex: slot.index);
  }
}

class _CardLightbox extends StatefulWidget {
  const _CardLightbox({required this.slot, required this.lang});

  final DealtCardSlot slot;
  final AppLanguage lang;

  @override
  State<_CardLightbox> createState() => _CardLightboxState();
}

class _CardLightboxState extends State<_CardLightbox> {
  double _dismissDistance = 0;
  static void _ignoreTap() {}

  @override
  Widget build(BuildContext context) {
    final close = Navigator.of(context).pop;
    final slot = widget.slot;
    final lang = widget.lang;
    final card = slot.card!;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slot.index + 1} · ${slot.role}',
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  card.name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  meaningFor(slot),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => close(true),
          icon: const Icon(Icons.edit_note),
          label: Text(AppStrings.t(lang, 'table.cardNotes')),
        ),
      ],
    );
    return SafeArea(
      minimum: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxHeight < 440 && c.maxWidth > c.maxHeight;
          final w = math.min(c.maxWidth, wide ? 550.0 : 350.0);
          final h = math.min(c.maxHeight, wide ? 345.0 : 580.0);
          final cardW = math.min(
            w * (wide ? 0.36 : 0.66),
            h * (wide ? 0.85 : 0.60) * deckWidth / deckHeight,
          );
          final art = SizedBox(
            width: cardW,
            height: cardW * deckHeight / deckWidth,
            child: IgnorePointer(
              child: SlottedDivinationCard(
                slot: slot,
                width: cardW,
                height: cardW * deckHeight / deckWidth,
                tilt: false,
                interactive: false,
                onFlip: _ignoreTap,
                onTapFaceUp: _ignoreTap,
              ),
            ),
          );
          return Center(
            child: GestureDetector(
              onVerticalDragStart: (_) => _dismissDistance = 0,
              onVerticalDragUpdate: (event) =>
                  _dismissDistance += event.primaryDelta ?? 0,
              onVerticalDragEnd: (event) {
                if (_dismissDistance > 64 || (event.primaryVelocity ?? 0) > 300) {
                  close();
                }
              },
              child: Material(
                key: const ValueKey('spread-card-lightbox'),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            wide ? 14 : 20,
                            18,
                            12,
                          ),
                          child: wide
                              ? Row(
                                  children: [
                                    art,
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 20),
                                        child: details,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    art,
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: details,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          onPressed: () => close(),
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
