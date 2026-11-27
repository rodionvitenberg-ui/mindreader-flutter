import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/lenormand_data.dart';
import '../../../core/data/runes_data.dart';
import '../../../core/data/tarot_deck_data.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/deck_pack.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../state/app_settings_controller.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_pack.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
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
    return showTaroGlassSheet<void>(
      context: context,
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
    final ctrl = context.read<DeckPackController>();
    final pack = ctrl.activeFor(widget.system);
    final idx = ctrl.packsFor(widget.system).indexWhere((p) => p.id == pack.id);
    _page = PageController(
      initialPage: idx < 0 ? 0 : idx,
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
    final packs = ctrl.packsFor(widget.system);
    final language = context.watch<AppSettingsController>().language;
    final title = AppStrings.t(
      language,
      'almanac.picker.${widget.system.name}',
    );
    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }
}

/// One carousel tile — Tarot Star card face, Lenormand engraved face or a
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
      preview = TarotCard3DWidget(
        card: tarotDeck[17], // XVII · The Star
        previewPack: pack,
        isReversed: false,
        state: SlotState.faceUp,
        width: 150,
        height: 245,
        tilt: false,
        interactive: false,
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
      preview = RuneStoneView(
        stone: elderFuthark[0],
        pack: pack as RunePack,
        faceUp: true,
        ignite: 1,
        seed: 3,
        width: 150,
        height: 178,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? TaroColors.lavender.withValues(alpha: 0.16)
              : TaroColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? TaroColors.lavender
                : TaroColors.mist.withValues(alpha: TaroOpacity.border),
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
                    style: AppTypography.label(
                      fontSize: 10,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? TaroColors.lavender
                          : TaroColors.textPrimary,
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
                color: TaroColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
