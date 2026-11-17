import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/data/deck_packs_registry.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/deck_pack_controller.dart';
import 'tarot_card_3d_widget.dart';

/// Horizontal 3D carousel bottom sheet: preview and switch between all
/// registered deck packs on the fly. The selection persists via
/// [DeckPackController] / SharedPreferences.
class DeckPickerSheet extends StatefulWidget {
  const DeckPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const DeckPickerSheet(),
    );
  }

  @override
  State<DeckPickerSheet> createState() => _DeckPickerSheetState();
}

class _DeckPickerSheetState extends State<DeckPickerSheet> {
  late final PageController _page = PageController(viewportFraction: 0.62);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DeckPackController>();
    final active = ctrl.activePack;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xEB13131A),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'DECK SELECTOR',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Text(
                  '${deckPacksRegistry.length} PACKS · ACTIVE: '
                  '${active.name.toUpperCase()}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: PageView.builder(
                    controller: _page,
                    itemCount: deckPacksRegistry.length,
                    itemBuilder: (context, i) =>
                        _DeckCarouselTile(pack: deckPacksRegistry[i]),
                  ),
                ),
                const SizedBox(height: 14),
                _PrimaryAction(
                  label: 'USE ${active.name.toUpperCase()}',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One carousel tile: 3D-tilted procedural back of the pack + metadata.
class _DeckCarouselTile extends StatelessWidget {
  const _DeckCarouselTile({required this.pack});

  final TarotDeckPack pack;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DeckPackController>();
    final selected = ctrl.activePack.id == pack.id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<DeckPackController>().setActivePack(pack.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: selected ? 0.95 : 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(0.22)
                    ..rotateX(0.06),
                  child: CardBack(
                    width: 110,
                    height: 180,
                    pack: pack,
                    glint: true,
                    angleY: 0.22,
                    angleX: 0.06,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    pack.name.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.lavender
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (pack.isPro) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7.5,
                        letterSpacing: 1.2,
                        color: AppColors.lavender,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              pack.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.3,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pack.license.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 6.5,
                letterSpacing: 1,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}

