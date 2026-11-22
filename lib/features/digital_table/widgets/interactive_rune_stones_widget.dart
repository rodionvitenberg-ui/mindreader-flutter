import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/runes_data.dart';
import '../../../core/models/divination_card.dart';
import '../../../core/models/rune_pack.dart';
import '../../../core/models/rune_stone.dart';
import '../../../core/theme/card_motion.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import 'rune_stone_3d_widget.dart';

/// The 24 stones still lying in the cluster — the FULL futhark, so the heap
/// visibly shrinks 24 → 23 → 22 … as each cast stone is removed.
const visibleStoneCap = 24;

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
    required this.depth,
  });

  final Offset stoneOffsetLocal;
  final double releaseVelocityPx;

  /// The stone's DEPTH in the shuffled stack (0 = top). Casting removes
  /// exactly this stone from the heap and the controller ledger.
  final int depth;
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

  /// The heap's visual layer order (top stone = last visible entry). Casting
  /// removes the grabbed stone from here so the pile visibly shrinks; a
  /// reset regenerates all 24.
  late List<int> _stoneOrder = List.generate(visibleStoneCap, (i) => i);

  /// Persistent swirl travel — frozen messy heap, never snaps back to zero.
  double _swirl = 0;
  int _lastRemaining = -1;
  int _lastTick = 0;

  // ---- grabbed stone state ----
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
    // Organic heap of 24: 6 staggered columns × 4 rows, seeded jitter.
    final poses = <_StoneRestPose>[];
    for (var i = 0; i < visibleStoneCap; i++) {
      final col = i % 6;
      final row = i ~/ 6;
      poses.add(
        _StoneRestPose(
          dx: (col - 2.5) * 36.0 + _visualRng.nextDouble() * 24 - 12,
          dy: row * 72.0 + _visualRng.nextDouble() * 18 - 6,
          rotZ: (_visualRng.nextDouble() - 0.5) * 0.6,
          scale: 0.9 + _visualRng.nextDouble() * 0.14,
        ),
      );
    }
    return poses;
  }

  int get _visibleCount =>
      math.min(visibleStoneCap, context.read<SpreadController>().remaining);

  /// The actual shuffled rune stone at [depth] (0 = top of the pile). Each
  /// heap stone carries its own identity so the pile shows the REAL runes.
  RuneStone _stoneAtDepth(int depth) {
    final cards = context.read<SpreadController>().remainingDeck;
    if (cards.isEmpty) return elderFuthark[0];
    final idx = depth.clamp(0, cards.length - 1);
    final card = cards[idx];
    return card is RuneDivinationCard ? card.stone : elderFuthark[0];
  }

  void _onSwirlStart(DragStartDetails d) {}

  void _onSwirlUpdate(DragUpdateDetails d) {
    setState(() => _swirl += d.delta.dx);
    final tick = (_swirl.abs() ~/ stoneClatterTickPx);
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.mediumImpact();
      // Stone clatter: swap two ADJACENT stones' rest positions (and layer
      // order) so they genuinely trade places, then re-weave the ledger.
      _swapAdjacentStones();
      context.read<SpreadController>().weaveShuffleRemaining();
    }
  }

  /// Swaps the rest poses + z-order of two neighbouring heap stones so the
  /// pile physically re-arranges rather than just wiggling in place.
  void _swapAdjacentStones() {
    final n = _stoneOrder.length;
    if (n < 2) return;
    final a = _visualRng.nextInt(n - 1);
    final b = a + 1;
    final tmpPose = _restPoses[a];
    _restPoses[a] = _restPoses[b];
    _restPoses[b] = tmpPose;
    final tmpOrder = _stoneOrder[a];
    _stoneOrder[a] = _stoneOrder[b];
    _stoneOrder[b] = tmpOrder;
  }

  void _onSwirlEnd(DragEndDetails d) {
    HapticFeedback.mediumImpact();
  }

  /// Hit-test the concrete stone under the finger, allowing ANY exposed
  /// stone to be grabbed (not only the top one).
  void _onGrabStart(DragStartDetails d) {
    setState(() {
      _grabbedIndex = _pickStoneAt(d.localPosition);
      _grabDelta = Offset.zero;
    });
  }

  int? _pickStoneAt(Offset local) {
    final visible = _visibleCount;
    if (visible == 0) return null;
    // Topmost (last-rendered) stone whose centre is within its radius wins.
    int? best;
    double bestDist = 90 * 90; // stone radius ~45
    for (var i = visible - 1; i >= 0; i--) {
      final pose = _restPoses[_stoneOrder[i] % _restPoses.length];
      final cx = 110 + pose.dx;
      final cy = 78 + pose.dy;
      final d2 =
          (local.dx - cx) * (local.dx - cx) + (local.dy - cy) * (local.dy - cy);
      if (d2 < bestDist) {
        bestDist = d2;
        best = _stoneOrder[i];
      }
    }
    // Fall back to the top stone if nothing is within reach.
    return best ?? _stoneOrder[visible - 1];
  }

  void _onGrabUpdate(DragUpdateDetails d) {
    if (_grabbedIndex == null) return;
    setState(() => _grabDelta += d.delta);
  }

  void _onGrabEnd(DragEndDetails d) {
    final grabbed = _grabbedIndex;
    if (grabbed == null) return;
    _releaseVelocity = d.primaryVelocity ?? 0;
    final pose = _restPoses[grabbed % _restPoses.length];
    final stoneLocal = Offset(pose.dx + 110, pose.dy + 96 + _grabDelta.dy);
    final cast =
        _grabDelta.dy > stoneCastDistancePx ||
        _releaseVelocity > stoneCastVelocityPx;
    if (cast) {
      // The exact grabbed stone is cast: remove it from the visual heap so
      // the pile shrinks by one, and hand off its DEPTH to the parent.
      final depth = _grabbedDepth(grabbed);
      widget.onCastRelease?.call(
        RuneCastReleaseRequest(
          stoneOffsetLocal: stoneLocal,
          releaseVelocityPx: _releaseVelocity,
          depth: depth,
        ),
      );
      setState(() {
        _stoneOrder.remove(grabbed);
        _grabbedIndex = null;
        _grabDelta = Offset.zero;
      });
      return;
    }
    // Spring the stone back into the heap (no cast).
    final start = _grabDelta;
    setState(() {
      _grabbedIndex = null;
      _grabDelta = Offset.zero;
    });
    _returnAnim = _return.drive(
      Tween<Offset>(
        begin: start,
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    _return
      ..reset()
      ..animateWith(SpringSimulation(spring, 0, 1, _releaseVelocity / 300))
          .whenCompleteOrCancel(() => _returnAnim = null);
  }

  /// Depth (0 = top) in the shuffled stack for the stone with heap index
  /// [heapId]. The heap renders stones in shuffled order, so the top-rendered
  /// stone is depth 0 and each cast grabs its real position in the deck.
  int _grabbedDepth(int heapId) {
    final cards = context.read<SpreadController>().remainingDeck;
    if (cards.isEmpty) return 0;
    // The shuffled deck's remaining list is the authoritative order: the
    // heap layer order mirrors it, so depth = the stone's render position.
    final pos = _stoneOrder.indexOf(heapId);
    return pos < 0 ? 0 : pos.clamp(0, cards.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final pack = context.watch<DeckPackController>().activeRunePack;
    final remaining = ctrl.remaining;

    // Table reset detection: remaining jumped back up → regenerate the heap
    // and restore all 24 stones.
    if (_lastRemaining != -1 && remaining > _lastRemaining) {
      _swirl = 0;
      _restPoses = _generatePoses();
      _stoneOrder = List.generate(visibleStoneCap, (i) => i);
      _grabbedIndex = null;
      _grabDelta = Offset.zero;
    }
    _lastRemaining = remaining;

    final visible = math.min(_stoneOrder.length, _visibleCount);
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
                      _stoneOrder[i],
                      pack,
                      renderIndex: i,
                      visibleCount: visible,
                      isGrabbed: _stoneOrder[i] == grabbed,
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

  /// One heap stone: swirl orbit + rest imperfection + cast drag. Each stone
  /// shows its REAL rune identity from the shuffled remaining deck with depth
  /// occlusion beneath upper stones and an expanded lift shadow when grabbed.
  Widget _stoneTile(
    int heapIndex,
    RunePack pack, {
    required int renderIndex,
    required int visibleCount,
    required bool isGrabbed,
    required Offset returnDelta,
  }) {
    final pose = _restPoses[heapIndex % _restPoses.length];
    final phase = heapIndex * 0.55;
    final orbitX = math.sin(_swirl / 24 + phase) * (14 + heapIndex % 4 * 3);
    final orbitY = math.cos(_swirl / 30 + phase) * (5 + heapIndex % 3 * 2);
    final lift = math.max(0, math.sin(_swirl / 20 + phase)) * 10;

    final stone = _stoneAtDepth(heapIndex);
    var dx = 110 + pose.dx + orbitX;
    var dy = 78 + pose.dy + orbitY - lift;
    if (isGrabbed) {
      dy += _grabDelta.dy + returnDelta.dy;
    }
    final size = 88.0 * pose.scale;
    // Lower-rendered stones sit physically beneath upper stones.
    final depthRatio = visibleCount <= 1
        ? 0.0
        : (visibleCount - 1 - renderIndex) / (visibleCount - 1);
    final depthShade = isGrabbed ? 0.0 : depthRatio * 0.44;
    return Positioned(
      left: dx - size / 2,
      top: dy - size / 2,
      child: Transform.rotate(
        angle: pose.rotZ + (isGrabbed ? _grabDelta.dy * 0.0015 : 0),
        child: RuneStoneView(
          stone: stone,
          pack: pack,
          faceUp: false,
          ignite: 0,
          seed: 11 + stone.id,
          depthShade: depthShade,
          lift: isGrabbed ? 1.0 : 0.0,
          width: size,
          height: size * 1.18,
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
