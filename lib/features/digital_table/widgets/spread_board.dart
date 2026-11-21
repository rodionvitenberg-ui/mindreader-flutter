import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/spread_type.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/card_motion.dart';
import '../../../core/theme/element_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import '../../profile/widgets/profile_header.dart';
import 'deal_lock_prompt.dart';
import 'shuffle_physics.dart';
import 'slotted_divination_card.dart';
import 'spread_deck_dock.dart';
import 'reading_guide.dart';
import 'spread_threads_layer.dart';
import 'spread_viewport.dart';

part 'spread_deal_motion.dart';

class SpreadBoard extends StatefulWidget {
  const SpreadBoard({
    super.key,
    required this.inspect,
    this.selected,
    required this.header,
    required this.badge,
    required this.onDeal,
  });

  final ValueChanged<int> inspect;
  final int? selected;
  final Widget header;
  final Widget badge;
  final int? Function() onDeal;

  @override
  State<SpreadBoard> createState() => _SpreadBoardState();
}

class _SpreadBoardState extends State<SpreadBoard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _surface = GlobalKey();
  final _deck = GlobalKey();
  final _viewport = GlobalKey<SpreadViewportState>();
  final _slotKeys = <int, GlobalKey>{};
  final _dragDelta = ValueNotifier(Offset.zero);
  late final _motion = AnimationController(vsync: this);
  _DealPhase? _phase;
  int? _index;
  int? _heldCard;
  late int _revision;
  late _DealPose _from;
  Offset _down = Offset.zero;

  RenderBox? _box(GlobalKey? key) =>
      key?.currentContext?.findRenderObject() as RenderBox?;

  _DealPose? _pose(GlobalKey? key) {
    final piece = _box(key);
    final surface = _box(_surface);
    if (piece == null || surface == null || !piece.hasSize) return null;
    return _DealPose.measure(piece, surface);
  }

  int? _next(SpreadController ctrl) => ctrl.isDealLocked || ctrl.remaining == 0
      ? null
      : ctrl.nextEmptySlotIndex ?? ctrl.slots.length;

  bool _begin({Offset? finger}) {
    final ctrl = context.read<SpreadController>();
    final index = _next(ctrl);
    if (_phase != null || index == null) return false;
    final source = _pose(_deck);
    if (source == null || _pose(_slotKeys[index]) == null) return false;
    _viewport.currentState?.bringIntoView(
      _geometryFor(ctrl).slotRects[index].center,
    );
    _from = source;
    _heldCard = ctrl.deckTop.first.id;
    _revision = ctrl.readingRevision;
    _down = finger ?? Offset.zero;
    _dragDelta.value = Offset.zero;
    setState(() {
      _index = index;
      _phase = finger == null ? _DealPhase.landing : _DealPhase.dragging;
    });
    return true;
  }

  void _tap() {
    if (!_begin()) return;
    _land(const Duration(milliseconds: 360));
  }

  void _pickUp(LongPressStartDetails details) {
    if (!_begin(finger: details.globalPosition)) return;
    HapticFeedback.selectionClick();
    _motion.duration = const Duration(milliseconds: 130);
    _motion.forward(from: 0);
  }

  void _move(Offset finger) {
    if (_phase != _DealPhase.dragging) return;
    final surface = _box(_surface)!;
    _dragDelta.value =
        surface.globalToLocal(finger) - surface.globalToLocal(_down);
  }

  bool _visibleAt(Offset global) {
    final hits = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      hits,
      global,
      View.of(context).viewId,
    );
    final viewport = _box(_viewport);
    return hits.path.any((entry) => entry.target == viewport);
  }

  void _release(LongPressEndDetails details) {
    if (_phase != _DealPhase.dragging) return;
    final finger = details.globalPosition;
    _move(finger);
    final ctrl = context.read<SpreadController>();
    final slot = _box(_slotKeys[_index]);
    if (ctrl.readingRevision != _revision ||
        !ctrl.isSpreadOverview ||
        _next(ctrl) != _index ||
        ctrl.deckTop.first.id != _heldCard ||
        slot == null ||
        !_visibleAt(finger)) {
      _returnToDeck();
      return;
    }
    // Evaluate in the card's own (possibly rotated) frame. A small allowance
    // keeps tiny fit-to-screen slots usable without selecting a neighbour.
    final target = _pose(_slotKeys[_index])!;
    final padding = math.max(0.0, (32 / target.scale - slot.size.width) / 2);
    final bounds = Offset.zero & slot.size;
    final local = slot.globalToLocal(finger);
    if (!bounds.contains(local) &&
        (!bounds.inflate(padding).contains(local) ||
            _overDifferentSlot(finger))) {
      _returnToDeck();
      return;
    }
    _from = _currentPose();
    _land(const Duration(milliseconds: 210));
  }

  bool _overDifferentSlot(Offset finger) {
    for (final entry in _slotKeys.entries) {
      if (entry.key == _index) continue;
      final box = _box(entry.value);
      if (box != null &&
          (Offset.zero & box.size).contains(box.globalToLocal(finger))) {
        return true;
      }
    }
    return false;
  }

  void _land(Duration duration) {
    if (widget.onDeal() != _index) {
      _finish();
      return;
    }
    setState(() => _phase = _DealPhase.landing);
    _motion.duration = duration;
    _motion.forward(from: 0).then((_) {
      if (!mounted) return;
      final slot = _box(_slotKeys[_index]);
      if (slot != null &&
          _visibleAt(slot.localToGlobal(slot.size.center(Offset.zero)))) {
        HapticFeedback.lightImpact();
      }
      _finish();
    });
  }

  void _returnToDeck() {
    if (_phase != _DealPhase.dragging) return;
    _from = _currentPose();
    setState(() => _phase = _DealPhase.returning);
    // Same physical return spring as the Focus deck.
    _motion
        .animateWith(SpringSimulation(spring, 0, 1, 0))
        .then((_) => _finish());
  }

  void _finish() {
    if (!mounted) return;
    setState(() {
      _phase = null;
      _index = null;
      _heldCard = null;
    });
  }

  _DealPose _currentPose() {
    final returning = _phase == _DealPhase.returning;
    final end = _pose(returning ? _deck : _slotKeys[_index]) ?? _from;
    if (_phase == _DealPhase.dragging) {
      return _from.dragged(_dragDelta.value, end, _motion.value);
    }
    return _DealPose.flight(_from, end, _motion.value, returning: returning);
  }

  Widget _gestures(Widget deck) {
    if (context.read<SpreadController>().system == DivinationSystem.runes) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _motion.duration = const Duration(milliseconds: 420);
          _motion.forward(from: 0);
          if (widget.onDeal() == null) {
            showDealLockPrompt(context, context.read<SpreadController>());
          } else {
            HapticFeedback.mediumImpact();
          }
        },
        child: ScaleTransition(
          scale: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1, end: 1.05), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.05, end: 1), weight: 2),
          ]).animate(_motion),
          child: GuideHighlight(child:deck),
        ),
      );
    }
    return Listener(
      onPointerCancel: (_) => _returnToDeck(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        onLongPressStart: _pickUp,
        onLongPressMoveUpdate: (d) => _move(d.globalPosition),
        onLongPressEnd: _release,
        child: GuideHighlight(child:deck),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabVisible = Visibility.of(context);
    final routeCurrent = ModalRoute.isCurrentOf(context);
    if (!tabVisible || routeCurrent == false) _interrupt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _interrupt();
  }

  void _interrupt() {
    if (_phase == null) return;
    _motion.stop();
    _finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _dragDelta.dispose();
    super.dispose();
  }

  /// Solves the coupled dock height and viewport fit scale so the horizontal
  /// deck's top card in [SpreadDeckDock] matches the rendered size of each
  /// card on the table (`deckHeight * fit` × `deckWidth * fit`) without moving
  /// the deck out of its centered top-dock position.
  static ({double dockHeight, double deckWidthPx, double deckHeightPx})
  _dockSizingFor(Size area, Size boardSize) {
    const headerH = ProfileHeader.actionSize;
    const deckPad = 12.0;
    const stackEdge = 4.0;
    if (area.height <= headerH + deckPad + stackEdge || area.width <= 0) {
      return (
        dockHeight: math.min(area.height, headerH),
        deckWidthPx: 0,
        deckHeightPx: 0,
      );
    }
    var inset = 12.0;
    var fit = 1.0;
    for (var i = 0; i < 3; i++) {
      final availW = math.max(1.0, area.width - 2 * inset);
      final availH = math.max(
        1.0,
        area.height - headerH - deckPad - stackEdge - 2 * inset,
      );
      final fitW = availW / boardSize.width;
      final fitH = availH / (boardSize.height + deckWidth);
      fit = math.min(1.0, math.min(fitW, fitH)).clamp(0.0, 1.0);
      final dockH = headerH + deckPad + stackEdge + deckWidth * fit;
      final vpH = math.max(0.0, area.height - dockH);
      inset = math.min(12.0, math.min(area.width, vpH) / 8);
    }
    final cardShort = deckWidth * fit;
    final cardLong = deckHeight * fit;
    return (
      dockHeight: math.min(
        area.height,
        headerH + deckPad + stackEdge + cardShort,
      ),
      deckWidthPx: cardLong + stackEdge,
      deckHeightPx: cardShort + stackEdge,
    );
  }

  SpreadBoardGeometry _geometryFor(SpreadController ctrl) {
    final loveBridge =
        !ctrl.isCustomSpread &&
        ctrl.system == DivinationSystem.tarot &&
        ctrl.spreadType == SpreadType.loveBridge;
    final count =
        ctrl.slots.length +
        (ctrl.system != DivinationSystem.runes &&
                _next(ctrl) == ctrl.slots.length
            ? 1
            : 0);
    return ctrl.isCustomSpread
        ? spreadBoardGeometryForCustom(ctrl.spreadCardCount, totalSlots: count, fiveCardLine: ctrl.customSpread!.isFiveCardLine)
        : spreadBoardGeometryForCount(
            ctrl.spreadCardCount,
            totalSlots: count,
            loveBridge: loveBridge,
          );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final geometry = _geometryFor(ctrl);
    return LayoutBuilder(
      builder: (context, area) {
        final sizing = _dockSizingFor(area.biggest, geometry.canvasSize);
        return Stack(
          key: _surface,
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                SizedBox(
                  height: sizing.dockHeight,
                  width: double.infinity,
                  child: SpreadDeckDock(
                    header: widget.header,
                    badge: widget.badge,
                    wrapDeck: _gestures,
                    topKey: _deck,
                    lifted: _phase != null,
                    deckWidthPx: sizing.deckWidthPx,
                    deckHeightPx: sizing.deckHeightPx,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) =>
                        _canvas(context, ctrl, geometry, c.biggest),
                  ),
                ),
              ],
            ),
            if (_phase != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_motion, _dragDelta]),
                    child: const RepaintBoundary(
                      child: SpreadCardBack(
                        width: deckWidth,
                        height: deckHeight,
                      ),
                    ),
                    builder: (_, back) =>
                        _MovingCard(pose: _currentPose(), child: back!),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _canvas(
    BuildContext context,
    SpreadController ctrl,
    SpreadBoardGeometry geometry,
    Size viewport,
  ) {
    if (viewport.isEmpty) return const SizedBox.shrink();
    final design = geometry.canvasSize;
    final rects = geometry.slotRects;

    final designCanvas = SizedBox(
      width: design.width,
      height: design.height,
      child: Stack(
        children: [
          Positioned.fill(child: SpreadThreadsLayer(selected:_phase == null ? widget.selected : null,rects:rects.asMap())),
          for (var i = 0; i < rects.length; i++)
            Positioned.fromRect(
              rect: geometry.crossingSlotIndex == i
                  ? Rect.fromCenter(
                      center: rects[i].center,
                      width: deckHeight,
                      height: deckWidth,
                    )
                  : rects[i],
              child: RotatedBox(
                quarterTurns: geometry.crossingSlotIndex == i ? 1 : 0,
                child: SizedBox.expand(
                  key: _slotKeys.putIfAbsent(i, GlobalKey.new),
                  child: GuideHighlight(slot:i, child: _OverviewSlot(
                    key: ValueKey('spread-slot-$i'),
                    inspect: widget.inspect,
                    slot: i < ctrl.slots.length ? ctrl.slots[i] : null,
                    slotIndex: i,
                    highlighted: _index == i && _phase == _DealPhase.dragging,
                    inFlight: _index == i && _phase == _DealPhase.landing,
                  )),
                ),
              ),
            ),
        ],
      ),
    );

    return SpreadViewport(
      key: _viewport,
      viewport: viewport,
      boardSize: design,
      fitLabel: AppStrings.t(
        context.watch<AppSettingsController>().language,
        'table.fit',
      ),
      child: designCanvas,
    );
  }
}

class _OverviewSlot extends StatefulWidget {
  const _OverviewSlot({
    super.key,
    required this.slot,
    required this.slotIndex,
    required this.inspect,
    required this.highlighted,
    required this.inFlight,
  });

  final DealtCardSlot? slot;
  final int slotIndex;
  final ValueChanged<int> inspect;
  final bool highlighted;
  final bool inFlight;

  @override
  State<_OverviewSlot> createState() => _OverviewSlotState();
}

class _OverviewSlotState extends State<_OverviewSlot>
    with SingleTickerProviderStateMixin {
  /// Materialization entrance; starts completed when the view opens with
  /// already-dealt cards (no replay).
  late final AnimationController _entrance;
  late bool _occupied;

  @override
  void initState() {
    super.initState();
    _occupied = widget.slot?.card != null;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: _occupied ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _OverviewSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_occupied && widget.slot?.card?.system == DivinationSystem.runes) {
      _entrance.forward(from: 0);
    }
    _occupied = widget.slot?.card != null;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final card = slot?.card;
    if (card == null || slot == null || widget.inFlight) {
      final positions = context.watch<AppSettingsController>().enabled(ReadingAid.positions);
      if (!positions && !widget.highlighted) return const SizedBox.expand();
      final shorts = context.read<SpreadController>().spreadSlotRoleShorts;
      final shortRole = widget.slotIndex < shorts.length
          ? shorts[widget.slotIndex]
          : 'Clarifier';
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(deckWidth * 0.06),
          color: widget.highlighted
              ? TaroColors.lavender.withValues(alpha: 0.12)
              : null,
          border: Border.all(
            color: widget.highlighted ? TaroColors.lavender : TaroColors.border,
            width: widget.highlighted ? 3 : 1,
          ),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Text(
          positions ? '${widget.slotIndex + 1} · $shortRole' : '',
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.8,
            color: TaroColors.textSecondary.withValues(alpha: 0.65),
          ),
        ),
      );
    }
    final piece = SlottedDivinationCard(
      slot: slot,
      width: deckWidth,
      height: deckHeight,
      onFlip: () => context.read<SpreadController>().flipSlot(slot.index),
      onTapFaceUp: () => widget.inspect(slot.index),
    );
    if (card.system != DivinationSystem.runes) return piece;
    return AnimatedBuilder(
      animation: _entrance,
      child: piece,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_entrance.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: v,
              child: Transform.scale(scale: 0.88 + 0.12 * v, child: child),
            ),
            // Elemental rim shimmer fading out as the card settles.
            if (v < 1)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(deckWidth * 0.06),
                    border: Border.all(
                      color: card.element.accent.withValues(
                        alpha: (1 - v) * 0.85,
                      ),
                      width: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
