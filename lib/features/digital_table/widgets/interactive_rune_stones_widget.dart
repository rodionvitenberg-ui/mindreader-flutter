import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/runes_data.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import 'rune_stone_3d_widget.dart';

/// The 24 stones still lying in the cluster (visual cap ~14).
const visibleStoneCap = 14;

/// Drag travel (px) that fires one swirl/clatter haptic tick.
const stoneClatterTickPx = 24.0;

/// Downward drag distance / velocity that CASTS the grabbed stone.
const stoneCastDistancePx = 60.0;
const stoneCastVelocityPx = 450.0;

/// One tactile cast: the grabbed stone was released past the threshold.
/// The parent flies the stone from [stoneOffsetLocal] into the slot.
class RuneCastReleaseRequest {
  const RuneCastReleaseRequest({
    required this.stoneOffsetLocal,
    required this.releaseVelocityPx,
  });

  final Offset stoneOffsetLocal;
  final double releaseVelocityPx;
}

/// The 3D tactile rune stone cluster on the Digital Table: an organic heap
/// of carved pebble-shaped stones (radial obsidian shader, chiseled rim
/// light, deep shadows). Touch-scoped (`HitTestBehavior.opaque`) so its
/// gestures never fight the unified table scroll view:
///
/// * horizontal drag → the heap SWIRLS and clatters in 3D (stones orbit
///   with staggered sine phases) with heavy stone haptics
///   (`HapticFeedback.mediumImpact`) every [stoneClatterTickPx];
/// * downward drag → the TOP stone is grabbed and follows the finger;
///   released past the cast threshold it is handed off via
///   [onCastRelease] and the heap sinks as the ledger depletes.
class InteractiveRuneStonesWidget extends StatefulWidget {
  const InteractiveRuneStonesWidget({
    super.key,
    this.onCastRelease,
    this.randomSeed,
  });

  final void Function(RuneCastReleaseRequest request)? onCastRelease;
  final int? randomSeed;

  @override
  State<InteractiveRuneStonesWidget> createState() =>
      _InteractiveRuneStonesWidgetState();
}

class _InteractiveRuneStonesWidgetState
    extends State<InteractiveRuneStonesWidget>
    with TickerProviderStateMixin {
  late final math.Random _visualRng = math.Random(widget.randomSeed ?? 24);

  /// Per-stone lived-in heap pose: position jitter, rotation, scale.
  late List<_StoneRestPose> _restPoses = _generatePoses();

  /// Persistent swirl travel — frozen messy heap, never snaps back to zero.
  double _swirl = 0;
  int _lastRemaining = -1;
  int _lastTick = 0;

  // ---- grabbed top stone state ----
  int? _grabbedIndex;
  Offset _grabDelta = Offset.zero;
  double _releaseVelocity = 0;

  late final AnimationController _return = AnimationController(vsync: this);
  Animation<Offset>? _returnAnim;

  @override
  void dispose() {
    _return.dispose();
    super.dispose();
  }

  List<_StoneRestPose> _generatePoses() {
    // Organic heap: 5 staggered columns × 3 rows, seeded jitter.
    final poses = <_StoneRestPose>[];
    for (var i = 0; i < visibleStoneCap; i++) {
      final col = i % 5;
      final row = i ~/ 5;
      poses.add(_StoneRestPose(
        dx: (col - 2) * 40.0 + _visualRng.nextDouble() * 26 - 13,
        dy: row * 92.0 + _visualRng.nextDouble() * 22 - 8,
        rotZ: (_visualRng.nextDouble() - 0.5) * 0.6,
        scale: 0.92 + _visualRng.nextDouble() * 0.16,
      ));
    }
    return poses;
  }

  int get _visibleCount =>
      math.min(visibleStoneCap, context.read<SpreadController>().remaining);

  void _onSwirlStart(DragStartDetails d) {}

  void _onSwirlUpdate(DragUpdateDetails d) {
    setState(() => _swirl += d.delta.dx);
    final tick = (_swirl.abs() ~/ stoneClatterTickPx);
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.mediumImpact();
      // Heavy stone clatter: the ledger re-weaves on every tick, exactly
      // like the card deck riffle.
      context.read<SpreadController>().weaveShuffleRemaining();
    }
  }

  void _onSwirlEnd(DragEndDetails d) {
    HapticFeedback.mediumImpact();
  }

  void _onGrabStart(DragStartDetails d) {
    if (_visibleCount == 0) return;
    setState(() {
      _grabbedIndex = _visibleCount - 1; // the top/front stone
      _grabDelta = Offset.zero;
    });
  }

  void _onGrabUpdate(DragUpdateDetails d) {
    if (_grabbedIndex == null) return;
    setState(() => _grabDelta += d.delta);
  }

  void _onGrabEnd(DragEndDetails d) {
    final grabbed = _grabbedIndex;
    if (grabbed == null) return;
    _releaseVelocity = d.primaryVelocity ?? 0;
    final pose = _restPoses[grabbed];
    final stoneLocal = Offset(pose.dx + 110, pose.dy + 96 + _grabDelta.dy);
    final cast = _grabDelta.dy > stoneCastDistancePx ||
        _releaseVelocity > stoneCastVelocityPx;
    if (cast) {
      widget.onCastRelease?.call(RuneCastReleaseRequest(
        stoneOffsetLocal: stoneLocal,
        releaseVelocityPx: _releaseVelocity,
      ));
      setState(() {
        _grabbedIndex = null;
        _grabDelta = Offset.zero;
      });
      return;
    }
    // Spring the stone back into the heap.
    final start = _grabDelta;
    setState(() {
      _grabbedIndex = null;
      _grabDelta = Offset.zero;
    });
    _returnAnim = _return.drive(
      Tween<Offset>(begin: start, end: Offset.zero).chain(
        CurveTween(curve: Curves.easeOutCubic),
      ),
    );
    _return
      ..reset()
      ..animateWith(
        SpringSimulation(spring, 0, 1, _releaseVelocity / 300),
      ).whenCompleteOrCancel(() => _returnAnim = null);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final pack = context.watch<DeckPackController>().activeRunePack;
    final remaining = ctrl.remaining;

    // Table reset detection: remaining jumped back up → regenerate the heap.
    if (_lastRemaining != -1 && remaining > _lastRemaining) {
      _swirl = 0;
      _restPoses = _generatePoses();
      _grabbedIndex = null;
      _grabDelta = Offset.zero;
    }
    _lastRemaining = remaining;

    final visible = _visibleCount;
    final grabbed = _grabbedIndex;
    final returnDelta = _returnAnim?.value ?? Offset.zero;

    return SizedBox(
      width: 220,
      height: 360,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onSwirlStart,
        onHorizontalDragUpdate: _onSwirlUpdate,
        onHorizontalDragEnd: _onSwirlEnd,
        onVerticalDragStart: _onGrabStart,
        onVerticalDragUpdate: _onGrabUpdate,
        onVerticalDragEnd: _onGrabEnd,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _return,
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < visible; i++)
                    _stoneTile(
                      i,
                      pack,
                      isGrabbed: i == grabbed,
                      returnDelta: returnDelta,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// One heap stone: swirl orbit + rest imperfection + cast drag.
  Widget _stoneTile(
    int i,
    RunePack pack, {
    required bool isGrabbed,
    required Offset returnDelta,
  }) {
    final pose = _restPoses[i];
    final phase = i * 0.55;
    final orbitX = math.sin(_swirl / 24 + phase) * (14 + i % 4 * 3);
    final orbitY = math.cos(_swirl / 30 + phase) * (5 + i % 3 * 2);
    final lift = math.max(0, math.sin(_swirl / 20 + phase)) * 10;

    var dx = 110 + pose.dx + orbitX;
    var dy = 78 + pose.dy + orbitY - lift;
    if (isGrabbed) {
      dx += 0;
      dy += _grabDelta.dy + returnDelta.dy;
    }
    final size = 88.0 * pose.scale;
    return Positioned(
      left: dx - size / 2,
      top: dy - size / 2,
      child: Transform.rotate(
        angle: pose.rotZ + (isGrabbed ? _grabDelta.dy * 0.0015 : 0),
        child: CustomPaint(
          size: Size(size, size * 1.18),
          painter: RuneStonePainter(
            stone: elderFuthark[0],
            pack: pack,
            faceUp: false,
            ignite: 0,
            seed: 11 + i,
          ),
        ),
      ),
    );
  }
}

/// Lived-in resting imperfection of one heap stone.
class _StoneRestPose {
  const _StoneRestPose({
    required this.dx,
    required this.dy,
    required this.rotZ,
    required this.scale,
  });

  final double dx;
  final double dy;
  final double rotZ;
  final double scale;
}
