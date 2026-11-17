import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/lenormand_card.dart';
import '../../../core/models/lenormand_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/deck_pack_controller.dart';
import 'foil_glint.dart';
import 'tarot_card_3d_widget.dart' show CardBack;

/// A single 3D Petit Lenormand card on the table plane: same footprint and
/// reveal choreography as the tarot cards (750ms arcane materialization),
/// but with a bespoke procedural engraved face — number + playing-card
/// inset + title + suit line + keywords. Lenormand NEVER reads reversed,
/// so [isReversed] is accepted for interface symmetry and ignored.
/// Real art may be dropped into `assets/lenormand/<pack>/NN.jpg` — the
/// first asset that loads wins over the procedural face.
class LenormandCard3DWidget extends StatefulWidget {
  const LenormandCard3DWidget({
    super.key,
    required this.card,
    required this.isReversed,
    required this.state,
    required this.width,
    required this.height,
    this.tilt = true,
    this.interactive = true,
    this.onFlip,
    this.onTapFaceUp,
  });

  final LenormandCard card;
  final bool isReversed; // ignored — Lenormand is always upright
  final SlotState state;
  final double width;
  final double height;
  final bool tilt;
  final bool interactive;
  final VoidCallback? onFlip;
  final VoidCallback? onTapFaceUp;

  @override
  State<LenormandCard3DWidget> createState() => _LenormandCard3DWidgetState();
}

class _LenormandCard3DWidgetState extends State<LenormandCard3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    value: widget.state == SlotState.faceUp ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant LenormandCard3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != SlotState.faceUp && widget.state == SlotState.faceUp) {
      HapticFeedback.selectionClick();
      _reveal.forward(from: 0).whenCompleteOrCancel(() {
        widget.onFlip?.call();
      });
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activeLenormandPack;
    final faceUp = widget.state == SlotState.faceUp;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive
          ? () {
              if (faceUp) widget.onTapFaceUp?.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final v = Curves.easeInOutSine.transform(_reveal.value);
          return RepaintBoundary(
            child: Opacity(
              opacity: faceUp ? 0.35 + 0.65 * v : 1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX(widget.tilt ? -0.14 : 0)
                  ..scaleByDouble(faceUp ? 0.985 + 0.015 * v : 1.0, 1, 1, 1),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.width * 0.06),
                  child: SizedBox(
                    width: widget.width,
                    height: widget.height,
                    child: faceUp
                        ? _face(pack)
                        : CardBack(
                            width: widget.width,
                            height: widget.height,
                            styleOverride: pack.backStyle,
                            accentOverride: pack.backAccentArgb,
                            secondaryOverride: pack.backSecondaryArgb,
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The procedural engraved face — always upright.
  Widget _face(LenormandPack pack) {
    final card = widget.card;
    final accent = Color(pack.faceAccentArgb);
    final secondary = Color(pack.faceSecondaryArgb);
    final background = Color(pack.faceBackgroundArgb);
    final isDark = background.computeLuminance() < 0.3;

    final face = Container(
      width: widget.width,
      height: widget.height,
      color: background,
      padding: EdgeInsets.all(widget.width * 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: number (left) + playing-card inset (right).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.number.toString().padLeft(2, '0'),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: widget.width * 0.085,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              Text(
                card.insetLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: widget.width * 0.08,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: isDark ? accent.withValues(alpha: 0.9) : secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.height * 0.045),
          // Engraved hairline frame around the central emblem.
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(widget.width * 0.04),
              ),
              child: _LenormandEmblem(
                card: card,
                accent: accent,
                secondary: secondary,
                width: widget.width,
              ),
            ),
          ),
          SizedBox(height: widget.height * 0.035),
          Text(
            card.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: widget.width * 0.085,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? AppColors.textPrimary : AppColors.surface,
            ),
          ),
          SizedBox(height: widget.height * 0.012),
          Text(
            card.keywords.map((k) => k.toLowerCase()).join(' · '),
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: widget.width * 0.048,
              letterSpacing: 0.6,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: widget.height * 0.012),
          Text(
            'PETIT LENORMAND · ${card.timing.toUpperCase()}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: widget.width * 0.043,
              letterSpacing: 1.2,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );

    // Real scan if it exists — full-bleed art, never covered by bars.
    final candidates = pack.cardAssetCandidates(card.number);
    return Stack(
      fit: StackFit.expand,
      children: [
        _faceAsset(candidates, face),
        Positioned.fill(
          child: FoilGlint(angleY: 0.18, angleX: 0.10, intensity: 0.5),
        ),
      ],
    );
  }

  Widget _faceAsset(List<String> candidates, Widget face) {
    if (candidates.isEmpty) return face;
    return Image.asset(
      candidates.first,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _faceAsset(candidates.sublist(1), face),
    );
  }
}

/// Central engraved emblem: the large inset glyph inside a chiseled ring.
class _LenormandEmblem extends StatelessWidget {
  const _LenormandEmblem({
    required this.card,
    required this.accent,
    required this.secondary,
    required this.width,
  });

  final LenormandCard card;
  final Color accent;
  final Color secondary;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.insetLabel,
            style: GoogleFonts.cinzel(
              fontSize: width * 0.19,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          SizedBox(height: width * 0.03),
          Text(
            '${card.playingCard.label.toUpperCase()} · '
            '${card.playingCard.domain.toUpperCase()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: width * 0.045,
              letterSpacing: 1.1,
              color: secondary.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
