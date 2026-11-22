import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/rune_stone.dart';
import '../../../core/services/rune_stone_asset_cache.dart';
import '../../../state/deck_pack_controller.dart';

/// Stateless volumetric rune stone view that binds [RuneStoneAssetCache] to
/// [RuneStonePainter]. Every rune surface in the app (Table, Spread View heap,
/// flight overlay, Almanac, Deck Picker, Card Detail) renders through this
/// widget so all 5 material sets share identical 3D blank textures, smooth
/// Bezier 3D fallback, and carved-groove glyph rendering.
class RuneStoneView extends StatelessWidget {
  const RuneStoneView({
    super.key,
    required this.stone,
    required this.pack,
    required this.faceUp,
    this.ignite = 1.0,
    this.merkstave = false,
    this.glyphRotation,
    this.seed = 7,
    this.stoneTilt = 0,
    this.revealing = false,
    this.depthShade = 0,
    this.lift = 0,
    this.variantIndex,
    this.width,
    this.height,
  });

  final RuneStone stone;
  final RunePack pack;
  final bool faceUp;
  final double ignite;
  final bool merkstave;

  /// Optional animated glyph rotation in radians (overrides [merkstave] while
  /// interpolating upright ↔ merkstave in the Almanac inspector).
  final double? glyphRotation;

  final int seed;
  final double stoneTilt;
  final bool revealing;

  /// `0.0` = top stone (full brightness); `1.0` = deeply buried in a heap.
  final double depthShade;

  /// `0.0` = resting on the table; `1.0` = lifted / mid-flight (softer, deeper shadow).
  final double lift;

  /// Optional explicit blank-stone shape index (`0..pack.stoneVariantCount-1`).
  final int? variantIndex;

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final variant = variantIndex ?? pack.variantIndexFor(stone.id);
    return ListenableBuilder(
      listenable: RuneStoneAssetCache.instance,
      builder: (context, _) {
        final image = RuneStoneAssetCache.instance.imageFor(pack, variant);
        return CustomPaint(
          size: width != null && height != null
              ? Size(width!, height!)
              : Size.zero,
          painter: RuneStonePainter(
            stone: stone,
            pack: pack,
            stoneImage: image,
            faceUp: faceUp,
            ignite: ignite,
            merkstave: merkstave,
            glyphRotation: glyphRotation,
            seed: seed,
            stoneTilt: stoneTilt,
            revealing: revealing,
            depthShade: depthShade,
            lift: lift,
          ),
        );
      },
    );
  }
}

/// One carved 3D rune stone on the Digital Table: a volumetric 3D pebble
/// sprite (with smooth extruded Bezier fallback) and a multi-layer carved
/// Elder Futhark glyph. Face-down it rests as a blank stone; when tapped it
/// performs a tactile 3D Y-axis stone turn-over with lift and shadow
/// expansion while the carved glyph ignites over 750ms. Symmetrical runes
/// stay upright; merkstave flips only the glyph so top-left stone lighting
/// stays physically consistent.
class RuneStone3DWidget extends StatefulWidget {
  const RuneStone3DWidget({
    super.key,
    required this.stone,
    this.previewPack,
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
  final RunePack? previewPack;
  final bool isMerkstave;
  final SlotState state;
  final double width;
  final double height;

  /// Table slot index — seeds the deterministic organic resting tilt.
  final int slotIndex;

  /// True on the dealt table (an actual slot); false in the heap/flight.
  final bool tilt;

  final bool interactive;
  final VoidCallback? onFlip;
  final VoidCallback? onTapFaceUp;

  /// Deterministic natural resting tilt in [-0.15, +0.15] rad (~±8.5°), seeded
  /// by [slotIndex] + [stone.id]. The rock body tilts, while the glyph is
  /// counter-rotated inside the painter so it always stands vertical.
  double get stoneTiltRad {
    final h = (slotIndex * 31 + stone.id * 17).abs();
    final unit = (h % 360) / 359.0;
    return (unit * 2.0 - 1.0) * 0.15;
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

  /// True while the local 3D stone turn-over is playing (tap-to-flip).
  bool _revealing = false;
  bool _midpointHapticFired = false;
  bool _completedLocalReveal = false;

  @override
  void initState() {
    super.initState();
    _ignite.addListener(_onTick);
  }

  void _onTick() {
    if (_revealing && !_midpointHapticFired && _ignite.value >= 0.46) {
      _midpointHapticFired = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void didUpdateWidget(covariant RuneStone3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != SlotState.faceUp &&
        widget.state == SlotState.faceUp) {
      if (_completedLocalReveal) {
        _completedLocalReveal = false;
        _ignite.value = 1.0;
      } else {
        _ignite.forward(from: 0);
      }
    } else if (oldWidget.state == SlotState.faceUp &&
        widget.state != SlotState.faceUp) {
      _completedLocalReveal = false;
      _ignite.value = 0.0;
    }
  }

  @override
  void dispose() {
    _ignite.removeListener(_onTick);
    _ignite.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.state == SlotState.faceDown) {
      if (_revealing) return;
      setState(() {
        _revealing = true;
        _midpointHapticFired = false;
      });
      HapticFeedback.selectionClick();
      _ignite.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        _completedLocalReveal = true;
        setState(() => _revealing = false);
        widget.onFlip?.call();
      });
    } else if (widget.state == SlotState.faceUp) {
      widget.onTapFaceUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack =
        widget.previewPack ?? context.watch<DeckPackController>().activeRunePack;
    final faceUp = widget.state == SlotState.faceUp;
    final tilt = widget.tilt ? widget.stoneTiltRad : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive ? _handleTap : null,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ignite,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_ignite.value);
            double rotateY = 0.0;
            double lift = 0.0;
            bool showFace = faceUp;
            double glyphIgnite = t;

            if (_revealing) {
              // 3D Y-axis stone turn-over: lift and rotate to edge (0..0.46),
              // then rotate face-up and ignite carved runes (0.46..1.0).
              lift = math.sin(math.pi * t);
              if (t < 0.46) {
                final p = t / 0.46;
                rotateY = p * (math.pi / 2);
                showFace = false;
                glyphIgnite = 0.0;
              } else {
                final p = (t - 0.46) / 0.54;
                rotateY = -(1.0 - p) * (math.pi / 2);
                showFace = true;
                glyphIgnite = p.clamp(0.0, 1.0);
              }
            }

            final scale = 1.0 + 0.075 * lift;
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateZ(tilt)
              ..rotateY(rotateY)
              ..scaleByDouble(scale, scale, 1.0, 1.0);

            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: RuneStoneView(
                stone: widget.stone,
                pack: pack,
                faceUp: showFace,
                ignite: glyphIgnite,
                merkstave: widget.isMerkstave,
                stoneTilt: tilt,
                revealing: _revealing,
                lift: lift,
                width: widget.width,
                height: widget.height,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Volumetric 3D rune stone painter:
/// * Draws the pre-decoded 3D blank stone sprite (`stoneImage`) when available,
///   with multi-layer grounded drop shadows, heap depth occlusion shading
///   (`depthShade`), and a 3-layer carved Elder Futhark groove + ignition glow.
/// * Falls back seamlessly to a smooth closed Catmull-Rom Bezier 3D extruded
///   pebble (zero angular polygon vertices!) while assets decode or in tests.
class RuneStonePainter extends CustomPainter {
  const RuneStonePainter({
    required this.stone,
    required this.pack,
    required this.faceUp,
    required this.ignite,
    this.stoneImage,
    this.merkstave = false,
    this.glyphRotation,
    this.seed = 7,
    this.stoneTilt = 0,
    this.revealing = false,
    this.depthShade = 0,
    this.lift = 0,
  });

  final RuneStone stone;
  final RunePack pack;
  final ui.Image? stoneImage;
  final bool faceUp;
  final double ignite; // 0..1 glyph etching / glow bloom
  final bool merkstave;
  final double? glyphRotation;
  final int seed;

  /// Natural rock-body tilt (rad) — the glyph is counter-rotated by this
  /// amount so the rune always stands vertical.
  final double stoneTilt;

  /// True during the tap-to-flip phase.
  final bool revealing;

  /// `0.0` = top stone; `1.0` = deeply buried beneath other stones in a heap.
  final double depthShade;

  /// `0.0` = resting on cloth; `1.0` = lifted / mid-flight.
  final double lift;

  /// Deterministic smooth organic contour points (8 radial control points
  /// interpolated via closed Catmull-Rom cubic Beziers so fallback pebbles
  /// are always silky smooth and river-worn, never jagged polygons).
  static List<Offset> _controlPoints(RuneStone stone, math.Random rng) {
    const sides = 8;
    // Slight organic silhouette variety: egg, oval, rounded shield, broad pebble.
    final shapeStyle = (stone.id * 7 + 3) % 5;
    final topWidth = switch (shapeStyle) {
      0 => 0.90, // classic smooth oval
      1 => 0.80, // rounded egg (narrower crown)
      2 => 1.00, // rounded shield (broader crown)
      3 => 0.84, // tapered thumb-stone
      _ => 0.95, // soft river stone
    };
    final bottomWidth = switch (shapeStyle) {
      0 => 0.90,
      1 => 0.98,
      2 => 0.78,
      3 => 0.96,
      _ => 0.92,
    };

    final out = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final a = i / sides * 2 * math.pi - math.pi / 2;
      final sinA = math.sin(a);
      final cosA = math.cos(a);
      final widthFactor = sinA < 0 ? topWidth : bottomWidth;
      final jitter = 0.95 + rng.nextDouble() * 0.08;
      out.add(Offset(cosA * widthFactor * jitter, sinA * jitter));
    }
    return out;
  }

  /// Converts a closed loop of control points into a smooth Catmull-Rom
  /// cubic Bezier [Path].
  static Path _smoothClosedPath(List<Offset> pts) {
    final n = pts.length;
    final path = Path();
    if (n < 3) return path;
    path.moveTo(pts[0].dx, pts[0].dy);
    const tension = 1.0 / 6.0;
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) * tension,
        p1.dy + (p2.dy - p0.dy) * tension,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) * tension,
        p2.dy - (p3.dy - p1.dy) * tension,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final image = stoneImage;

    if (image != null) {
      _paintSpriteStone(canvas, size, center, image);
    } else {
      _paintProceduralVolumetricStone(canvas, size, center);
    }

    if (faceUp) {
      _paintCarvedGlyph(canvas, size, center);
    }
  }

  void _paintSpriteStone(
    Canvas canvas,
    Size size,
    Offset center,
    ui.Image image,
  ) {
    final liftClamped = lift.clamp(0.0, 1.0);
    final shadeClamped = depthShade.clamp(0.0, 1.0);

    // 1. Soft ambient ground shadow (expands & shifts down when lifted).
    final shadowRect = Rect.fromCenter(
      center: Offset(
        center.dx + size.width * (0.02 + 0.025 * liftClamped),
        center.dy + size.height * (0.065 + 0.065 * liftClamped),
      ),
      width: size.width * (0.76 + 0.06 * liftClamped),
      height: size.height * (0.78 + 0.05 * liftClamped),
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = Colors.black.withValues(
          alpha: (0.46 - 0.14 * liftClamped).clamp(0.18, 0.55),
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (size.width * (0.075 + 0.055 * liftClamped)).clamp(2.0, 18.0),
        ),
    );

    // 2. Tight contact shadow right beneath the resting stone base.
    if (liftClamped < 0.7) {
      final contactRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + size.height * 0.04),
        width: size.width * 0.72,
        height: size.height * 0.74,
      );
      canvas.drawOval(
        contactRect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.34 * (1 - liftClamped))
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (size.width * 0.028).clamp(1.0, 6.0),
          ),
      );
    }

    // 3. The 3D volumetric blank stone sprite (aspect-fit inside canvas).
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.contain, src.size, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);

    final imgPaint = Paint()..filterQuality = FilterQuality.medium;
    if (shadeClamped > 0.005) {
      imgPaint.colorFilter = ColorFilter.mode(
        Colors.black.withValues(alpha: (shadeClamped * 0.48).clamp(0.0, 0.65)),
        BlendMode.srcATop,
      );
    }
    canvas.drawImageRect(image, src, dst, imgPaint);
  }

  void _paintProceduralVolumetricStone(
    Canvas canvas,
    Size size,
    Offset center,
  ) {
    final rng = math.Random(seed);
    final base = Color(pack.stoneBaseArgb);
    final dark = Color(pack.stoneDarkArgb);
    final rim = Color(pack.stoneRimArgb);
    final liftClamped = lift.clamp(0.0, 1.0);
    final shadeClamped = depthShade.clamp(0.0, 1.0);

    final radiusX = size.width * 0.43;
    final radiusY = size.height * 0.43;
    final topCenter = Offset(center.dx, center.dy - size.height * 0.02);
    final points = [
      for (final o in _controlPoints(stone, rng))
        Offset(topCenter.dx + o.dx * radiusX, topCenter.dy + o.dy * radiusY),
    ];
    final topPath = _smoothClosedPath(points);

    // 1. Soft ground shadow.
    final shadowOffset = Offset(
      size.width * (0.02 + 0.025 * liftClamped),
      size.height * (0.095 + 0.06 * liftClamped),
    );
    canvas.drawPath(
      topPath.shift(shadowOffset),
      Paint()
        ..color = Colors.black.withValues(
          alpha: (0.50 - 0.14 * liftClamped).clamp(0.2, 0.6),
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (size.width * (0.075 + 0.05 * liftClamped)).clamp(2.0, 16.0),
        ),
    );

    // 2. Extruded 3D bottom thickness / chamfered stone wall.
    final wallOffset = Offset(0, size.height * 0.065);
    final wallPath = topPath.shift(wallOffset);
    final wallGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, dark, 0.55)!,
        dark,
        Color.lerp(dark, Colors.black, 0.55)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawPath(wallPath, Paint()..shader = wallGradient);

    // 3. Smooth domed top face with studio top-left key light.
    final litCenter = Color.lerp(base, Colors.white, 0.18)!;
    final domeShader = RadialGradient(
      center: const Alignment(-0.32, -0.38),
      radius: 1.15,
      colors: [litCenter, base, dark],
      stops: const [0.0, 0.56, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawPath(topPath, Paint()..shader = domeShader);

    // 4. Soft specular dome sheen (upper-left studio reflection).
    final glintColor = Color(pack.specularArgb).withValues(alpha: 0.24);
    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.52),
        radius: 0.72,
        colors: [glintColor, glintColor.withValues(alpha: 0.0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(topPath, glint);

    // 5. Subtle chiseled top-left rim light.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.022).clamp(1.0, 3.0)
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          rim.withValues(alpha: 0.0),
          rim.withValues(alpha: 0.0),
          rim.withValues(alpha: 0.42),
          rim.withValues(alpha: 0.08),
          rim.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 0.68, 0.85, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(topPath, rimPaint);

    // 6. Heap depth darkening (ambient occlusion beneath upper stones).
    if (shadeClamped > 0.005) {
      final occ = Paint()
        ..color = Colors.black.withValues(
          alpha: (shadeClamped * 0.46).clamp(0.0, 0.62),
        );
      canvas.drawPath(wallPath, occ);
      canvas.drawPath(topPath, occ);
    }
  }

  /// Paints the 3-layer carved-in-stone rune engraving:
  /// 1. Soft radial ignition bloom contained within the stone face.
  /// 2. Upper-left dark recessed chisel shadow (depth illusion).
  /// 3. Lower-right carved edge catch-light.
  /// 4. Luminous engraved glyph core with soft glow halo.
  void _paintCarvedGlyph(Canvas canvas, Size size, Offset center) {
    final glyphColor = Color(pack.glyphArgb);
    final glow = Color(pack.glowArgb);
    final rim = Color(pack.stoneRimArgb);
    final carveShadow = Color(pack.carveShadowArgb);

    final glyphOpacity = (0.18 + 0.82 * ignite).clamp(0.0, 1.0);
    final fontSize = size.width * 0.42;
    final scale = (size.width / 120.0).clamp(0.45, 2.2);

    // Soft ignition glow centered on the stone face (elliptical so it stays
    // cleanly inside the pebble silhouette without clipping artifacts).
    if (ignite > 0.02) {
      final bloomRect = Rect.fromCenter(
        center: center,
        width: size.width * 0.68,
        height: size.height * 0.68,
      );
      canvas.drawOval(
        bloomRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: 0.36 * ignite),
              glow.withValues(alpha: 0.10 * ignite),
              glow.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(bloomRect),
      );
    }

    TextPainter layoutGlyph(TextStyle style) => TextPainter(
          text: TextSpan(text: stone.glyph, style: style),
          textDirection: TextDirection.ltr,
        )..layout();

    final shadowPainter = layoutGlyph(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: carveShadow.withValues(alpha: 0.80 * glyphOpacity),
      ),
    );
    final rimPainter = layoutGlyph(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: rim.withValues(alpha: 0.42 * glyphOpacity),
      ),
    );
    final corePainter = layoutGlyph(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: glyphColor.withValues(alpha: glyphOpacity),
        shadows: [
          if (ignite > 0.05)
            Shadow(
              color: glow.withValues(alpha: 0.72 * ignite),
              blurRadius: (size.width * 0.11).clamp(3.0, 18.0),
            ),
          Shadow(
            color: carveShadow.withValues(alpha: 0.50 * glyphOpacity),
            offset: Offset(-0.6 * scale, -0.7 * scale),
            blurRadius: 1.5 * scale,
          ),
        ],
      ),
    );

    final origin = Offset(
      center.dx - corePainter.width / 2,
      center.dy - corePainter.height / 2,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Counter-rotate the glyph to keep it vertical; merkstave flips it 180°
    // while the 3D stone body & top-left lighting remain naturally upright.
    final angle = glyphRotation ?? (merkstave ? math.pi : 0.0);
    canvas.rotate(angle - stoneTilt);
    canvas.translate(-center.dx, -center.dy);

    // 1. Recessed chisel shadow (upper-left offset).
    shadowPainter.paint(
      canvas,
      origin + Offset(-1.25 * scale, -1.45 * scale),
    );
    // 2. Lower groove bevel catch-light (lower-right offset).
    rimPainter.paint(
      canvas,
      origin + Offset(0.95 * scale, 1.15 * scale),
    );
    // 3. Luminous carved glyph core.
    corePainter.paint(canvas, origin);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RuneStonePainter oldDelegate) =>
      oldDelegate.ignite != ignite ||
      oldDelegate.faceUp != faceUp ||
      oldDelegate.stone.id != stone.id ||
      oldDelegate.pack.id != pack.id ||
      oldDelegate.stoneImage != stoneImage ||
      oldDelegate.stoneTilt != stoneTilt ||
      oldDelegate.merkstave != merkstave ||
      oldDelegate.glyphRotation != glyphRotation ||
      oldDelegate.revealing != revealing ||
      oldDelegate.depthShade != depthShade ||
      oldDelegate.lift != lift;
}
