import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/data/deck_packs_registry.dart';
import '../../../core/data/lenormand_data.dart';
import '../../../core/data/runes_data.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/deck_pack.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../state/app_settings_controller.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_pack.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import '../../almanac/deck_cover_picker.dart';
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
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    final pack = context.read<DeckPackController>().activeFor(widget.system);
    _page = PageController(
      initialPage: packsFor(widget.system).indexOf(pack),
      viewportFraction: 0.62,
    );
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DeckPackController>();
    final active = ctrl.activeFor(widget.system);
    final packs = packsFor(widget.system);
    final language = context.watch<AppSettingsController>().language;
    final title = AppStrings.t(
      language,
      'almanac.picker.${widget.system.name}',
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xEB13131A),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: PageView.builder(
                    controller: _page,
                    itemCount: packs.length,
                    itemBuilder: (context, i) => _PackTile(
                      pack: packs[i],
                      selected: active == packs[i],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.read<SpreadController>().setSystem(
                          widget.system,
                        );
                        if (active == packs[i]) {
                          Navigator.pop(context);
                          return;
                        }
                        switch (widget.system) {
                          case DivinationSystem.tarot:
                            ctrl.setActivePack(packs[i].id);
                          case DivinationSystem.lenormand:
                            ctrl.setActiveLenormandPack(packs[i].id);
                          case DivinationSystem.runes:
                            ctrl.setActiveRunePack(packs[i].id);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DeckCoverPicker(system: widget.system),
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
  const _PackTile({
    required this.pack,
    required this.selected,
    required this.onTap,
  });
  final DeckPack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pack = this.pack;
    final Widget preview;
    if (pack is TarotDeckPack) {
      preview = CardBack(
        width: 150,
        height: 245,
        pack: pack,
        angleY: 0.22,
        angleX: 0.10,
        glint: true,
      );
    } else if (pack is LenormandPack) {
      preview = LenormandCard3DWidget(
        card: lenormandDeck[0],
        previewPack: pack,
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
          pack: pack as RunePack,
          faceUp: true,
          ignite: 1,
          seed: 3,
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
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
              child: FittedBox(fit: BoxFit.scaleDown, child: preview),
            ),
            const SizedBox(height: 4),
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
