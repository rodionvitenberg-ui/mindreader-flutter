import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/models/tarot_deck_pack.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/card_motion.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import 'deal_lock_prompt.dart';
import 'foil_glint.dart';
import 'shuffle_physics.dart';
import 'tarot_card_3d_widget.dart';

/// The hero 3D deck: a real 78-layer physical stack, touch-scoped
/// (`HitTestBehavior.opaque`) so its gestures never fight the unified table
/// scroll view:
///
/// * horizontal drag → uncompromised multi-card riffle: up to 20 REAL card
///   layers individually articulated in 3D under the permanent isometric
///   table camera (perspective 0.0014 + rotateX 0.16), staggered sine
///   phases, cascading and interleaving. Haptic + `Random.secure()`
///   permutation every 18 px;
/// * release → the exact finger-release pose is BAKED as the new permanent
///   rest state in the same frame (at most an 80ms ease-out micro-damp
///   FORWARD along the release velocity) — the cards NEVER spring/roll
///   backward toward a previous pose, and the interleaved layer order is
///   kept;
/// * every card layer carries a persistent lived-in resting imperfection
///   (`CardRestPose`: dx ±6, dy ±3, rotZ ±0.045 rad) so even an untouched
///   deck sits unevenly, with individual edges peeking out;
/// * vertical drag → TRUE TOP-CARD EXTRACTION: the finger translation is
///   applied DIRECTLY to the topmost rendered card layer
///   ([topVisibleLayer] = the last visible entry of the paint order,
///   starting from its exact shuffled rest pose) — no spawned proxy card.
///   Pulling it down immediately exposes the card beneath. Released past
///   the deal threshold, the true top card of the shuffled deck
///   (depth 0) is handed off via [onDealRelease], the exposed second card
///   is promoted to the new top of the paint order, and the rendered stack
///   sinks proportionally (`deckTopCardDy(remaining/78)`), so the user
///   physically sees and feels the deck thinning with every draw.
class InteractiveDeckWidget extends StatefulWidget {
  const InteractiveDeckWidget({
    super.key,
    this.onDealRelease,
    this.randomSeed,
  });

  /// Fired when a grabbed card is released past the deal threshold. The
  /// parent plays the single continuous flight into the target slot.
  final void Function(DeckDealReleaseRequest request)? onDealRelease;

  /// Test-only: pins the organic rest-pose RNG for deterministic layouts.
  final int? randomSeed;

  @override
  State<InteractiveDeckWidget> createState() => _InteractiveDeckWidgetState();
}

class _InteractiveDeckWidgetState extends State<InteractiveDeckWidget>
    with TickerProviderStateMixin {
  late final math.Random _visualRng = math.Random(widget.randomSeed);

  /// Persistent lived-in imperfection of every visible layer — generated
  /// once and regenerated only when the table is reset.
  late final List<CardRestPose> _restPoses =
      generateOrganicRestPoses(count: fanLayerCount, rng: _visualRng);

  // ---- persistent shuffle state ----
  double _travel = 0; // signed drag travel (at rest after the last release)
  double _restTravel = 0; // frozen messy fan — NEVER resets to zero
  double _sign = 1;
  int _lastTick = 0;
  bool _shuffling = false; // finger is down
  bool _settling = false; // settling into the NEW organic arrangement

  /// Paint order of the fan layers (first = back). Weave ticks swap
  /// adjacent entries so cards visibly interleave; the interleaved order
  /// persists across releases — the exact shuffled arrangement stays.
  final List<int> _layerOrder = List.generate(fanLayerCount, (i) => i);

  // ---- grab/deal state ----
  int? _grabbedLayer; // physical layer index under the finger (null = none)
  Offset _dragDelta = Offset.zero; // finger-driven offset, deck-local
  double _dragDown = 0; // total downward travel of the current grab
  bool _returning = false; // un-dealt card springing back into the stack

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: microDampDuration,
  );
  late final AnimationController _return = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// Overhand arc played by the 1–2 layers that just travelled from the top
  /// of the fan to the bottom of the stack (150 ms, GPU transforms only).
  late final AnimationController _overhand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  /// Layers currently mid-arc — painted ON TOP while they travel, then
  /// dropped behind the fan when the cycle completes.
  final Set<int> _cycling = {};

  int _lastRemaining = -1;

  @override
  void dispose() {
    _settle.dispose();
    _return.dispose();
    _overhand.dispose();
    super.dispose();
  }

  /// One weave tick: the top 1–2 VISIBLE layers arc over the fan and are
  /// physically moved to the BACK/BOTTOM of the paint order, so the reader
  /// sees the real top card tuck underneath the stack and a fresh card
  /// surface on top. The remaining deck is then permuted with
  /// `Random.secure()` in the controller.
  void _interleave() {
    final visible = _layerOrder.where((l) => l < _visibleCount).toList();
    if (visible.length < 2) return;
    final count = math.min(2, visible.length);
    final moving = visible.sublist(visible.length - count);
    for (final layer in moving) {
      _layerOrder.remove(layer);
    }
    _layerOrder.insertAll(0, moving.reversed);
    setState(() {
      _cycling
        ..clear()
        ..addAll(moving);
    });
    _overhand.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || _overhand.isAnimating) return;
      setState(_cycling.clear);
    });
    context.read<SpreadController>().weaveShuffleRemaining();
  }

  int get _visibleCount {
    final remaining = context.read<SpreadController>().remaining;
    return math.max(0, math.min(fanLayerCount, remaining));
  }

  /// Effective pose of one layer: fan choreography + its organic rest pose.
  FanLayerPose _poseOf(int layer, int visibleCount, double travel) =>
      FanLayerPose.of(
        layer: layer,
        count: visibleCount,
        travel: travel,
        sign: _sign,
      ).withRest(_restPoses[layer % _restPoses.length]);

  // ---- shuffle gestures (touch-scoped to the deck only) ----

  void _onShuffleStart(DragStartDetails d) {
    if (_grabbedLayer != null || _returning) return;
    _settle.stop();
    setState(() {
      // Interrupting a running micro-damp: bake its current pose first so
      // the fan never teleports back to a stale value.
      if (_settling) _travel = _restTravel;
      _shuffling = true;
      _settling = false;
      _lastTick = _travel.abs() ~/ weaveTickPx;
    });
  }

  void _onShuffleUpdate(DragUpdateDetails d) {
    if (!_shuffling) return;
    setState(() => _travel += d.delta.dx);
    final tick = _travel.abs() ~/ weaveTickPx;
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick(); // weave tick every 18 px
      _interleave();
    }
  }

  void _onShuffleEnd(DragEndDetails d) {
    if (!_shuffling) return;
    _shuffling = false;
    // BAKE THE EXACT FINGER-RELEASE POSE as the new permanent rest state.
    // No reverse/settle spring toward the old pose — where the finger lifts
    // is where the cards stay. At most an 80ms ease-out micro-damp drifts
    // the fan FORWARD along the release velocity; it never moves backward.
    final velocityX = d.velocity.pixelsPerSecond.dx;
    final forwardDrift =
        velocityX * _sign > 0 ? (velocityX.abs() * 0.08).clamp(0.0, 18.0) : 0.0;
    final target = (_travel + _sign * forwardDrift)
        .clamp(-fullSeparationPx, fullSeparationPx);
    _sign = dragSignOf(_travel);
    final from = separationOf(_travel);
    final to = separationOf(target);
    if (to > from) {
      _restTravel = target;
      setState(() => _settling = true);
      HapticFeedback.mediumImpact();
      _settle
          .animateWith(ShuffleMicroDamp(from: from, to: to))
          .whenCompleteOrCancel(() {
        if (!mounted) return;
        setState(() {
          _settling = false;
          _travel = _restTravel; // the baked pose becomes the new rest
        });
      });
    } else {
      // Exact bake in the same frame — zero animation, zero rollback.
      _restTravel = _travel;
      setState(() {});
      HapticFeedback.mediumImpact();
    }
  }

  // ---- true top-card extraction (vertical drag, touch-scoped) ----

  void _onGrabStart(DragStartDetails d) {
    if (_shuffling || _settling || _grabbedLayer != null || _returning) {
      return;
    }
    final visible = _visibleCount;
    if (visible <= 0) return;
    // The finger ALWAYS lifts the actual top card: the topmost rendered
    // layer in the paint order. No hit-test picking, no proxy spawn.
    final layer = topVisibleLayer(_layerOrder, visible);
    setState(() {
      _grabbedLayer = layer;
      _dragDelta = Offset.zero;
      _dragDown = 0;
    });
    HapticFeedback.selectionClick();
  }

  void _onGrabUpdate(DragUpdateDetails d) {
    if (_grabbedLayer == null || _returning) return;
    setState(() {
      _dragDelta += d.delta; // 1:1 finger tracking
      _dragDown += d.delta.dy;
    });
  }

  void _onGrabEnd(DragEndDetails d) {
    final layer = _grabbedLayer;
    if (layer == null || _returning) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final ctrl = context.read<SpreadController>();
    if ((_dragDown > 60 || velocity > 450) && ctrl.isDealLocked) {
      // The deck is locked (base spread complete, no clarifier armed):
      // refuse the draw with a subtle haptic/visual prompt and spring the
      // card back — the whole deck must never dump onto the table.
      _springCardBack(velocity);
      showDealLockPrompt(context, ctrl);
      return;
    }
    if (_dragDown > 60 || velocity > 450) {
      // Hand the TRUE top card of the shuffled deck to the parent: the
      // single continuous flight starts at the finger's release position
      // (no proxy, no pop). The exposed second card is promoted to the new
      // top: the dealt layer is buried at the back of the paint order.
      final remaining = ctrl.remaining;
      final visible = _visibleCount;
      final request = DeckDealReleaseRequest(
        depth: 0, // the actual top card
        cardOffsetLocal:
            Offset(0, deckTopCardDy(remaining, totalCards: ctrl.totalCards) +
                    layer * layerThicknessPx) +
                _dragDelta,
        pose: _poseOf(layer, visible, _travel),
        releaseVelocityPx: velocity,
      );
      setState(() {
        _layerOrder.remove(layer);
        _layerOrder.insert(0, layer);
        _grabbedLayer = null;
        _dragDelta = Offset.zero;
        _dragDown = 0;
      });
      HapticFeedback.mediumImpact();
      widget.onDealRelease?.call(request);
    } else {
      // Released below the threshold: spring the card back into its slot.
      _springCardBack(velocity);
    }
  }

  /// The grabbed card slides back into the stack (un-dealt grab).
  void _springCardBack(double velocity) {
    final start = _dragDelta;
    setState(() => _returning = true);
    _return
        .animateWith(SpringSimulation(
          spring,
          1,
          0,
          velocity / (start.distance + 1),
        ))
        .whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() {
        _returning = false;
        _grabbedLayer = null;
        _dragDelta = Offset.zero;
        _dragDown = 0;
      });
    });
  }

  // ---- rendering ----

  /// One individually articulated fan layer under the permanent table
  /// camera: real card + specular glint over its resting stack offset.
  /// When [layer] is the grabbed card, the finger's drag translation is
  /// applied DIRECTLY to this same layer (lifted translateZ +26, lavender
  /// glow) — the actual top card moves, no proxy is ever spawned.
  /// [tarotPack] is null while the LENORMAND system is active — the back
  /// then uses the active Lenormand pack's procedural pattern.
  Widget _fanLayer(
    int layer,
    int visibleCount,
    double travel,
    TarotDeckPack? tarotPack, {
    required int remaining,
    required int totalCards,
  }) {
    final pose = _poseOf(layer, visibleCount, travel);
    final baseDy = deckTopCardDy(remaining, totalCards: totalCards) +
        layer * layerThicknessPx;
    final grabbed = layer == _grabbedLayer;
    final drag = grabbed
        ? (_returning ? _dragDelta * _return.value : _dragDelta)
        : Offset.zero;
    // Overhand arc: outward translateX + translateZ lift + rotateZ, driven
    // by a sine bell so the card leaves and returns to the stack smoothly.
    final arc =
        _cycling.contains(layer) ? math.sin(math.pi * _overhand.value) : 0.0;
    final glintK = 0.35 + 0.65 * (1 - layer / visibleCount);
    return Transform.translate(
      offset: Offset(_sign * 46 * arc, baseDy - 8 * arc) + drag,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateZ(_sign * 0.16 * arc),
        child: Transform(
          alignment: Alignment.center,
          transform: fanMatrixWithCamera(
            pose,
            liftZ: (grabbed ? 26 : 0) + 42 * arc,
          ),
          child: RepaintBoundary(
            child: Stack(
              children: [
                if (grabbed)
                  // Subtle glow + drop shadow under the lifted card.
                  Container(
                    width: deckWidth,
                    height: deckHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(deckWidth * 0.06),
                      boxShadow: [
                        BoxShadow(
                          color: TaroColors.lavender.withValues(alpha: 0.35),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                  ),
                if (tarotPack == null)
                  _LenormandDeckBack()
                else
                  CardBack(
                    width: deckWidth,
                    height: deckHeight,
                    pack: tarotPack,
                  ),
                Positioned.fill(
                  child: FoilGlint(
                    angleY: pose.rotateY,
                    angleX: pose.rotateX,
                    intensity: glintK,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final packs = context.watch<DeckPackController>();
    final tarotPack = ctrl.system == DivinationSystem.tarot
        ? packs.activePack
        : null;
    final remaining = ctrl.remaining;

    // Table reset detection: remaining jumps back up → regenerate the
    // lived-in imperfection and clear the frozen shuffle arrangement.
    if (_lastRemaining != -1 && remaining > _lastRemaining) {
      _settle.stop();
      _return.stop();
      _restTravel = 0;
      _travel = 0;
      _sign = 1;
      _layerOrder
        ..clear()
        ..addAll(List.generate(fanLayerCount, (i) => i));
      _restPoses
        ..clear()
        ..addAll(generateOrganicRestPoses(
          count: fanLayerCount,
          rng: _visualRng,
        ));
      _shuffling = false;
      _settling = false;
      _returning = false;
      _grabbedLayer = null;
      _dragDelta = Offset.zero;
      _overhand.stop();
      _cycling.clear();
    }
    _lastRemaining = remaining;

    final visibleCount = math.min(fanLayerCount, remaining);
    final travel =
        _settling ? _sign * travelForSeparation(_settle.value) : _travel;
    return SizedBox(
      width: deckWidth,
      height: deckBoxHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onShuffleStart,
        onHorizontalDragUpdate: _onShuffleUpdate,
        onHorizontalDragEnd: _onShuffleEnd,
        onVerticalDragStart: _onGrabStart,
        onVerticalDragUpdate: _onGrabUpdate,
        onVerticalDragEnd: _onGrabEnd,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_settle, _return, _overhand]),
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // ONLY the individual rounded cards of the stack are
                  // rendered — on Colors.transparent, clip none. No spine,
                  // headplate, backing rectangle or painter bar above the
                  // top card. The grabbed layer carries its own drag
                  // transform; every other layer stays put underneath.
                  // Layers mid-overhand are painted LAST so their arc
                  // travels visibly over the fan.
                  for (final layer in _layerOrder)
                    if (layer < visibleCount && !_cycling.contains(layer))
                      _fanLayer(
                        layer,
                        visibleCount,
                        travel,
                        tarotPack,
                        remaining: remaining,
                        totalCards: ctrl.totalCards,
                      ),
                  for (final layer in _layerOrder)
                    if (layer < visibleCount && _cycling.contains(layer))
                      _fanLayer(
                        layer,
                        visibleCount,
                        travel,
                        tarotPack,
                        remaining: remaining,
                        totalCards: ctrl.totalCards,
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The active Lenormand pack's procedural back — reused by every fan layer
/// while the LENORMAND system owns the table deck.
class _LenormandDeckBack extends StatelessWidget {
  const _LenormandDeckBack();

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activeLenormandPack;
    return CardBack(
      width: deckWidth,
      height: deckHeight,
      styleOverride: pack.backStyle,
      accentOverride: pack.backAccentArgb,
      secondaryOverride: pack.backSecondaryArgb,
    );
  }
}
