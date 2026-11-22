import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../core/models/guide_event.dart';
import '../../../core/models/guide_hint.dart';
import '../../../design_system/taro_tokens.dart';

/// How the guide companion feels about the current moment.
enum GuideMascotMood { idle, hint, celebrate }

/// Maps the mentor's single current hint onto the companion's mood.
///
/// Pure: the widget only reacts, so the mood can be unit-tested without
/// pumping widgets. A finished spread is the only moment worth celebrating —
/// every other actionable hint simply makes the companion point.
GuideMascotMood guideMascotMoodFor(GuideHint? hint) {
  if (hint == null) return GuideMascotMood.idle;
  if (hint.eventType == GuideEventType.spreadCompleted) {
    return GuideMascotMood.celebrate;
  }
  return GuideMascotMood.hint;
}

/// G2 placeholder companion: a procedural four-point star.
///
/// Deliberately not a character — the look/name/personality decision is still
/// open (GUIDED_READING §8). What is already real: it lives inside the hint
/// bar (never over the cards), breathes on an isolated [RepaintBoundary], pops
/// on a spring when the mood changes, respects reduce-motion, and fires a
/// single medium haptic when the spread is finished.
class GuideMascot extends StatefulWidget {
  const GuideMascot({super.key, required this.mood, this.size = 18});

  final GuideMascotMood mood;
  final double size;

  @override
  State<GuideMascot> createState() => _GuideMascotState();
}

class _GuideMascotState extends State<GuideMascot>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced && (reduced || _idle.isAnimating)) return;
    _reduced = reduced;
    if (reduced) {
      _idle.stop();
      _idle.value = .5;
    } else {
      _idle.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GuideMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood == widget.mood) return;
    if (widget.mood == GuideMascotMood.celebrate) {
      HapticFeedback.mediumImpact();
    }
    if (_reduced) return;
    _pop.value = 0;
    _pop.animateWith(SpringSimulation(TaroMotion.spring, 0, 1, 0));
  }

  @override
  void dispose() {
    _idle.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _pop]),
          builder: (context, _) => Transform.scale(
            scale: .72 + .28 * _pop.value,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _StarMascotPainter(
                mood: widget.mood,
                breathe: _reduced ? .5 : _idle.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarMascotPainter extends CustomPainter {
  _StarMascotPainter({required this.mood, required this.breathe});

  final GuideMascotMood mood;
  final double breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.shortestSide / 2;
    final glow = switch (mood) {
      GuideMascotMood.idle => .26 + .14 * breathe,
      GuideMascotMood.hint => .52 + .22 * breathe,
      GuideMascotMood.celebrate => .92,
    };

    // Lavender halo — the only "light" the companion emits.
    canvas.drawCircle(
      centre,
      radius * (.78 + .1 * breathe),
      Paint()
        ..color = TaroColors.indigo.withValues(alpha: glow * .38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .5),
    );

    canvas.drawPath(
      _sparklePath(rect.deflate(radius * .2), waist: .2),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF4EFFF), TaroColors.lavender, TaroColors.indigo],
          stops: [0, .55, 1],
        ).createShader(rect),
    );

    if (mood == GuideMascotMood.celebrate) {
      canvas.drawPath(
        _sparklePath(
          Rect.fromCircle(
            center: centre + Offset(radius * .72, -radius * .62),
            radius: radius * .18,
          ),
          waist: .18,
        ),
        Paint()..color = TaroColors.dawn.withValues(alpha: .8),
      );
      canvas.drawPath(
        _sparklePath(
          Rect.fromCircle(
            center: centre + Offset(-radius * .68, radius * .66),
            radius: radius * .12,
          ),
          waist: .18,
        ),
        Paint()..color = TaroColors.lavender.withValues(alpha: .7),
      );
    }
  }

  /// Four-point sparkle: a diamond with concave sides.
  Path _sparklePath(Rect rect, {required double waist}) {
    final c = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    final wx = rx * waist;
    final wy = ry * waist;
    return Path()
      ..moveTo(c.dx, c.dy - ry)
      ..quadraticBezierTo(c.dx + wx, c.dy - wy, c.dx + rx, c.dy)
      ..quadraticBezierTo(c.dx + wx, c.dy + wy, c.dx, c.dy + ry)
      ..quadraticBezierTo(c.dx - wx, c.dy + wy, c.dx - rx, c.dy)
      ..quadraticBezierTo(c.dx - wx, c.dy - wy, c.dx, c.dy - ry)
      ..close();
  }

  @override
  bool shouldRepaint(_StarMascotPainter old) =>
      old.mood != mood || (old.breathe - breathe).abs() > .01;
}

