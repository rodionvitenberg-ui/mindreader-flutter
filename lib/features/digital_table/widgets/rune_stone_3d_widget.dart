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
    this.interactive = true,
    this.onFlip,
    this.onTapFaceUp,
  });

  final RuneStone stone;
  final bool isMerkstave;
  final SlotState state;
  final double width;
  final double height;
  final bool interactive;
  final VoidCallback? onFlip;
  final VoidCallback? onTapFaceUp;

  @override
  State<RuneStone3DWidget> createState() => _RuneStone3DWidgetState();
}

class _RuneStone3DWidgetState extends State<RuneStone3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ignite = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.state == SlotState.faceUp ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant RuneStone3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != SlotState.faceUp && widget.state == SlotState.faceUp) {
      HapticFeedback.selectionClick();
      _ignite.forward(from: 0).whenCompleteOrCancel(() {
        widget.onFlip?.call();
      });
    }
  }

  @override
  void dispose() {
    _ignite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activeRunePack;
    final faceUp = widget.state == SlotState.faceUp;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive
          ? () {
              if (faceUp) widget.onTapFaceUp?.call();
            }
          : null,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ignite,
          builder: (context, _) {
            final v = Curves.easeOutCubic.transform(_ignite.value);
            return CustomPaint(
              painter: RuneStonePainter(
                stone: widget.stone,
                pack: pack,
                faceUp: faceUp,
                ignite: v,
                merkstave: widget.isMerkstave,
              ),
              size: Size(widget.width, widget.height),
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
  });

  final RuneStone stone;
  final RunePack pack;
  final bool faceUp;
  final double ignite; // 0..1 glyph etching / glow bloom
  final bool merkstave;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rng = math.Random(seed);
    final base = Color(pack.stoneBaseArgb);
    final dark = Color(pack.stoneDarkArgb);
    final rim = Color(pack.stoneRimArgb);
    final glyphColor = Color(pack.glyphArgb);
    final glow = Color(pack.glowArgb);

    // Organic pebble silhouette: 9 vertices with seeded radius jitter.
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * 0.46;
    final radiusY = size.height * 0.44;
    final points = <Offset>[];
    const sides = 9;
    for (var i = 0; i < sides; i++) {
      final a = i / sides * 2 * math.pi - math.pi / 2;
      final jitter = 0.86 + rng.nextDouble() * 0.28;
      points.add(Offset(
        center.dx + math.cos(a) * radiusX * jitter,
        center.dy + math.sin(a) * radiusY * jitter,
      ));
    }
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
      colors: [
        Color.lerp(base, Colors.white, 0.12)!,
        base,
        dark,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawPath(silhouette, Paint()..shader = shader);

    // Chiseled edge highlight — top-left rim light, bottom-right dark rim.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;
    final rimGradient = SweepGradient(
      colors: [rim.withValues(alpha: 0.0), rim.withValues(alpha: 0.65), rim.withValues(alpha: 0.0), rim.withValues(alpha: 0.0)],
      stops: const [0.0, 0.32, 0.6, 1.0],
    ).createShader(Offset.zero & size);
    rimPaint.shader = rimGradient;
    canvas.drawPath(silhouette, rimPaint);

    // Engraved glyph channel: a dark recess + the glowing glyph inside.
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
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: 0.5 * ignite),
              glow.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(
            center: center,
            radius: size.width * 0.55,
          ));
        canvas.drawPath(silhouette, bloom);
      }
      canvas.save();
      if (merkstave) {
        // Merkstave: the whole glyph renders rotated 180°.
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi);
        canvas.translate(-center.dx, -center.dy);
      }
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
      oldDelegate.pack.id != pack.id;
}
