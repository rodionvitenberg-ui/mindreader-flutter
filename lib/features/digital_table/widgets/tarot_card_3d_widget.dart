import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/deck_pack_controller.dart';
import 'foil_glint.dart';

/// Procedural card back — seven bespoke patterns (one per deck style), no
/// image assets required. Palette follows the active deck pack, or the
/// explicit [styleOverride]/[accentOverride]/[secondaryOverride] triples
/// (used by the Lenormand packs, which have no tarot pack object).
class CardBackPainter extends CustomPainter {
  const CardBackPainter({
    this.pack,
    this.styleOverride,
    this.accentOverride,
    this.secondaryOverride,
  });

  final TarotDeckPack? pack;

  /// Replaces [pack]'s style (Lenormand backs reuse the tarot families).
  final CardBackStyle? styleOverride;
  final int? accentOverride;
  final int? secondaryOverride;

  Color get _accent =>
      Color(accentOverride ?? pack?.backAccentArgb ?? 0xFFA78BFA);
  Color get _secondary =>
      Color(secondaryOverride ?? pack?.backSecondaryArgb ?? 0xFF6366F1);

  @override
  void paint(Canvas canvas, Size size) {
    // The very first frame on a real device can arrive with a 0x0 surface
    // ("FlutterRenderer: Width is zero"). Several back styles derive loop
    // steps from size.width, so a zero width produces step 0 and an
    // infinite loop on the main thread. Paint nothing until a real size
    // is laid out.
    if (size.isEmpty) return;
    final style =
        styleOverride ?? pack?.backStyle ?? CardBackStyle.obsidian;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(r, Paint()..color = AppColors.surface);

    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _accent.withValues(alpha: 0.5);
    canvas.drawRRect(r.deflate(size.width * 0.05), frame);

    switch (style) {
      case CardBackStyle.obsidian:
        _paintObsidian(canvas, size);
      case CardBackStyle.marseille:
        _paintMarseille(canvas, size);
      case CardBackStyle.hermetic:
        _paintHermetic(canvas, size);
      case CardBackStyle.botanical:
        _paintBotanical(canvas, size);
      case CardBackStyle.visconti:
        _paintVisconti(canvas, size);
      case CardBackStyle.shadow:
        _paintShadow(canvas, size);
      case CardBackStyle.cyber:
        _paintCyber(canvas, size);
    }
  }

  void _paintObsidian(Canvas canvas, Size size) {
    final step = size.width * 0.22;
    final lattice = Paint()
      ..strokeWidth = 0.6
      ..color = _accent.withValues(alpha: 0.16);
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), lattice);
      canvas.drawLine(
          Offset(x + size.height, 0), Offset(x, size.height), lattice);
    }
    _paintSigil(canvas, size);
  }

  void _paintMarseille(Canvas canvas, Size size) {
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _accent.withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.09, size.height * 0.09,
            size.width * 0.82, size.height * 0.82),
        Radius.circular(size.width * 0.03),
      ),
      inner,
    );
    final hatch = Paint()
      ..strokeWidth = 0.6
      ..color = _secondary.withValues(alpha: 0.22);
    const gap = 14.0;
    for (double y = size.height * 0.12; y < size.height * 0.88; y += gap) {
      canvas.drawLine(Offset(size.width * 0.12, y),
          Offset(size.width * 0.88, y), hatch);
    }
    for (double x = size.width * 0.12; x < size.width * 0.88; x += gap) {
      canvas.drawLine(Offset(x, size.height * 0.12),
          Offset(x, size.height * 0.88), hatch);
    }
    _paintSigil(canvas, size, diamond: true);
  }

  void _paintHermetic(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.30;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _accent.withValues(alpha: 0.8);
    canvas.drawCircle(center, radius, line);
    final r1 = radius * 0.92;
    final path = Path();
    for (var k = 0; k < 2; k++) {
      final start = -math.pi / 2 + k * math.pi / 3;
      for (var v = 0; v <= 3; v++) {
        final a = start + v * 2 * math.pi / 3;
        final p = Offset(
            center.dx + r1 * math.cos(a), center.dy + r1 * math.sin(a));
        v == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, line);
    canvas.drawCircle(
        center, radius * 0.08, Paint()..color = _secondary);
    final dot = Paint()..color = _secondary.withValues(alpha: 0.7);
    for (final c in [
      Offset(size.width * 0.16, size.height * 0.16),
      Offset(size.width * 0.84, size.height * 0.16),
      Offset(size.width * 0.16, size.height * 0.84),
      Offset(size.width * 0.84, size.height * 0.84),
    ]) {
      canvas.drawCircle(c, 2.4, dot);
    }
  }

  void _paintBotanical(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _accent.withValues(alpha: 0.75);
    // Stem arcs fanning out like a fern.
    for (var i = -3; i <= 3; i++) {
      final rect = Rect.fromCircle(
        center: center,
        radius: size.width * 0.10 * (4 - i.abs()),
      );
      canvas.drawArc(
        rect.translate(
            -size.width * 0.22 * i.abs(), -size.height * 0.08 * i.abs()),
        math.pi * (0.9 + 0.05 * i),
        math.pi * 0.5,
        false,
        stem,
      );
      canvas.drawArc(
        rect.translate(
            size.width * 0.22 * i.abs(), -size.height * 0.08 * i.abs()),
        math.pi * (0.55 + 0.05 * i),
        math.pi * 0.5,
        false,
        stem,
      );
    }
    canvas.drawLine(
        Offset(center.dx, size.height * 0.3),
        Offset(center.dx, size.height * 0.86),
        Paint()
          ..strokeWidth = 1
          ..color = _secondary.withValues(alpha: 0.6));
    final dot = Paint()..color = _secondary.withValues(alpha: 0.7);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi * 2 / 12;
      canvas.drawCircle(
        Offset(center.dx + size.width * 0.3 * math.cos(a),
            center.dy + size.height * 0.18 * math.sin(a) - size.height * 0.08),
        1.8,
        dot,
      );
    }
  }

  void _paintVisconti(Canvas canvas, Size size) {
    final dot = Paint()..color = _secondary.withValues(alpha: 0.18);
    const gap = 18.0;
    for (double y = 0; y < size.height; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = _accent.withValues(alpha: 0.85);
    for (final f in [0.30, 0.22, 0.14]) {
      canvas.drawCircle(center, size.width * f, ring);
    }
    final petal = Paint()..color = _accent.withValues(alpha: 0.8);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi * 2 / 12;
      canvas.drawCircle(
        Offset(center.dx + size.width * 0.26 * math.cos(a),
            center.dy + size.width * 0.26 * math.sin(a)),
        2.2,
        petal,
      );
    }
    canvas.drawCircle(
        center, size.width * 0.045, Paint()..color = _secondary);
  }



  void _paintShadow(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final d = size.width * 0.20;
    final diamond = Path()
      ..moveTo(center.dx, center.dy - d)
      ..lineTo(center.dx + d, center.dy)
      ..lineTo(center.dx, center.dy + d)
      ..lineTo(center.dx - d, center.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _accent.withValues(alpha: 0.9),
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - d * 0.55),
      Offset(center.dx, center.dy + d * 0.55),
      Paint()
        ..strokeWidth = 1
        ..color = _secondary.withValues(alpha: 0.8),
    );
    final slash = Paint()
      ..strokeWidth = 0.8
      ..color = _secondary.withValues(alpha: 0.35);
    canvas.drawLine(Offset(size.width * 0.16, size.height * 0.16),
        Offset(size.width * 0.84, size.height * 0.84), slash);
    canvas.drawLine(Offset(size.width * 0.84, size.height * 0.16),
        Offset(size.width * 0.16, size.height * 0.84), slash);
  }

  void _paintCyber(Canvas canvas, Size size) {
    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _accent.withValues(alpha: 0.8);
    final via = Paint()..color = _secondary.withValues(alpha: 0.9);
    final segs = [
      (Offset(size.width * 0.16, size.height * 0.22),
          Offset(size.width * 0.40, size.height * 0.22),
          Offset(size.width * 0.40, size.height * 0.40)),
      (Offset(size.width * 0.84, size.height * 0.78),
          Offset(size.width * 0.60, size.height * 0.78),
          Offset(size.width * 0.60, size.height * 0.60)),
      (Offset(size.width * 0.16, size.height * 0.78),
          Offset(size.width * 0.40, size.height * 0.78),
          Offset(size.width * 0.40, size.height * 0.60)),
      (Offset(size.width * 0.84, size.height * 0.22),
          Offset(size.width * 0.60, size.height * 0.22),
          Offset(size.width * 0.60, size.height * 0.40)),
    ];
    for (final s in segs) {
      canvas.drawLine(s.$1, s.$2, trace);
      canvas.drawLine(s.$2, s.$3, trace);
      canvas.drawCircle(s.$2, 2.2, via);
    }
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 3.2, via);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi * 2 / 8;
      final p = Offset(center.dx + size.width * 0.22 * math.cos(a),
          center.dy + size.width * 0.22 * math.sin(a));
      canvas.drawLine(
          center,
          p,
          Paint()
            ..strokeWidth = 0.8
            ..color = _accent.withValues(alpha: 0.5));
      canvas.drawCircle(p, 1.6, via);
    }
  }

  void _paintSigil(Canvas canvas, Size size, {bool diamond = false}) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.26;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _secondary.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _accent.withValues(alpha: 0.75),
    );
    final d = radius * (diamond ? 0.7 : 0.55);
    final path = Path()
      ..moveTo(center.dx, center.dy - d)
      ..lineTo(center.dx + d, center.dy)
      ..lineTo(center.dx, center.dy + d)
      ..lineTo(center.dx - d, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _secondary.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      center,
      radius * 0.2,
      Paint()..color = _accent.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CardBackPainter oldDelegate) =>
      oldDelegate.pack?.id != pack?.id ||
      oldDelegate.styleOverride != styleOverride ||
      oldDelegate.accentOverride != accentOverride ||
      oldDelegate.secondaryOverride != secondaryOverride;
}

/// RepaintBoundary-wrapped procedural card back with an optional specular
/// glint that slides with the card's 3D angle.
class CardBack extends StatelessWidget {
  const CardBack({
    super.key,
    required this.width,
    required this.height,
    this.pack,
    this.styleOverride,
    this.accentOverride,
    this.secondaryOverride,
    this.angleY = 0,
    this.angleX = 0,
    this.glint = false,
  });

  final double width;
  final double height;
  final TarotDeckPack? pack;

  /// Lenormand packs reuse the tarot back-pattern families via these
  /// overrides (no tarot pack object exists for them).
  final CardBackStyle? styleOverride;
  final int? accentOverride;
  final int? secondaryOverride;

  final double angleY;
  final double angleX;
  final bool glint;

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      size: Size(width, height),
      painter: CardBackPainter(
        pack: pack,
        styleOverride: styleOverride,
        accentOverride: accentOverride,
        secondaryOverride: secondaryOverride,
      ),
    );
    // Real deck backs (pack.backAsset → back.jpg) replace the procedural
    // pattern when the asset exists; zero-crash fallback chain to painter.
    final candidates = pack?.backAssetCandidates;
    Widget back() => candidates == null
        ? painter
        : Image.asset(
            candidates.first,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => candidates.length > 1
                ? Image.asset(
                    candidates[1],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => painter,
                  )
                : painter,
          );
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.06),
        child: Stack(
          children: [
            SizedBox(width: width, height: height, child: back()),
            if (glint)
              Positioned.fill(
                child: FoilGlint(
                  angleY: angleY,
                  angleX: angleX,
                  intensity: 0.6,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single 3D tarot card resting flat and serene on the table plane:
/// 2.5D perspective, isometric tilt, and a MEDITATIVE 750ms "arcane
/// materialization" reveal on `Curves.easeInOutSine` — ZERO `rotateY`
/// flip, no harsh geometric jump at 90°:
///
/// 1. a subtle breathing lift (scale 1.0 → 1.035 → 1.0) with a soft
///    ambient glow pulse;
/// 2. the card back dissolves into deep obsidian darkness (0 → 0.45);
/// 3. the face materializes from the center outward through a radial
///    `ShaderMask` mist (opacity 0 → 1 from v = 0.25) while a slow
///    diagonal `FoilGlint` light sweep crosses the revealed artwork.
/// A haptic lands at the halfway point; completion fires [onFlip].

/// Reveal duration: 750ms meditative materialization.
const cardRevealDuration = Duration(milliseconds: 750);

class TarotCard3DWidget extends StatefulWidget {
  const TarotCard3DWidget({
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

  final TarotCard card;
  final bool isReversed;
  final SlotState state;
  final double width;
  final double height;
  final bool tilt; // isometric board tilt; false for flat previews
  final bool interactive; // false = pass taps through (e.g. almanac tiles)
  final VoidCallback? onFlip; // fired when the flip animation completes
  final VoidCallback? onTapFaceUp;

  @override
  State<TarotCard3DWidget> createState() => _TarotCard3DWidgetState();
}

class _TarotCard3DWidgetState extends State<TarotCard3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: cardRevealDuration,
  )..addListener(_onRevealTick);

  /// The meditative timing curve: calm start, calm stop, graceful middle.
  late final CurvedAnimation _revealCurve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeInOutSine,
  );

  bool _revealing = false;
  double _lastValue = 0;

  void _onRevealTick() {
    // Haptic exactly at the halfway point of the materialization.
    if (_lastValue < 0.5 && _reveal.value >= 0.5) {
      HapticFeedback.mediumImpact();
    }
    _lastValue = _reveal.value;
  }

  @override
  void dispose() {
    _revealCurve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_revealing) return;
    if (widget.state == SlotState.faceDown) {
      setState(() => _revealing = true);
      _reveal.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        _revealing = false;
        widget.onFlip?.call(); // controller reveals the card
        _reveal.value = 0; // face now rests fully materialized
      });
    } else if (widget.state == SlotState.faceUp) {
      widget.onTapFaceUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activePack;
    final content = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final v = _revealCurve.value;
          final showFace = widget.state == SlotState.faceUp ||
              (_revealing && v >= 0.25);
          // Breathing lift: 1.0 → 1.035 → 1.0 — the card floats gently.
          final breathe =
              _revealing ? 1.0 + 0.035 * math.sin(math.pi * v) : 1.0;
          // The back dissolves into deep obsidian darkness (0 → 0.45 → 0).
          final backAlpha =
              _revealing ? (v < 0.35 ? 1.0 - v / 0.35 : 0.0) : 1.0;
          final darkVeil = _revealing
              ? (v < 0.35
                  ? 0.45 * (v / 0.35)
                  : 0.45 * (1 - (v - 0.35) / 0.65))
              : 0.0;
          // The face materializes from the center outward from v = 0.25.
          final faceIn = ((v - 0.25) / 0.75).clamp(0.0, 1.0);
          // Flat and serene — isometric tilt only, NEVER rotateY.
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, perspectiveEntry)
            ..rotateX(widget.tilt ? slotTiltRadians : 0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: Stack(
                  children: [
                    Transform.scale(
                      scale: breathe,
                      child: Opacity(
                        opacity: backAlpha,
                        child: CardBack(
                          width: widget.width,
                          height: widget.height,
                          pack: pack,
                        ),
                      ),
                    ),
                    if (_revealing) ...[
                      // Soft ambient glow pulse breathing with the card.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.lavender.withValues(
                                    alpha: 0.28 * math.sin(math.pi * v),
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Deep obsidian darkness between back and face.
                      if (darkVeil > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    Colors.black.withValues(alpha: darkVeil),
                              ),
                            ),
                          ),
                        ),
                      // The face emerges from the center outward through a
                      // radial mist…
                      if (showFace && faceIn > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: faceIn,
                              child: ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) => RadialGradient(
                                  radius: 0.3 + 1.1 * faceIn,
                                  colors: const [
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.72, 1.0],
                                ).createShader(bounds),
                                child: _CardFace(
                                  card: widget.card,
                                  isReversed: widget.isReversed,
                                  width: widget.width,
                                  height: widget.height,
                                  pack: pack,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // …swept by a slow diagonal light glint.
                      if (faceIn > 0 && faceIn < 1)
                        Positioned.fill(
                          child: FoilGlint(
                            angleY: -0.9 + 1.8 * v,
                            angleX: widget.tilt ? slotTiltRadians : 0,
                            intensity: math.sin(math.pi * faceIn) * 0.6,
                          ),
                        ),
                    ],
                    if (!_revealing && showFace)
                      _CardFace(
                        card: widget.card,
                        isReversed: widget.isReversed,
                        width: widget.width,
                        height: widget.height,
                        pack: pack,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    if (!widget.interactive) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: content,
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.isReversed,
    required this.width,
    required this.height,
    required this.pack,
  });

  final TarotCard card;
  final bool isReversed;
  final double width;
  final double height;
  final TarotDeckPack pack;

  /// Smart asset resolver with zero-crash fallback: legacy bundled artwork
  /// → active pack candidates (`<id>.jpg/png`, `00.jpg`, RWS names) → the
  /// bespoke procedural face in the pack's palette.
  Widget _faceArt({double? clipRadius}) {
    final candidates = pack.cardAssetCandidates(card);
    Widget fallback() => _TypographicFace(card: card, width: width, pack: pack);
    Widget build(int i) => i >= candidates.length
        ? fallback()
        : _framedArtwork(candidates[i], () => build(i + 1), clipRadius);
    return Image.asset(
      'assets/cards/${card.id}.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => build(0),
    );
  }

  /// The historical scan, framed like a native obsidian card: `BoxFit.contain`
  /// renders the FULL artwork edge to edge inside the rounded border — zero
  /// crop at the top or bottom (the old `BoxFit.cover` + 1.05 upscale clipped
  /// the illustrated deck's artwork). A dark inner vignette with a hairline
  /// accent border still frames it. [clipRadius] defaults to the inner padded
  /// radius; illustrated full-bleed faces pass the card radius.
  Widget _framedArtwork(
    String path,
    Widget Function() onError,
    double? clipRadius,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(clipRadius ?? width * 0.035),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => onError(),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.38),
                  ],
                  stops: const [0.62, 0.86, 1.0],
                ),
                border: Border.all(
                  color: Color(pack.faceAccentArgb).withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faceSec = Color(pack.faceSecondaryArgb);
    final faceAccent = Color(pack.faceAccentArgb);
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(faceSec, Colors.black, 0.45)!,
          AppColors.surface,
        ],
      ),
      borderRadius: BorderRadius.circular(width * 0.06),
      border: Border.all(color: faceAccent.withValues(alpha: 0.35)),
    );

    // Illustrated decks (the 7 real historical scans): the artwork fills
    // the ENTIRE card face, edge to edge inside the rounded border — NO
    // top/bottom text bars may ever cover or crop the illustration.
    final Widget face;
    if (pack.isIllustrated) {
      face = Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: _faceArt(clipRadius: width * 0.06),
      );
    } else {
      face = Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(width * 0.055),
        decoration: decoration,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.positionLabel,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: width * 0.07,
                      letterSpacing: 0.8,
                      color: faceAccent.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Text(
                  '${card.element.glyph} ${card.element.label.toUpperCase()}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(
                    fontSize: width * 0.055,
                    letterSpacing: 0.7,
                    color: card.element.accent,
                  ),
                ),
              ],
            ),
            Expanded(child: _faceArt()),
            Text(
              card.arcana == Arcana.major
                  ? 'MAJOR ARCANA'
                  : '${card.suit!.label.toUpperCase()} · ${card.element.label.toUpperCase()}',
              style: AppTypography.label(
                fontSize: width * 0.05,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    return isReversed ? Transform.rotate(angle: math.pi, child: face) : face;
  }
}

class _TypographicFace extends StatelessWidget {
  const _TypographicFace({
    required this.card,
    required this.width,
    required this.pack,
  });

  final TarotCard card;
  final double width;
  final TarotDeckPack pack;

  @override
  Widget build(BuildContext context) {
    final accent = Color(pack.faceAccentArgb);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.element.glyph,
            style: TextStyle(fontSize: width * 0.16, color: accent),
          ),
          const SizedBox(height: 4),
          Text(
            card.name,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              fontSize: width * 0.09,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.keywords.map((k) => k.toLowerCase()).join(' · '),
            textAlign: TextAlign.center,
            style: AppTypography.label(
              fontSize: width * 0.05,
              letterSpacing: 0.8,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

