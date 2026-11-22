part of 'spread_board.dart';

enum _DealPhase { dragging, flying, landing, returning }

/// All distances are in the common surface above the dock and viewport.
/// Measuring the portrait card's local x-axis includes RotatedBox and zoom.
class _DealPose {
  const _DealPose(
    this.center,
    this.scale,
    this.angle, {
    this.lift = 0,
    this.tilt = 0,
  });
  final Offset center;
  final double scale;
  final double angle;
  final double lift;
  final double tilt;

  factory _DealPose.measure(RenderBox box, RenderBox surface) {
    final origin = box.localToGlobal(Offset.zero, ancestor: surface);
    final axis =
        box.localToGlobal(Offset(box.size.width, 0), ancestor: surface) -
        origin;
    return _DealPose(
      box.localToGlobal(box.size.center(Offset.zero), ancestor: surface),
      axis.distance / deckWidth,
      axis.direction,
    );
  }

  _DealPose dragged(Offset delta, _DealPose target, double pickup) {
    final distance = math.max(1.0, (target.center - center).distance);
    final t = (1 - (target.center - center - delta).distance / distance).clamp(
      0.0,
      1.0,
    );
    return _DealPose(
      center + delta - Offset(0, 5 * pickup),
      scale + (target.scale - scale) * t,
      angle + (target.angle - angle) * t,
      lift: pickup,
    );
  }

  /// Drive the same lifted card as a drag with a virtual pointer. Both the
  /// target and its rotation are measured in the current viewport each frame.
  _DealPose carriedTo(_DealPose target, double time) {
    final travel = Curves.easeOutQuad.transform(time);
    final lift =
        const Interval(0, .14, curve: Curves.easeOut).transform(time) *
        (1 - const Interval(.78, 1, curve: Curves.easeInOut).transform(time));
    final distance = target.center - center;
    final arc =
        math.min(26.0, distance.distance * .13) * math.sin(math.pi * travel);
    final pose = dragged(distance * travel - Offset(0, arc), target, lift);
    return _DealPose(
      pose.center,
      pose.scale,
      pose.angle,
      lift: lift,
      tilt: slotTiltRadians *
          const Interval(.78, 1, curve: Curves.easeOut).transform(time),
    );
  }

  static _DealPose flight(
    _DealPose start,
    _DealPose end,
    double t, {
    required bool returning,
  }) {
    final p = returning ? t : Curves.easeInOutCubic.transform(t);
    final arc = math.sin(math.pi * p);
    final lift = start.lift * (1 - p) + (returning ? 0 : 0.75 * arc);
    final distance = (end.center - start.center).distance;
    return _DealPose(
      Offset.lerp(start.center, end.center, p)! -
          Offset(0, math.min(22.0, distance * 0.09) * arc),
      start.scale + (end.scale - start.scale) * p,
      start.angle + (end.angle - start.angle) * p,
      lift: lift,
      tilt: returning ? 0 : slotTiltRadians * p,
    );
  }
}

class _MovingCard extends StatelessWidget {
  const _MovingCard({required this.pose, required this.child});
  final _DealPose pose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = pose.scale * (1 + 0.035 * pose.lift);
    return Stack(
      children: [
        Positioned(
          left: pose.center.dx - deckWidth / 2,
          top: pose.center.dy - deckHeight / 2,
          width: deckWidth,
          height: deckHeight,
          child: Transform(
            key: const ValueKey('spread-moving-card'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(pose.angle)
              ..scaleByDouble(scale, scale, scale, 1)
              ..setEntry(3, 2, perspectiveEntry)
              ..rotateX(pose.tilt),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(deckWidth * 0.06),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.15 + 0.10 * pose.lift,
                    ),
                    blurRadius: 2 + 5 * pose.lift,
                    offset: Offset(0, 1 + 3 * pose.lift),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
