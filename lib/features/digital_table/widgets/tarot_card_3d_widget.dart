import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/deck_pack_controller.dart';
import 'foil_glint.dart';

/// Procedural card back — seven bespoke patterns (one per deck style), no
/// image assets required. Palette follows the active deck pack.
class CardBackPainter extends CustomPainter {
  const CardBackPainter({this.pack});

  final TarotDeckPack? pack;

  Color get _accent => Color(pack?.backAccentArgb ?? 0xFFA78BFA);
  Color get _secondary => Color(pack?.backSecondaryArgb ?? 0xFF6366F1);

  @override
  void paint(Canvas canvas, Size size) {
    // The very first frame on a real device can arrive with a 0x0 surface
    // ("FlutterRenderer: Width is zero"). Several back styles derive loop
    // steps from size.width, so a zero width produces step 0 and an
    // infinite loop on the main thread. Paint nothing until a real size
    // is laid out.
    if (size.isEmpty) return;
    final style = pack?.backStyle ?? CardBackStyle.obsidian;
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
      oldDelegate.pack?.id != pack?.id;
}

/// RepaintBoundary-wrapped procedural card back with an optional specular
/// glint that slides with the card's 3D angle.
class CardBack extends StatelessWidget {
  const CardBack({
    super.key,
    required this.width,
    required this.height,
    this.pack,
    this.angleY = 0,
    this.angleX = 0,
    this.glint = false,
  });

  final double width;
  final double height;
  final TarotDeckPack? pack;
  final double angleY;
  final double angleX;
  final bool glint;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.06),
        child: Stack(
          children: [
            CustomPaint(
              size: Size(width, height),
              painter: CardBackPainter(pack: pack),
            ),
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

/// A single 3D tarot card: 2.5D perspective, isometric tilt, 680ms
/// `rotateY(π)` flip on `Curves.easeInOutCubic` (deliberate, heavy,
/// ceremonial) with a haptic at the 90° midpoint and a `FoilGlint`
/// specular sheen sliding across the surface mid-flip. NO protruding
/// side strips/bevel layers — the flip is clean inside the card's
/// rounded border.

/// Flip duration: 680ms — +40% heavier than the old snappy 600ms flip.
const cardFlipDuration = Duration(milliseconds: 680);

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
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: cardFlipDuration,
  )..addListener(_onFlipTick);

  /// The ceremonial timing curve: heavy start, heavy stop, graceful middle.
  late final CurvedAnimation _flipCurve = CurvedAnimation(
    parent: _flip,
    curve: Curves.easeInOutCubic,
  );

  bool _flipping = false;
  double _lastValue = 0;

  void _onFlipTick() {
    // Haptic exactly at the 90° midpoint of the flip.
    if (_lastValue < 0.5 && _flip.value >= 0.5) {
      HapticFeedback.mediumImpact();
    }
    _lastValue = _flip.value;
  }

  @override
  void dispose() {
    _flipCurve.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_flipping) return;
    if (widget.state == SlotState.faceDown) {
      setState(() => _flipping = true);
      _flip.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        _flipping = false;
        widget.onFlip?.call(); // controller reveals the card
        _flip.value = 0; // face now rests at rotateY(0)
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
        animation: _flip,
        builder: (context, _) {
          final v = _flipCurve.value;
          final showFace =
              widget.state == SlotState.faceUp || (_flipping && v >= 0.5);
          var angle = 0.0;
          if (_flipping) {
            angle = v < 0.5 ? math.pi * v : math.pi * v - math.pi;
          }
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, perspectiveEntry)
            ..rotateX(widget.tilt ? slotTiltRadians : 0)
            ..rotateY(angle);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: Stack(
                  children: [
                    showFace
                        ? _CardFace(
                            card: widget.card,
                            isReversed: widget.isReversed,
                            width: widget.width,
                            height: widget.height,
                            pack: pack,
                          )
                        : CardBack(
                            width: widget.width,
                            height: widget.height,
                            pack: pack,
                          ),
                    // Specular sheen slides across the card mid-flip.
                    if (_flipping)
                      Positioned.fill(
                        child: FoilGlint(
                          angleY: angle,
                          angleX: widget.tilt ? slotTiltRadians : 0,
                          intensity: 0.55,
                        ),
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
  Widget _faceArt() {
    final candidates = pack.cardAssetCandidates(card);
    Widget fallback() => _TypographicFace(card: card, width: width, pack: pack);
    Widget build(int i) => i >= candidates.length
        ? fallback()
        : Image.asset(
            candidates[i],
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => build(i + 1),
          );
    return Image.asset(
      'assets/cards/${card.id}.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => build(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faceSec = Color(pack.faceSecondaryArgb);
    final faceAccent = Color(pack.faceAccentArgb);
    final face = Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.055),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.positionLabel,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: width * 0.07,
                    letterSpacing: 1.4,
                    color: faceAccent.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '${card.element.glyph} ${card.element.label.toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: width * 0.055,
                  letterSpacing: 1.2,
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
            style: GoogleFonts.jetBrainsMono(
              fontSize: width * 0.05,
              letterSpacing: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
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
            style: GoogleFonts.cinzel(
              fontSize: width * 0.09,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.keywords.map((k) => k.toLowerCase()).join(' · '),
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
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

