import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/element_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import 'natal_wheel_geometry.dart';

/// Harmonious chord gradient (trine 120° / sextile 60°).
const wheelHarmonyStart = Color(0xFF38BDF8);
const wheelHarmonyEnd = Color(0xFF34D399);

/// Tense chord gradient (square 90° / opposition 180°).
const wheelTenseStart = Color(0xFFFB7185);
const wheelTenseEnd = Color(0xFFF59E0B);

/// Single accent color for a chord's type (inspector rows).
Color aspectAccentColor(AspectType type) => switch (type.harmony) {
  AspectHarmony.harmonious => wheelHarmonyStart,
  AspectHarmony.tense => wheelTenseStart,
  AspectHarmony.intense => TaroColors.lavender,
};

/// Stagger of the Stage-4 aspect flashes (0.72 -> 1.00): every chord shoots
/// one by one, capped so any chart finishes inside the 2200 ms window.
double aspectFlashStep(int aspectCount) =>
    aspectCount <= 0 ? 0.0 : math.min(0.02, 0.26 / aspectCount);

double aspectFlashBegin(int index, int aspectCount) =>
    0.72 + index * aspectFlashStep(aspectCount);

/// One eased sub-window of the choreography timeline.
double _window(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeOutCubic,
]) {
  final span = end - begin;
  if (span <= 0) return t >= end ? 1.0 : 0.0;
  return curve.transform(((t - begin) / span).clamp(0.0, 1.0));
}

/// GPU-composited natal wheel: zodiac ring, house grid, planet orbit and
/// flashing aspect chords. Repaints are driven by `Listenable.merge` over the
/// choreography, the idle pulse and the house morph — never by layout.
class NatalWheelPainter extends CustomPainter {
  NatalWheelPainter({
    required this.chart,
    required this.ascendantLongitude,
    required this.houseCusps,
    required this.choreography,
    required this.pulse,
    required this.houseMorph,
    required this.siderealTimeDegrees,
    this.selectedPlanet,
    this.transitLongitudes,
  }) : super(repaint: Listenable.merge([choreography, pulse, houseMorph]));

  final NatalChart chart;

  /// Ecliptic longitude of the Ascendant — pinned to the 9 o'clock horizon.
  final double ascendantLongitude;

  /// Cusps currently displayed (morphed during a house-system switch).
  final List<double> houseCusps;

  final Animation<double> choreography;
  final Animation<double> pulse;
  final Animation<double> houseMorph;

  /// Birth local sidereal time in degrees (Stage-1 HUD readout).
  final double siderealTimeDegrees;

  final PlanetId? selectedPlanet;

  /// Today's transiting longitudes on the outer hairline ring, when the
  /// LIVE TRANSITS OVERLAY is on.
  final Map<PlanetId, double>? transitLongitudes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = wheelRadius(size);
    if (radius <= 0) return;
    final t = choreography.value;
    final ringSpin = (1 - _window(t, 0.0, 0.30)) * -0.55;

    _paintBackdrop(canvas, center, radius);
    _paintZodiacRing(canvas, center, radius, t, ringSpin);
    if (chart.timeKnown) _paintHouseGrid(canvas, center, radius, t);
    final anchors = _paintPlanets(canvas, center, radius, t);
    _paintAspects(canvas, t, anchors);
    _paintTransits(canvas, center, radius);
    _paintCenter(canvas, center, t);
  }

  // ---- backdrop -------------------------------------------------------

  void _paintBackdrop(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TaroColors.lavender.withValues(alpha: 0.10),
            const Color(0x0009090D),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    _hairlineCircle(canvas, center, radius, 0.16);
    _hairlineCircle(canvas, center, radius * wheelRingInnerFactor, 0.10);
    _hairlineCircle(canvas, center, radius * wheelCoreFactor, 0.12);
  }

  void _hairlineCircle(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = TaroColors.lavender.withValues(alpha: alpha),
    );
  }
  // ---- Stage 1: zodiac ring calibration ------------------------------

  void _paintZodiacRing(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double spin,
  ) {
    final outer = radius;
    final inner = radius * wheelRingInnerFactor;
    final s1 = _window(t, 0.0, 0.30);
    const sweepRad = -math.pi / 6; // 30° counter-clockwise

    for (var i = 0; i < 12; i++) {
      final accent = ZodiacSign.values[i].element.accent;
      final start = chartScreenAngle(i * 30.0, ascendantLongitude) + spin;
      final band = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: outer),
          start,
          sweepRad,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: inner),
          start + sweepRad,
          -sweepRad,
          false,
        )
        ..close();
      canvas.drawPath(
        band,
        Paint()
          ..style = PaintingStyle.fill
          ..color = accent.withValues(alpha: 0.045 + 0.04 * s1),
      );
      canvas.drawPath(
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = accent.withValues(alpha: 0.16 + 0.12 * s1),
      );
    }

    // Degree ticks every 1° / 5° / 10°, hugging the outer rim.
    final minor = Path();
    final medium = Path();
    final major = Path();
    for (var deg = 0; deg < 360; deg++) {
      final angle = chartScreenAngle(deg.toDouble(), ascendantLongitude) + spin;
      final length = deg % 10 == 0 ? 8.0 : (deg % 5 == 0 ? 4.5 : 2.0);
      final from = pointOnCircle(center, outer - 1.5, angle);
      final to = pointOnCircle(center, outer - 1.5 - length, angle);
      final target = deg % 10 == 0 ? major : (deg % 5 == 0 ? medium : minor);
      target
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
    }
    canvas.drawPath(minor, _tickPaint(0.10 + 0.08 * s1));
    canvas.drawPath(medium, _tickPaint(0.22 + 0.10 * s1));
    canvas.drawPath(major, _tickPaint(0.34 + 0.12 * s1));

    // ♈..♓ glyphs on the band's mid-track.
    for (var i = 0; i < 12; i++) {
      final sign = ZodiacSign.values[i];
      final angle =
          chartScreenAngle(i * 30.0 + 15.0, ascendantLongitude) + spin;
      final tp = _text(
        sign.glyph,
        size: 13,
        color: TaroColors.textPrimary.withValues(alpha: 0.45 + 0.55 * s1),
      );
      final pos = pointOnCircle(center, (outer + inner) / 2, angle);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  Paint _tickPaint(double alpha) => Paint()
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round
    ..color = TaroColors.lavender.withValues(alpha: alpha);
  // ---- Stage 2: house grid sweep + live morph -------------------------

  void _paintHouseGrid(Canvas canvas, Offset center, double radius, double t) {
    final rInner = radius * wheelCoreFactor;
    final rOuter = radius * wheelHouseOuterFactor;
    final rLabel = radius * wheelHouseLabelFactor;
    const axisLabels = [
      'ASC',
      '',
      '',
      'IC',
      '',
      '',
      'DSC',
      '',
      '',
      'MC',
      '',
      '',
    ];

    for (var i = 0; i < 12; i++) {
      final cusp = i < houseCusps.length
          ? houseCusps[i]
          : ascendantLongitude + i * 30.0;
      final begin = 0.25 + i * 0.018;
      final progress = _window(t, begin, 0.42 + i * 0.018);
      if (progress <= 0) continue;

      final target = chartScreenAngle(cusp, ascendantLongitude);
      final angle = math.pi + shortestAngleDelta(math.pi, target) * progress;
      final isAxis = i == 0 || i == 3 || i == 6 || i == 9;
      final color = switch (i) {
        0 || 6 => TaroColors.lavender,
        3 || 9 => TaroColors.indigo,
        _ => TaroColors.lavender,
      };
      canvas.drawLine(
        pointOnCircle(center, rInner, angle),
        pointOnCircle(center, rOuter, angle),
        Paint()
          ..color = color.withValues(alpha: (isAxis ? 0.55 : 0.22) * progress)
          ..strokeWidth = isAxis ? 1.5 : 0.7,
      );

      final label = axisLabels[i];
      if (isAxis && label.isNotEmpty) {
        final tp = _text(
          label,
          size: 7,
          color: color.withValues(alpha: 0.75 * progress),
          letterSpacing: 1.2,
        );
        final pos = pointOnCircle(center, rLabel, angle);
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // H1..H12 captions once the grid has swept open.
    final captions = _window(t, 0.55, 0.64);
    if (captions <= 0.01) return;
    for (var i = 0; i < 12; i++) {
      final cusp = i < houseCusps.length
          ? houseCusps[i]
          : ascendantLongitude + i * 30.0;
      final next = i + 1 < houseCusps.length ? houseCusps[i + 1] : cusp + 30.0;
      final mid = lerpLongitude(cusp, next, 0.5);
      final angle = chartScreenAngle(mid, ascendantLongitude);
      final tp = _text(
        'H${i + 1}',
        size: 7,
        color: TaroColors.textSecondary.withValues(alpha: 0.4 * captions),
        letterSpacing: 1.0,
      );
      final pos = pointOnCircle(center, radius * wheelHouseNumberFactor, angle);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }
  // ---- Stage 3: planetary orbit lock-on -------------------------------

  Map<PlanetId, Offset> _paintPlanets(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
  ) {
    final rPlanet = radius * wheelPlanetFactor;
    final rAspect = radius * wheelAspectFactor;
    final anchors = <PlanetId, Offset>{
      for (final p in chart.planets)
        p.planet: pointOnCircle(
          center,
          rAspect,
          chartScreenAngle(p.longitude, ascendantLongitude),
        ),
    };

    final bodies = [
      for (final p in chart.planets)
        if (p.planet.isBody && (chart.timeKnown || p.planet != PlanetId.moon))
          p,
    ];
    final display = resolveCollisions([for (final p in bodies) p.longitude]);
    final pulsePhase = pulse.value * 2 * math.pi;

    for (var i = 0; i < bodies.length; i++) {
      final body = bodies[i];
      final begin = 0.50 + i * 0.028;
      final ignite = _window(t, begin, begin + 0.10);
      if (ignite <= 0) continue;

      final angle = chartScreenAngle(display[i], ascendantLongitude);
      final pos = pointOnCircle(center, rPlanet, angle);
      anchors[body.planet] = pointOnCircle(center, rAspect, angle);

      final dim = selectedPlanet != null && selectedPlanet != body.planet
          ? 0.35
          : 1.0;
      final isSelected = selectedPlanet == body.planet;

      // Soft radial halo pulse.
      final halo = 10.0 + 4.0 * math.sin(pulsePhase + i * 1.7);
      canvas.drawCircle(
        pos,
        halo,
        Paint()
          ..color = TaroColors.lavender.withValues(alpha: 0.12 * ignite * dim)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Node disc + hairline ring.
      canvas.drawCircle(
        pos,
        9.0,
        Paint()..color = TaroColors.background.withValues(alpha: 0.92 * ignite),
      );
      canvas.drawCircle(
        pos,
        9.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 1.6 : 0.9
          ..color = (isSelected ? TaroColors.lavender : TaroColors.mist.withValues(alpha: TaroOpacity.borderStrong))
              .withValues(
                alpha: (isSelected ? 0.95 : 0.5 + 0.3 * dim) * ignite,
              ),
      );
      final glyph = _text(
        body.planet.glyph,
        size: 10.5,
        color: TaroColors.textPrimary.withValues(
          alpha: (0.55 + 0.45 * dim) * ignite,
        ),
      );
      glyph.paint(canvas, pos - Offset(glyph.width / 2, glyph.height / 2));

      if (body.isRetrograde) {
        final rx = _text(
          'Rx',
          size: 6,
          color: TaroColors.textSecondary.withValues(alpha: 0.9 * ignite),
        );
        rx.paint(canvas, pos + const Offset(5, -13));
      }

      // Radial tick at the TRUE longitude (the node itself is nudged).
      final tickAngle = chartScreenAngle(body.longitude, ascendantLongitude);
      canvas.drawLine(
        pointOnCircle(center, radius * wheelHouseOuterFactor, tickAngle),
        pointOnCircle(center, rPlanet + 10.0, tickAngle),
        Paint()
          ..color = TaroColors.lavender.withValues(alpha: 0.22 * ignite)
          ..strokeWidth = 0.7,
      );
    }
    return anchors;
  }
  // ---- Stage 4: flashing aspect chords + living pulse -----------------

  void _paintAspects(Canvas canvas, double t, Map<PlanetId, Offset> anchors) {
    final aspects = chart.aspects;
    for (var k = 0; k < aspects.length; k++) {
      final aspect = aspects[k];
      final from = anchors[aspect.bodyA];
      final to = anchors[aspect.bodyB];
      if (from == null || to == null) continue;

      final begin = aspectFlashBegin(k, aspects.length);
      final flash = _window(t, begin, math.min(begin + 0.08, 1.0));
      if (flash <= 0) continue;

      final connected =
          selectedPlanet == null ||
          aspect.bodyA == selectedPlanet ||
          aspect.bodyB == selectedPlanet;
      final (start, end) = _chordColors(aspect.type);
      final alpha =
          (0.20 + 0.45 * aspect.strength) * (connected ? 1.0 : 0.12) * flash;

      // Outer luminous aura.
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = Color.lerp(start, end, 0.5)!.withValues(alpha: alpha * 0.45)
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      // Crisp gradient core.
      canvas.drawLine(
        from,
        to,
        Paint()
          ..shader = LinearGradient(colors: [start, end])
              .createShader(Rect.fromPoints(from, to))
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = 0.8 + 1.4 * aspect.strength,
      );

      if (flash < 1.0) {
        // The bolt head shooting across the abyss.
        final head = Offset.lerp(from, to, flash)!;
        canvas.drawCircle(
          head,
          4.5,
          Paint()
            ..color = Color.lerp(
              start,
              end,
              flash,
            )!.withValues(alpha: 0.3 + 0.6 * (1 - flash))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      } else if (connected) {
        // Idle energy particles gliding along the live chord.
        for (final offset in const [0.0, 0.34, 0.68]) {
          final s = (pulse.value + offset + k * 0.13) % 1.0;
          final dot = Offset.lerp(from, to, s)!;
          canvas.drawCircle(
            dot,
            2.0,
            Paint()
              ..color = Color.lerp(start, end, s)!.withValues(alpha: 0.75)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }
  }

  (Color, Color) _chordColors(AspectType type) => switch (type.harmony) {
    AspectHarmony.harmonious => (wheelHarmonyStart, wheelHarmonyEnd),
    AspectHarmony.tense => (wheelTenseStart, wheelTenseEnd),
    AspectHarmony.intense => (TaroColors.lavender, TaroColors.indigo),
  };

  // ---- LIVE TRANSITS OVERLAY ------------------------------------------

  void _paintTransits(Canvas canvas, Offset center, double radius) {
    final transits = transitLongitudes;
    if (transits == null || transits.isEmpty) return;
    final r = radius * wheelTransitFactor;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = TaroColors.indigo.withValues(alpha: 0.35),
    );
    transits.forEach((planet, longitude) {
      final angle = chartScreenAngle(longitude, ascendantLongitude);
      final pos = pointOnCircle(center, r, angle);
      canvas.drawCircle(
        pos,
        5.5,
        Paint()
          ..color = TaroColors.lavender.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        pos,
        3.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = TaroColors.indigo.withValues(alpha: 0.9),
      );
      final tp = _text(
        planet.glyph,
        size: 6,
        color: TaroColors.lavender.withValues(alpha: 0.85),
      );
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });
  }
  // ---- center: Stage-1 HUD, then the chart core -----------------------

  void _paintCenter(Canvas canvas, Offset center, double t) {
    final breathe = 0.5 + 0.5 * math.sin(pulse.value * 2 * math.pi);
    canvas.drawCircle(
      center,
      2.2 + 1.2 * breathe,
      Paint()..color = TaroColors.lavender.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      center,
      7.0 + 3.0 * breathe,
      Paint()
        ..color = TaroColors.lavender.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final intro = _window(t, 0.30, 0.42);
    if (chart.timeKnown && intro > 0.01) {
      final sign = ZodiacSignX.fromLongitude(ascendantLongitude);
      final asc = _text(
        '${sign.glyph} ${_formatDegree(ascendantLongitude)}',
        size: 9,
        color: TaroColors.textPrimary.withValues(alpha: 0.9 * intro),
        letterSpacing: 1.2,
      );
      asc.paint(canvas, Offset(center.dx - asc.width / 2, center.dy - 26));
      final system = _text(
        chart.houseSystem.label,
        size: 7,
        color: TaroColors.textSecondary.withValues(alpha: 0.9 * intro),
        letterSpacing: 1.8,
      );
      system.paint(
        canvas,
        Offset(center.dx - system.width / 2, center.dy + 12),
      );
      final tag = _text(
        'ASC',
        size: 6,
        color: TaroColors.lavender.withValues(alpha: 0.8 * intro),
        letterSpacing: 1.6,
      );
      tag.paint(canvas, Offset(center.dx - tag.width / 2, center.dy + 24));
    }

    if (chart.timeKnown) _paintHud(canvas, center, t);
  }

  void _paintHud(Canvas canvas, Offset center, double t) {
    final alpha = 1 - _window(t, 0.26, 0.40);
    if (alpha <= 0.01) return;

    final lat = chart.latitude;
    final lon = chart.longitude;
    final lines = [
      'LAT ${lat.abs().toStringAsFixed(2)}° ${lat >= 0 ? 'N' : 'S'}',
      'LON ${lon.abs().toStringAsFixed(2)}° ${lon >= 0 ? 'E' : 'W'}',
      'SID ${_siderealClock(siderealTimeDegrees)}',
    ];
    var y = center.dy - 38.0;
    for (final line in lines) {
      final tp = _text(
        line,
        size: 8,
        color: TaroColors.textPrimary.withValues(alpha: 0.85 * alpha),
        letterSpacing: 1.6,
      );
      tp.paint(canvas, Offset(center.dx - tp.width / 2, y));
      y += 13;
    }
    final percent = (t / 0.30).clamp(0.0, 1.0) * 100;
    final status = _text(
      'CALIBRATING ${percent.round().toString().padLeft(3, '0')}%',
      size: 7,
      color: TaroColors.lavender.withValues(alpha: alpha),
      letterSpacing: 1.4,
    );
    status.paint(canvas, Offset(center.dx - status.width / 2, y + 2));
  }

  // ---- helpers --------------------------------------------------------

  String _formatDegree(double longitude) {
    final sign = ZodiacSignX.fromLongitude(longitude);
    final inSign = norm360(longitude) - sign.index * 30.0;
    final whole = inSign.floor();
    final minutes = ((inSign - whole) * 60).floor();
    return '$whole°${minutes.toString().padLeft(2, '0')}′';
  }

  /// Degrees of sidereal time as a `hh:mm:ss` clock.
  String _siderealClock(double degrees) {
    final total = ((norm360(degrees) / 15.0) * 3600).round() % 86400;
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  TextPainter _text(
    String text, {
    required double size,
    required Color color,
    double letterSpacing = 0,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: AppTypography.label(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant NatalWheelPainter oldDelegate) {
    if (!identical(oldDelegate.chart, chart)) return true;
    if (oldDelegate.ascendantLongitude != ascendantLongitude) return true;
    if (oldDelegate.siderealTimeDegrees != siderealTimeDegrees) return true;
    if (oldDelegate.selectedPlanet != selectedPlanet) return true;
    if (oldDelegate.transitLongitudes != transitLongitudes) return true;
    if (oldDelegate.houseCusps.length != houseCusps.length) return true;
    for (var i = 0; i < houseCusps.length; i++) {
      if (oldDelegate.houseCusps[i] != houseCusps[i]) return true;
    }
    return false;
  }
}
