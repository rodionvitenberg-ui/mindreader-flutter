import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/rune_stone.dart';
import '../../../state/deck_pack_controller.dart';

/// One carved 3D rune stone: an organic pebble/tablet silhouette with a
/// radial rock shader, chiseled edge highlights, a moving specular glint
/// and a deep stone drop shadow. Face-down it is a blank dark stone; when
/// flipped (tap), the glowing rune glyph ETCHES into the surface over
/// 650ms and ignites (glow bloom + haptic). Symmetrical runes always stay
/// upright — the glyph never rotates.
class RuneStone3DWidget extends StatefulWidget {
  const RuneStone3DWidget({
    super.key,
    required this.stone,
    required this.isMerkstave,
    required this.state,
    required this.width,
    required this.height,
    this.slotIndex = 0,
    this.tilt = false,
    this.interactive = true,
    this.onFlip,
    this.onTapFaceUp,
  });

  final RuneStone stone;
  final bool isMerkstave;
  final SlotState state;
  final double width;
  final double height;

  /// Table slot index — seeds the deterministic organic resting tilt.
  final int slotIndex;

  /// True on the dealt table (an actual slot); false in the heap/flight,
  /// where the stone must stay upright so it reads as one pile of stones.
  final bool tilt;

  final bool interactive;
  final VoidCallback? onFlip;
  final VoidCallback? onTapFaceUp;

  /// Deterministic natural resting tilt in [-0.18, +0.18] rad (±10°), seeded
  /// by [slotIndex] + [stone.id]. The rock body tilts, but the glyph is
  /// counter-rotated inside the painter so it always stands vertical.
  double get stoneTiltRad {
    final h = (slotIndex * 31 + stone.id * 17).abs();
    final unit = (h % 360) / 359.0; // 0..1, deterministic
    return (unit * 2.0 - 1.0) * 0.18;
  }

  @override
  State<RuneStone3DWidget> createState() => _RuneStone3DWidgetState();
}

class _RuneStone3DWidgetState extends State<RuneStone3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ignite = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    value: widget.state == SlotState.faceUp ? 1.0 : 0.0,
  );

  /// True while the local glyph etch is playing (tap-to-flip).
  bool _revealing = false;

  @override
  void didUpdateWidget(covariant RuneStone3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != SlotState.faceUp &&
        widget.state == SlotState.faceUp) {
      _ignite.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ignite.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.state == SlotState.faceDown) {
      setState(() => _revealing = true);
      HapticFeedback.selectionClick();
      _ignite.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _revealing = false);
        widget.onFlip?.call();
        _ignite.value = 0;
      });
    } else if (widget.state == SlotState.faceUp) {
      widget.onTapFaceUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activeRunePack;
    final faceUp = widget.state == SlotState.faceUp;
    // On the dealt table the rock body tilts; in the heap/flight it stays
    // upright (the heap passes tilt:false).
    final tilt = widget.tilt ? widget.stoneTiltRad : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive ? _handleTap : null,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ignite,
          builder: (context, _) {
            final v = Curves.easeInOutCubic.transform(_ignite.value);
            // Breathing lift during the mist phase (1.0 → 1.035 → 1.0).
            final breathe = _revealing
                ? 1.0 + 0.035 * math.sin(math.pi * v)
                : 1.0;
            return Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: breathe,
                child: CustomPaint(
                  painter: RuneStonePainter(
                    stone: widget.stone,
                    pack: pack,
                    faceUp: faceUp,
                    ignite: v,
                    merkstave: widget.isMerkstave,
                    stoneTilt: tilt,
                    revealing: _revealing,
                  ),
                  size: Size(widget.width, widget.height),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The procedural carved-rock shader: irregular rounded polygon, radial
/// stone gradient, chiseled rim light, engraved glyph channel with an
/// ignition bloom, moving specular glint and a deep drop shadow.
class RuneStonePainter extends CustomPainter {
  const RuneStonePainter({
    required this.stone,
    required this.pack,
    required this.faceUp,
    required this.ignite,
    this.merkstave = false,
    this.seed = 7,
    this.stoneTilt = 0,
    this.revealing = false,
  });

  final RuneStone stone;
  final RunePack pack;
  final bool faceUp;
  final double ignite; // 0..1 glyph etching / glow bloom
  final bool merkstave;
  final int seed;

  /// Natural rock-body tilt (rad) — the glyph is counter-rotated by this
  /// amount so the rune always stands vertical.
  final double stoneTilt;

  /// True during the tap-to-flip mist phase (drives the dark veil).
  final bool revealing;

  /// Deterministic organic contour: 7–9 rounded facets + aspect-ratio spread
  /// seeded by the rune's identity, so each of the 24 stones has its own
  /// natural pebble silhouette.
  static List<Offset> _silhouetteOffsets(RuneStone stone, math.Random rng) {
    final sides = 7 + (stone.id * 7 + 1) % 3; // 7, 8 or 9 facets
    final aRatio = 0.88 + ((stone.id * 5) % 7) * 0.03; // axe-stretch 0.88..1.06
    final out = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final a = i / sides * 2 * math.pi - math.pi / 2;
      final jitter = 0.86 + rng.nextDouble() * 0.28;
      out.add(Offset(math.cos(a) * jitter, math.sin(a) * aRatio * jitter));
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rng = math.Random(seed);
    final base = Color(pack.stoneBaseArgb);
    final dark = Color(pack.stoneDarkArgb);
    final rim = Color(pack.stoneRimArgb);
    final glyphColor = Color(pack.glyphArgb);
    final glow = Color(pack.glowArgb);

    // Organic pebble silhouette: unit offsets scaled to the canvas half.
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * 0.46;
    final radiusY = size.height * 0.44;
    final points = [
      for (final o in _silhouetteOffsets(stone, rng))
        Offset(center.dx + o.dx * radiusX, center.dy + o.dy * radiusY),
    ];
    final silhouette = Path()..addPolygon(points, true);

    // Deep stone drop shadow first.
    canvas.drawShadow(
      silhouette.shift(Offset(0, size.height * 0.06)),
      Colors.black,
      size.width * 0.16,
      false,
    );

    // Radial rock shader — base center light falling to dark edge.
    final shader = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      radius: 1.25,
      colors: [Color.lerp(base, Colors.white, 0.12)!, base, dark],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawPath(silhouette, Paint()..shader = shader);

    // Chiseled edge highlight — top-left rim light, bottom-right dark rim.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;
    final rimGradient = SweepGradient(
      colors: [
        rim.withValues(alpha: 0.0),
        rim.withValues(alpha: 0.65),
        rim.withValues(alpha: 0.0),
        rim.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.32, 0.6, 1.0],
    ).createShader(Offset.zero & size);
    rimPaint.shader = rimGradient;
    canvas.drawPath(silhouette, rimPaint);

    // Deep obsidian mist veil during the tap-to-flip phase (0→0.45→0).
    if (revealing) {
      final t = ignite;
      final veilAlpha = t < 0.35
          ? 0.45 * (t / 0.35)
          : 0.45 * (1 - (t - 0.35) / 0.65);
      if (veilAlpha > 0) {
        canvas.drawPath(
          silhouette,
          Paint()
            ..color = Colors.black.withValues(alpha: veilAlpha.clamp(0.0, 0.6)),
        );
      }
    }

    // Engraved glyph channel: a dark recess + the glowing glyph inside. The
    // glyph is counter-rotated by -stoneTilt so the rune always reads
    // vertical (0° upright / π merkstave) even though the rock body tilts.
    if (faceUp) {
      final glyphOpacity = 0.15 + 0.85 * ignite;
      final textPainter = TextPainter(
        text: TextSpan(
          text: stone.glyph,
          style: TextStyle(
            fontSize: size.width * 0.42,
            fontWeight: FontWeight.w600,
            color: glyphColor.withValues(alpha: glyphOpacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final glyphCenter = Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      );

      // Ignition bloom behind the glyph.
      if (ignite > 0.02) {
        final bloom = Paint()
          ..shader =
              RadialGradient(
                colors: [
                  glow.withValues(alpha: 0.5 * ignite),
                  glow.withValues(alpha: 0.0),
                ],
              ).createShader(
                Rect.fromCircle(center: center, radius: size.width * 0.55),
              );
        canvas.drawPath(silhouette, bloom);
      }
      canvas.save();
      canvas.translate(center.dx, center.dy);
      // Counter-rotate the glyph to keep it vertical; merkstave flips it 180°.
      canvas.rotate(merkstave ? math.pi - stoneTilt : -stoneTilt);
      canvas.translate(-center.dx, -center.dy);
      textPainter.paint(canvas, glyphCenter);
      canvas.restore();
    }

    // Moving specular glint sweep.
    final glintColor = Color(pack.specularArgb).withValues(alpha: 0.28);
    final glint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.6, -0.75),
        radius: 0.9,
        colors: [glintColor, glintColor.withValues(alpha: 0.0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(silhouette, glint);
  }

  @override
  bool shouldRepaint(covariant RuneStonePainter oldDelegate) =>
      oldDelegate.ignite != ignite ||
      oldDelegate.faceUp != faceUp ||
      oldDelegate.stone.id != stone.id ||
      oldDelegate.pack.id != pack.id ||
      oldDelegate.stoneTilt != stoneTilt ||
      oldDelegate.merkstave != merkstave ||
      oldDelegate.revealing != revealing;
}
