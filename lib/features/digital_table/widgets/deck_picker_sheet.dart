import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/data/deck_packs_registry.dart';
import '../../../core/data/lenormand_data.dart';
import '../../../core/data/lenormand_packs_registry.dart';
import '../../../core/data/rune_packs_registry.dart';
import '../../../core/data/runes_data.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_pack.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/deck_pack_controller.dart';
import 'lenormand_card_3d_widget.dart';
import 'rune_stone_3d_widget.dart';
import 'tarot_card_3d_widget.dart';

/// Horizontal 3D carousel bottom sheet: preview and switch between the
/// registered packs of ONE divination system — filtered strictly by
/// [system] (Tarot decks, Lenormand packs or Rune stone sets). The
/// selection persists via [DeckPackController] / SharedPreferences.
class DeckPickerSheet extends StatefulWidget {
  const DeckPickerSheet({super.key, required this.system});

  final DivinationSystem system;

  static Future<void> show(
    BuildContext context, {
    DivinationSystem system = DivinationSystem.tarot,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => DeckPickerSheet(system: system),
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
    final (title, subtitle, tiles, activeName) = switch (widget.system) {
      DivinationSystem.tarot => (
          'DECK SELECTOR',
          '${deckPacksRegistry.length} PACKS · ACTIVE: '
              '${ctrl.activePack.name.toUpperCase()}',
          [
            for (final p in deckPacksRegistry)
              _PackTile.tarot(p, ctrl.activePack.id == p.id),
          ],
          ctrl.activePack.name.toUpperCase(),
        ),
      DivinationSystem.lenormand => (
          'LENORMAND PACKS',
          '${lenormandPacksRegistry.length} PACKS · ACTIVE: '
              '${ctrl.activeLenormandPack.name.toUpperCase()}',
          [
            for (final p in lenormandPacksRegistry)
              _PackTile.lenormand(p, ctrl.activeLenormandPack.id == p.id),
          ],
          ctrl.activeLenormandPack.name.toUpperCase(),
        ),
      DivinationSystem.runes => (
          'RUNE STONE SETS',
          '${runePacksRegistry.length} SETS · ACTIVE: '
              '${ctrl.activeRunePack.name.toUpperCase()}',
          [
            for (final p in runePacksRegistry)
              _PackTile.rune(p, ctrl.activeRunePack.id == p.id),
          ],
          ctrl.activeRunePack.name.toUpperCase(),
        ),
    };
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
                Text(title, style: Theme.of(context).textTheme.displayMedium),
                Text(
                  subtitle,
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
                    itemCount: tiles.length,
                    itemBuilder: (context, i) => tiles[i],
                  ),
                ),
                const SizedBox(height: 14),
                _PrimaryAction(
                  label: 'USE $activeName',
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

/// One carousel tile — tarot card back, Lenormand engraved face or a
/// carved rune stone, selected by the pack of the active system.
class _PackTile extends StatelessWidget {
  const _PackTile.tarot(this.pack, this.selected) : lenormand = null, rune = null;
  const _PackTile.lenormand(this.lenormand, this.selected)
      : pack = null,
        rune = null;
  const _PackTile.rune(this.rune, this.selected)
      : pack = null,
        lenormand = null;

  final TarotDeckPack? pack;
  final LenormandPack? lenormand;
  final RunePack? rune;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final name = pack?.name ?? lenormand?.name ?? rune!.name;
    final subtitle = pack?.subtitle ?? lenormand?.subtitle ?? rune!.subtitle;
    final license = pack?.license ?? lenormand?.license ?? rune!.license;
    final Widget preview;
    if (pack != null) {
      preview = CardBack(
        width: 150,
        height: 245,
        pack: pack,
        angleY: 0.22,
        angleX: 0.10,
        glint: true,
      );
    } else if (lenormand != null) {
      preview = LenormandCard3DWidget(
        card: lenormandDeck[0],
        isReversed: false,
        state: SlotState.faceUp,
        width: 150,
        height: 245,
        tilt: false,
        interactive: false,
      );
    } else {
      preview = CustomPaint(
        size: const Size(150, 178),
        painter: RuneStonePainter(
          stone: elderFuthark[0],
          pack: rune!,
          faceUp: true,
          ignite: 1,
          seed: 3,
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (pack != null) {
          context.read<DeckPackController>().setActivePack(pack!.id);
        } else if (lenormand != null) {
          context.read<DeckPackController>().setActiveLenormandPack(lenormand!.id);
        } else {
          context.read<DeckPackController>().setActiveRunePack(rune!.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lavender.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: preview,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name.toUpperCase(),
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
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
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
              license.toUpperCase(),
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
