import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/lenormand_card.dart';
import '../../../core/models/lenormand_pack.dart';
import '../../../core/services/pack_asset_store.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/deck_pack_controller.dart';
import 'foil_glint.dart';
import 'tarot_card_3d_widget.dart' show CardBack;
import '../../../core/l10n/app_strings.dart';

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
    this.previewPack,
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
  final LenormandPack? previewPack;
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

  /// True while the local mist materialization is playing (tap-to-flip) —
  /// separate from the authoritative [widget.state].
  bool _revealing = false;

  @override
  void didUpdateWidget(covariant LenormandCard3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != SlotState.faceUp &&
        widget.state == SlotState.faceUp) {
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.state == SlotState.faceDown) {
      setState(() => _revealing = true);
      HapticFeedback.selectionClick();
      // The controller flips state only after the materialization completes,
      // mirroring the tarot reveal — the face does NOT pop in instantly.
      _reveal.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _revealing = false);
        widget.onFlip?.call();
        _reveal.value = 0;
      });
    } else if (widget.state == SlotState.faceUp) {
      widget.onTapFaceUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.previewPack ?? context.watch<DeckPackController>().activeLenormandPack;
    final faceUp = widget.state == SlotState.faceUp;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive ? _handleTap : null,
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final v = Curves.easeInOutCubic.transform(_reveal.value);
          // Phase 0→0.45: the back darkens into deep obsidian mist with a
          // breathing lift (1.0 → 1.035 → 1.0) + radial lavender aura.
          final breathing = _revealing
              ? 1.0 + 0.035 * math.sin(math.pi * v)
              : 1.0;
          final backAlpha = _revealing
              ? (v < 0.35 ? 1.0 - v / 0.35 : 0.0)
              : 1.0;
          final mist = _revealing
              ? (v < 0.35 ? 0.45 * (v / 0.35) : 0.45 * (1 - (v - 0.35) / 0.65))
              : 0.0;
          // Phase 0.30→1.0: the face blooms out of the mist from the center.
          final faceIn = _revealing ? ((v - 0.30) / 0.70).clamp(0.0, 1.0) : 1.0;
          return RepaintBoundary(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(widget.tilt ? -0.14 : 0)
                ..scaleByDouble(breathing, 1, 1, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.width * 0.06),
                child: SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Face-down: the procedural back, fading into the mist.
                      if (!_revealing || backAlpha > 0)
                        Opacity(
                          opacity: backAlpha,
                          child: CardBack(
                            width: widget.width,
                            height: widget.height,
                            styleOverride: pack.backStyle,
                            accentOverride: pack.backAccentArgb,
                            secondaryOverride: pack.backSecondaryArgb,
                          ),
                        ),
                      // The deep obsidian mist veil during the reveal.
                      if (mist > 0)
                        IgnorePointer(
                          child: Container(
                            color: TaroColors.surface.withValues(alpha: mist),
                          ),
                        ),
                      // The face, emerging from the center outward.
                      if (faceUp || (_revealing && faceIn > 0))
                        IgnorePointer(
                          child: Opacity(
                            opacity: faceUp ? 1.0 : faceIn,
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (bounds) => RadialGradient(
                                radius: _revealing ? 0.3 + 1.1 * faceIn : 3.0,
                                colors: const [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.72, 1.0],
                              ).createShader(bounds),
                              child: _face(pack),
                            ),
                          ),
                        ),
                      // Diagonal foil light sweep as the face completes.
                      if (_revealing && faceIn > 0 && faceIn < 1)
                        Positioned.fill(
                          child: FoilGlint(
                            angleY: -0.9 + 1.8 * v,
                            angleX: widget.tilt ? -0.14 : 0,
                            intensity: math.sin(math.pi * faceIn) * 0.6,
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
                style: AppTypography.label(
                  fontSize: widget.width * 0.085,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              Text(
                card.insetLabel,
                style: AppTypography.label(
                  fontSize: widget.width * 0.08,
                  letterSpacing: 0.7,
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
            style: AppTypography.display(
              fontSize: widget.width * 0.085,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: isDark ? TaroColors.textPrimary : TaroColors.surface,
            ),
          ),
          SizedBox(height: widget.height * 0.012),
          Text(
            card.keywords.map((k) => k.toLowerCase()).join(' · '),
            textAlign: TextAlign.center,
            style: AppTypography.label(
              fontSize: widget.width * 0.048,
              letterSpacing: 0.6,
              height: 1.35,
              color: TaroColors.textSecondary,
            ),
          ),
          SizedBox(height: widget.height * 0.012),
          Text(
            AppStrings.g('lenormand.cardTitle', {'timing': card.timing.toUpperCase()}),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(
              fontSize: widget.width * 0.043,
              letterSpacing: 0.7,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );

    // Store-downloaded scan or bundled scan if present — full-bleed art, never covered by bars.
    Widget artwork;
    if (pack.isStorePack) {
      final relPath = pack.storeCardPathForNumber(card.number);
      final provider = relPath == null
          ? null
          : PackAssetStore.instance.imageProviderFor(pack.storeKey!, relPath);
      artwork = provider == null
          ? face
          : Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => face,
            );
    } else {
      artwork = _faceAsset(pack.cardAssetCandidates(card.number), face);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        artwork,
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
            style: AppTypography.display(
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
            style: AppTypography.label(
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
