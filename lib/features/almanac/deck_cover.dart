import 'package:flutter/material.dart';

import '../../core/data/lenormand_data.dart';
import '../../core/data/runes_data.dart';
import '../../core/data/tarot_deck_data.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/deck_pack.dart';
import '../../core/models/lenormand_pack.dart';
import '../../core/models/rune_pack.dart';
import '../../core/models/tarot_deck_pack.dart';
import '../../design_system/taro_tokens.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';

/// Renders the backend-managed promo artwork for a deck or rune set inside the
/// collapsible Almanac banner and digital shop cards. Falls back gracefully to
/// a local face-up composition (Tarot's The Star, Lenormand's face, or carved
/// rune stone) until a promo image is assigned on the backend or while offline.
class DeckCover extends StatelessWidget {
  const DeckCover({super.key, required this.pack, this.promoUrl});

  final DeckPack pack;

  /// Absolute URL returned by the backend (`/api/v1/store/promos/`).
  final String? promoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = _LocalFallbackPreview(pack: pack);
    final url = promoUrl;
    return ClipRect(
      child: SizedBox.expand(
        child: url != null && url.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  fallback,
                  Image.network(
                    url,
                    key: ValueKey('deck-promo-image-${pack.id}'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ],
              )
            : fallback,
      ),
    );
  }
}

class _LocalFallbackPreview extends StatelessWidget {
  const _LocalFallbackPreview({required this.pack});

  final DeckPack pack;

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
          stone: elderFuthark[0],
          faceUp: true,
          ignite: 1,
          seed: 5,
        ),
      );
    } else if (p is LenormandPack) {
      accent = Color(p.faceAccentArgb);
      piece = LenormandCard3DWidget(
        card: lenormandDeck[0],
        previewPack: p,
        isReversed: false,
        state: SlotState.faceUp,
        width: 120,
        height: 190,
        tilt: false,
        interactive: false,
      );
    } else {
      final tarot = p as TarotDeckPack;
      accent = Color(tarot.faceAccentArgb);
      piece = TarotCard3DWidget(
        card: tarotDeck[17], // XVII · The Star
        previewPack: tarot,
        isReversed: false,
        state: SlotState.faceUp,
        width: 120,
        height: 190,
        tilt: false,
        interactive: false,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TaroColors.surface,
            Color.lerp(TaroColors.surface, accent, 0.34)!,
          ],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.55, 0),
        child: FractionallySizedBox(
          heightFactor: 1.4,
          child: Transform.rotate(
            angle: -0.14,
            child: FittedBox(child: piece),
          ),
        ),
      ),
    );
  }
}
