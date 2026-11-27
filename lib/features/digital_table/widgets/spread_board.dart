import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/runes_data.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/spread_type.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/card_motion.dart';
import '../../../core/theme/element_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/deck_pack_controller.dart';
import '../../../state/spread_controller.dart';
import '../../profile/widgets/profile_header.dart';
import 'deal_lock_prompt.dart';
import 'rune_stone_3d_widget.dart';
import 'shuffle_physics.dart';
import 'slotted_divination_card.dart';
import 'spread_deck_dock.dart';
import 'reading_guide.dart';
import 'spread_threads_layer.dart';
import 'spread_viewport.dart';

part 'spread_deal_motion.dart';

/// Duration of the automatic tap-to-deal card flight in SPREAD VIEW.
const tapDealFlightDuration = Duration(milliseconds: 700);

class SpreadBoard extends StatefulWidget {
  const SpreadBoard({
    super.key,
    required this.inspect,
    required this.header,
    required this.badge,
    required this.onDeal,
  });

  final ValueChanged<int> inspect;
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
  late final _motion = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  _DealPhase? _phase;
  int? _index;
  int? _heldCard;
  late int _revision;
  late _DealPose _from;
  Offset _down = Offset.zero;
  double _runeSwirl = 0;
  int _lastRuneSwirlTick = 0;

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
      _phase = finger == null ? _DealPhase.flying : _DealPhase.dragging;
    });
    return true;
  }

  void _tap() {
    if (!_begin()) {
      final ctrl = context.read<SpreadController>();
      if (_phase == null && ctrl.isDealLocked) showDealLockPrompt(context, ctrl);
      return;
    }
    _land(automatic: true);
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
    _land();
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

  void _land({bool automatic = false}) {
    if (widget.onDeal() != _index) {
      _finish();
      return;
    }
    setState(() => _phase = automatic ? _DealPhase.flying : _DealPhase.landing);
    _motion.duration = automatic
        ? tapDealFlightDuration
        : const Duration(milliseconds: 210);
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
    if (_phase == _DealPhase.flying) {
      return _from.carriedTo(end, _motion.value);
    }
    return _DealPose.flight(_from, end, _motion.value, returning: returning);
  }

  void _onRuneSwirlUpdate(DragUpdateDetails d) {
    if (_phase != null) return;
    setState(() => _runeSwirl += d.delta.dx);
    final tick = _runeSwirl.abs() ~/ 24.0;
    if (tick != _lastRuneSwirlTick) {
      _lastRuneSwirlTick = tick;
      HapticFeedback.mediumImpact();
      context.read<SpreadController>().weaveShuffleRemaining();
    }
  }

  void _onRuneSwirlEnd(DragEndDetails d) {
    if (_phase != null) return;
    HapticFeedback.selectionClick();
  }

  Widget _gestures(Widget deck) {
    final isRunes =
        context.read<SpreadController>().system == DivinationSystem.runes;
    return Listener(
      onPointerCancel: (_) => _returnToDeck(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        onLongPressStart: _pickUp,
        onLongPressMoveUpdate: (d) => _move(d.globalPosition),
        onLongPressEnd: _release,
        onHorizontalDragUpdate: isRunes ? _onRuneSwirlUpdate : null,
        onHorizontalDragEnd: isRunes ? _onRuneSwirlEnd : null,
        child: GuideHighlight(child: deck),
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

  /// Solves the coupled dock height and viewport fit scale for [baseBoardSize]
  /// so the horizontal deck's top card matches the exact rendered dimensions
  /// of a card on the board (`deckHeight * fit` × `deckWidth * fit`) and stays
  /// stable when clarifier rows extend the scene below.
  static ({double dockHeight, double cardLongPx, double cardShortPx})
  _dockSizingFor(Size area, Size baseBoardSize, {double topInset = 0}) {
    final headerH = topInset + ProfileHeader.actionSize;
    const dockPadV = 12.0;
    if (area.height <= headerH + dockPadV || area.width <= 0) {
      return (
        dockHeight: math.min(area.height, headerH),
        cardLongPx: 0,
        cardShortPx: 0,
      );
    }
    var inset = 12.0;
    var fit = 1.0;
    var stackY = overviewStackMetrics(deckWidth).depthY;
    for (var i = 0; i < 4; i++) {
      final availW = math.max(1.0, area.width - 2 * inset);
      final availH = math.max(
        1.0,
        area.height - headerH - dockPadV - stackY - 2 * inset,
      );
      final fitW = availW / baseBoardSize.width;
      final fitH = availH / (baseBoardSize.height + deckWidth);
      fit = math.min(1.0, math.min(fitW, fitH)).clamp(0.0, 1.0);
      final metrics = overviewStackMetrics(deckWidth * fit);
      final maxCardLong = math.max(1.0, area.width - 16.0 - metrics.depthX * 2);
      if (deckHeight * fit > maxCardLong) {
        fit = (maxCardLong / deckHeight).clamp(0.0, 1.0);
      }
      final refined = overviewStackMetrics(deckWidth * fit);
      stackY = refined.depthY;
      final dockH = headerH + dockPadV + deckWidth * fit + stackY;
      final vpH = math.max(0.0, area.height - dockH);
      inset = math.min(12.0, math.min(area.width, vpH) / 8);
    }
    final cardShort = deckWidth * fit;
    final cardLong = deckHeight * fit;
    final metrics = overviewStackMetrics(cardShort);
    return (
      dockHeight: math.min(
        area.height,
        headerH + dockPadV + cardShort + metrics.depthY,
      ),
      cardLongPx: cardLong,
      cardShortPx: cardShort,
    );
  }

  SpreadBoardGeometry _geometryFor(SpreadController ctrl, {bool baseOnly = false}) {
    final loveBridge =
        !ctrl.isCustomSpread &&
        ctrl.system == DivinationSystem.tarot &&
        ctrl.spreadType == SpreadType.loveBridge;
    final count = baseOnly ? ctrl.spreadCardCount :
        ctrl.slots.length + (_next(ctrl) == ctrl.slots.length ? 1 : 0);
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
    final baseSize = _geometryFor(ctrl, baseOnly: true).canvasSize;
    final topInset = MediaQuery.paddingOf(context).top;
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: LayoutBuilder(
        builder: (context, area) {
          final sizing = _dockSizingFor(
            area.biggest,
            baseSize,
            topInset: topInset,
          );
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
                      key: const ValueKey('spread-deck-dock'),
                      topInset: topInset,
                      header: widget.header,
                      badge: widget.badge,
                      wrapDeck: _gestures,
                      topKey: _deck,
                      held: _phase == _DealPhase.dragging || _phase == _DealPhase.returning,
                      cardLongPx: sizing.cardLongPx,
                      cardShortPx: sizing.cardShortPx,
                      runeSwirl: _runeSwirl,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) =>
                          _canvas(context, ctrl, geometry, baseSize, c.biggest),
                    ),
                  ),
                ],
              ),
              if (_phase != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_motion, _dragDelta]),
                      child: ctrl.system == DivinationSystem.runes
                          ? null
                          : const RepaintBoundary(
                              child: SpreadCardBack(
                                width: deckWidth,
                                height: deckHeight,
                              ),
                            ),
                      builder: (_, back) {
                        final pose = _currentPose();
                        if (ctrl.system == DivinationSystem.runes) {
                          final stoneId =
                              (_heldCard ?? 0).clamp(0, elderFuthark.length - 1);
                          final stoneW = deckWidth * 0.74;
                          return _MovingCard(
                            pose: pose,
                            showCardShadow: false,
                            child: Center(
                              child: RepaintBoundary(
                                child: RuneStoneView(
                                  stone: elderFuthark[stoneId],
                                  pack: context
                                      .watch<DeckPackController>()
                                      .activeRunePack,
                                  faceUp: false,
                                  ignite: 0,
                                  seed: 21 + stoneId,
                                  lift: pose.lift,
                                  width: stoneW,
                                  height: stoneW * 1.18,
                                ),
                              ),
                            ),
                          );
                        }
                        return _MovingCard(pose: pose, child: back!);
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _canvas(
    BuildContext context,
    SpreadController ctrl,
    SpreadBoardGeometry geometry,
    Size baseSize,
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
          Positioned.fill(child: SpreadThreadsLayer(rects: rects.asMap())),
          for (var i = 0; i < rects.length; i++)
            Positioned.fromRect(
              rect: rects[i],
              child: RotatedBox(
                quarterTurns: geometry.crossingSlotIndex == i ? 1 : 0,
                child: SizedBox.expand(
                  key: _slotKeys.putIfAbsent(i, GlobalKey.new),
                  child: GuideHighlight(
                    slot: i,
                    child: _OverviewSlot(
                      key: ValueKey('spread-slot-$i'),
                      inspect: widget.inspect,
                      slot: i < ctrl.slots.length ? ctrl.slots[i] : null,
                      slotIndex: i,
                      basePosition: i < ctrl.spreadCardCount,
                      highlighted: _index == i && _phase == _DealPhase.dragging,
                      inFlight: _index == i &&
                          (_phase == _DealPhase.flying ||
                              _phase == _DealPhase.landing),
                    ),
                  ),
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
      baseBoardSize: baseSize,
      readingRevision: ctrl.readingRevision,
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
    required this.basePosition,
    required this.inspect,
    required this.highlighted,
    required this.inFlight,
  });

  final DealtCardSlot? slot;
  final int slotIndex;
  final bool basePosition;
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
      if (!widget.basePosition) return const SizedBox.expand();
      final positions = context.watch<AppSettingsController>().enabled(ReadingAid.positions);
      if (!positions && !widget.highlighted) return const SizedBox.expand();
      final ctrl = context.read<SpreadController>();
      final shorts = ctrl.spreadSlotRoleShorts;
      final shortRole = widget.slotIndex < shorts.length
          ? shorts[widget.slotIndex]
          : AppStrings.g('table.clarifier');
      if (ctrl.system == DivinationSystem.runes) {
        final stoneW = deckWidth * 0.78;
        final stoneH = stoneW * 1.18;
        return Center(
          child: Container(
            width: stoneW,
            height: stoneH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.elliptical(stoneW * 0.5, stoneH * 0.5),
              ),
              color: widget.highlighted
                  ? TaroColors.lavender.withValues(alpha: 0.14)
                  : TaroColors.surface.withValues(alpha: 0.22),
              border: Border.all(
                color: widget.highlighted
                    ? TaroColors.lavender
                    : TaroColors.border.withValues(alpha: 0.85),
                width: widget.highlighted ? 2.6 : 1.1,
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Text(
              positions ? '${widget.slotIndex + 1} · $shortRole' : '',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.8,
                color: TaroColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ),
        );
      }
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
            // Soft radial elemental aura pulse when the rune settles.
            if (v < 1)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: deckWidth * (0.78 + 0.14 * v),
                    height: deckWidth * (0.90 + 0.14 * v),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          card.element.accent.withValues(alpha: (1 - v) * 0.34),
                          card.element.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Opacity(
              opacity: v,
              child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
            ),
          ],
        );
      },
    );
  }
}
