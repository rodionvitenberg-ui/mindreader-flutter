import 'package:flutter/material.dart';

import '../../core/data/runes_data.dart';
import '../../core/models/deck_pack.dart';
import '../../core/models/lenormand_pack.dart';
import '../../core/models/rune_pack.dart';
import '../../core/models/tarot_deck_pack.dart';
import '../../core/theme/app_colors.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';

/// Until a pack ships landscape artwork, offer three compositions from its
/// existing illustrations or engraved pieces. The stored selection is a
/// stable asset path (or preview name), independent of the picker's order.
List<String> deckCovers(DeckPack pack) => pack.coverAssets.isEmpty
    ? const ['preview-1', 'preview-2', 'preview-3']
    : pack.coverAssets;

class DeckCover extends StatelessWidget {
  const DeckCover({super.key, required this.pack, this.choice});

  final DeckPack pack;
  final String? choice;

  @override
  Widget build(BuildContext context) {
    final options = deckCovers(pack);
    final selected = options.contains(choice) ? choice! : options.first;
    final index = options.indexOf(selected);
    final fallback = _Preview(pack: pack, index: index % 3);
    return ClipRect(
      child: SizedBox.expand(
        child: pack.coverAssets.isEmpty
            ? fallback
            : Image.asset(
                selected,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.pack, required this.index});
  final DeckPack pack;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = pack;
    final Color accent;
    final Widget piece;
    if (p is RunePack) {
      accent = Color(p.stoneRimArgb);
      piece = CustomPaint(
        size: const Size(120, 150),
        painter: RuneStonePainter(
          pack: p,
          stone: elderFuthark[[0, 7, 18][index]],
          faceUp: true,
          ignite: 1,
          seed: index + 5,
        ),
      );
    } else if (p is LenormandPack) {
      accent = Color(p.faceAccentArgb);
      piece = CardBack(
        width: 120,
        height: 190,
        styleOverride: p.backStyle,
        accentOverride: p.backAccentArgb,
        secondaryOverride: p.backSecondaryArgb,
      );
    } else {
      final tarot = p as TarotDeckPack;
      accent = Color(tarot.faceAccentArgb);
      final back = CardBack(width: 120, height: 190, pack: tarot);
      piece = tarot.isIllustrated
          ? Image.asset(
              '${tarot.assetFolder}${['02', '17', '19'][index]}.jpg',
              width: 120,
              height: 190,
              fit: BoxFit.cover,
              cacheWidth: 480,
              errorBuilder: (_, _, _) => back,
            )
          : back;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            Color.lerp(AppColors.surface, accent, 0.34)!,
          ],
        ),
      ),
      child: Align(
        alignment: [
          const Alignment(0.6, 0),
          Alignment.center,
          const Alignment(-0.55, 0),
        ][index],
        child: FractionallySizedBox(
          heightFactor: 1.45,
          child: Transform.rotate(
            angle: [-0.18, 0.08, 0.2][index],
            child: FittedBox(child: piece),
          ),
        ),
      ),
    );
  }
}
