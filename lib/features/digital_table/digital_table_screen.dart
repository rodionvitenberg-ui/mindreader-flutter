import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/data/runes_data.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/rune_stone.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/models/tarot_deck_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import 'widgets/board_pillar_view.dart';
import 'widgets/deal_lock_prompt.dart';
import 'widgets/deck_picker_sheet.dart';
import 'widgets/elemental_threads_painter.dart';
import 'widgets/foil_glint.dart';
import 'widgets/interactive_deck_widget.dart';
import 'widgets/interactive_rune_stones_widget.dart';
import 'widgets/reading_bottom_sheet.dart';
import 'widgets/rune_stone_3d_widget.dart';
import 'widgets/shuffle_physics.dart';
import 'widgets/slotted_divination_card.dart';
import 'widgets/spread_selector_sheet.dart';
import 'widgets/spread_threads_layer.dart';
import 'widgets/tarot_card_3d_widget.dart';

/// Fixed header above the table canvas: three clean balanced rows —
/// Row 1 the FOCUS/SPREAD toggle, Row 2 the TAROT|LENORMAND|RUNES system
/// selector, Row 3 the pack + spread picker pills (Expanded, no overflow).
const _headerHeight = 118.0;

/// The two switchable view modes of the Digital Table.
enum TableViewMode {
  /// Mode A — tactile focus: full-size 220×360 deck at the top + full-size
  /// dealt cards below in ONE unified vertical scroll canvas. No
  /// auto-scroll on deal — the camera stays on the deck.
  focus,

  /// Mode B — full spread overview: the entire spread on a single screen
  /// like a real tarot table. Centered proportional deck (scaled to the
  /// slot cards) above the spread, dealt cards in their true spread
  /// geometry (Triad row / Target & Shadow 2×2 / Deep Synthesis 3-1-3),
  /// scaled to maximize the viewport height. No flying deal card — cards
  /// materialize directly in their slots.
  spread,
}

/// One single continuous scrollable table canvas: the full-size 220×360
/// 3D deck at the top, the dealt 220×360 cards directly below it in the
/// SAME scroll view (28 px gap), nothing else. The deck NEVER shrinks;
/// scrolling moves the deck off the top edge like a real table camera.
/// Also hosts the Full Spread Overview mode (see [TableViewMode]).
///
/// Sprint 2/3: decluttered — no pre-draw box above the deck, no bottom
/// spread carousel; the spread method lives in the tappable header
/// subtitle (`▾`), context flows through the Gemini input capsule, and
/// the synthesis lives in the Oracle AI Chat pane.
class DigitalTableScreen extends StatefulWidget {
  const DigitalTableScreen({super.key});

  @override
  State<DigitalTableScreen> createState() => _DigitalTableScreenState();
}

/// One in-flight dealt card: flies from the release position to its exact
/// slot rectangle in the active body Stack's local coordinates.
class _CardFlight {
  const _CardFlight({
    required this.start,
    required this.target,
    required this.pose,
    required this.velocity,
  });

  final Offset start; // release point, body-local coordinates
  final Offset target; // slot top-left, body-local coordinates
  final FanLayerPose pose;
  final double velocity;
}

class _DigitalTableScreenState extends State<DigitalTableScreen>
    with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();

  TableViewMode _viewMode = TableViewMode.focus;

  AnimationController? _flightCtl;
  _CardFlight? _flight;

  late final SpreadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<SpreadController>();
    _controller.addListener(_onSpreadChanged);
    // Unlock landscape on the Digital Table: the spread overview expands
    // horizontally with the deck on the left, slots across the wide table.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// The spread changed: repaint (clarifier expansion lives in the
  /// TableWorkspace).
  void _onSpreadChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onSpreadChanged);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _flightCtl?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Content-space top-left of dealt slot [slotIndex]: deck bottom + the
  /// 52 px deck→pillar gap + stacked 220×360 slots with 56 px thread gaps.
  Offset _slotContentTopLeft(int slotIndex, double contentWidth) => Offset(
        (contentWidth - deckWidth) / 2,
        tableTopPad +
            deckBoxHeight +
            deckToPillarGap +
            slotIndex * (deckHeight + slotGapPx),
      );

  /// The deck handed us an extracted card: deal the exact grabbed card and
  /// play ONE continuous flight from the release point into its slot.
  /// The camera does NOT follow — the user stays focused on the deck while
  /// pulling multiple cards and scrolls down manually whenever ready.
  /// When the initial spread is full, the pull becomes a Clarifier (+1) —
  /// but only while a clarifier question is armed.
  void _onDealRelease(DeckDealReleaseRequest request) {
    final ctrl = context.read<SpreadController>();
    final slotIndex = ctrl.dealCardAtOrClarifier(request.depth);
    if (slotIndex == null) {
      showDealLockPrompt(context, ctrl);
      return;
    }
    _storeIntentionInto(ctrl, slotIndex);
    final deckBox = _deckKey.currentContext?.findRenderObject() as RenderBox?;
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (deckBox == null || contentBox == null) return;
    final start = deckBox.localToGlobal(Offset.zero, ancestor: contentBox) +
        request.cardOffsetLocal;
    _flyCardToSlot(
      slotIndex,
      start: start,
      pose: request.pose,
      velocity: request.releaseVelocityPx,
    );
  }

  /// The rune cluster handed us a cast stone: deal the EXACT grabbed stone
  /// (its depth in the heap) and fly it from the release point into its slot.
  void _onRuneCastRelease(RuneCastReleaseRequest request) {
    final ctrl = context.read<SpreadController>();
    final slotIndex = ctrl.dealCardAtOrClarifier(request.depth);
    if (slotIndex == null) {
      showDealLockPrompt(context, ctrl);
      return;
    }
    _storeIntentionInto(ctrl, slotIndex);
    final deckBox = _deckKey.currentContext?.findRenderObject() as RenderBox?;
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (deckBox == null || contentBox == null) return;
    final start = deckBox.localToGlobal(Offset.zero, ancestor: contentBox) +
        request.stoneOffsetLocal;
    _flyCardToSlot(
      slotIndex,
      start: start,
      pose: FanLayerPose.flat,
      velocity: request.releaseVelocityPx,
    );
  }

  /// Stores the pending capsule context into the freshly dealt slot (the
  /// queue lives in [SpreadController] — shared with the workspace).
  void _storeIntentionInto(SpreadController ctrl, int slotIndex) {
    ctrl.consumePendingContext(slotIndex);
  }

  /// One continuous spring flight into slot [slotIndex] (shared by the
  /// tactile deck release and the clarifier pulls).
  void _flyCardToSlot(
    int slotIndex, {
    required Offset start,
    required FanLayerPose pose,
    required double velocity,
  }) {
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (contentBox == null) return;
    final target = _slotContentTopLeft(slotIndex, contentBox.size.width);
    final distance = math.max(1.0, (target - start).distance);

    HapticFeedback.mediumImpact();
    setState(() {
      _flightCtl = AnimationController(vsync: this);
      _flight = _CardFlight(
        start: start,
        target: target,
        pose: pose,
        velocity: velocity,
      );
    });
    _flightCtl!
        .animateWith(SpringSimulation(
          spring,
          0,
          1,
          (velocity / distance).clamp(-8.0, 8.0),
        ))
        .whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() => _flight = null);
      _flightCtl?.dispose();
      _flightCtl = null;
    });
  }

  /// Overview mode: tapping the deck deals the next card DIRECTLY into its
  /// target spread slot — NO 220×360 flight overlay (the old flying card
  /// clipped off the bottom-right corner). The deck plays a gentle pulse
  /// (see [_OverviewDeck]) while the dealt card materializes inside the
  /// slot (see [_OverviewSlot]). Once the initial spread is full, the tap
  /// appends a Clarifier (+1) — but only while a clarifier question is
  /// armed (the deck stays locked otherwise).
  void _onOverviewDeckTap() {
    final ctrl = context.read<SpreadController>();
    final slotIndex = ctrl.dealNextCardOrClarifier();
    if (slotIndex == null) {
      showDealLockPrompt(context, ctrl);
      return;
    }
    HapticFeedback.mediumImpact();
  }

  void _resetTable() {
    HapticFeedback.mediumImpact();
    context.read<SpreadController>().resetTable();
  }

  /// Mode B — Full Spread Overview: the entire spread on one screen like a
  /// real tarot table. Portrait: the deck + status pill are CENTERED above
  /// the spread geometry (Alignment.topCenter), the deck scales
  /// proportionally to the slot cards (~1.12× a slot, never the old 3×
  /// tower) and the slots take the maximum remaining viewport height.
  /// Landscape: the deck panel sits on the LEFT, the wide spread canvas
  /// expands to the right.
  ///
  /// Dealing here NEVER launches the 220×360 flight overlay — the dealt
  /// card materializes directly inside its target slot (see [_OverviewSlot]).
  Widget _buildSpreadOverview(
    SpreadController ctrl,
    TarotDeckPack pack,
    BoxConstraints constraints,
  ) {
    final design = spreadCanvasDesignSizeForCount(
      ctrl.spreadCardCount,
      totalSlots: ctrl.slots.length,
    );
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final dealt = [for (final s in ctrl.slots) if (s.card != null) s];
    Offset slotTopLeft(int i) => spreadSlotDesignTopLeftForCount(
          ctrl.spreadCardCount,
          i,
          totalSlots: ctrl.slots.length,
        );
    final rects = [
      for (var i = 0; i < ctrl.slots.length; i++)
        Rect.fromLTWH(
          slotTopLeft(i).dx,
          slotTopLeft(i).dy,
          deckWidth,
          deckHeight,
        ),
    ];

    // The design-space spread geometry, FittedBox-scaled to fit the screen.
    final designCanvas = SizedBox(
      width: design.width,
      height: design.height,
      child: Stack(
        children: [
          // The living Elemental Fate Threads across the spread geometry —
          // TAROT ONLY. Runes keep their rim glow, Lenormand its pair pills.
          if (elementalThreadsVisibleFor(ctrl.system))
            SpreadThreadsLayer(dealt: dealt, rects: rects),
          for (var i = 0; i < ctrl.slots.length; i++)
            Positioned(
              left: slotTopLeft(i).dx,
              top: slotTopLeft(i).dy,
              width: deckWidth,
              height: deckHeight,
              child: _OverviewSlot(
                slot: ctrl.slots[i],
                slotIndex: i,
              ),
            ),
        ],
      ),
    );

    final counterBadge = _DeckCounterBadge(
      ctrl: ctrl,
      onReset: _resetTable,
      dealHint: 'TAP DECK TO DEAL',
    );

    if (isLandscape) {
      final miniDeck = _OverviewDeck(
        system: ctrl.system,
        pack: pack,
        width: overviewDeckWidth,
        height: overviewDeckHeight,
        onTap: _onOverviewDeckTap,
      );
      final deckPanel = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [miniDeck, const SizedBox(width: 12), counterBadge],
      );
      return Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: deckPanel,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.contain,
                child: designCanvas,
              ),
            ),
          ),
        ],
      );
    }

    // Portrait: solve the canvas scale so the deck (1.12× a slot card) +
    // the status pill + the spread canvas ALL fit the viewport height —
    // the slots get the maximum possible size.
    const wPad = 24.0; // canvas horizontal padding (12+12)
    const hPad = 46.0; // top pad + gaps + canvas bottom pad
    const badgeRow = 32.0; // status pill + its gap below the deck
    final scale = math.min(
      (constraints.maxWidth - wPad) / design.width,
      (constraints.maxHeight - hPad - badgeRow) /
          (design.height + 1.12 * deckHeight),
    );
    final slotW = deckWidth * scale;
    final deckW = (slotW * 1.12).clamp(overviewDeckWidth, 200.0);
    final deckH = deckW * deckHeight / deckWidth;
    final miniDeck = _OverviewDeck(
      system: ctrl.system,
      pack: pack,
      width: deckW,
      height: deckH,
      onTap: _onOverviewDeckTap,
    );
    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              miniDeck,
              const SizedBox(height: 8),
              counterBadge,
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Center(
              child: SizedBox(
                width: design.width * scale,
                height: design.height * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: designCanvas,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The flight card (FOCUS mode only — the overview materializes in-slot),
  /// positioned in the active body Stack's local coordinates: it flies from
  /// the release pose to the exact slot rect, landing pixel-perfectly on the
  /// already-materialized slot card. Runes fly as a face-down carved stone.
  Widget _flightOverlay(
    DivinationSystem system,
    TarotDeckPack? tarotPack,
    _CardFlight flight,
    double t,
  ) {
    final pos = Offset.lerp(flight.start, flight.target, t)!;
    final flyingPiece = switch (system) {
      DivinationSystem.tarot => CardBack(
          width: deckWidth,
          height: deckHeight,
          pack: tarotPack,
        ),
      DivinationSystem.lenormand => CardBack(
          width: deckWidth,
          height: deckHeight,
          styleOverride:
              context.read<DeckPackController>().activeLenormandPack.backStyle,
          accentOverride:
              context.read<DeckPackController>().activeLenormandPack.backAccentArgb,
          secondaryOverride: context
              .read<DeckPackController>()
              .activeLenormandPack
              .backSecondaryArgb,
        ),
      DivinationSystem.runes => const Center(
          child: SizedBox(
            width: 150,
            height: 178,
            child: _FlightStone(),
          ),
        ),
    };
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Transform(
        alignment: Alignment.center,
        transform: extractedFlightMatrix(flight.pose, t),
        child: RepaintBoundary(
          child: SizedBox(
            width: deckWidth,
            height: deckHeight,
            child: Stack(
              children: [
                flyingPiece,
                if (system != DivinationSystem.runes)
                  Positioned.fill(
                    child: FoilGlint(
                      angleY: flight.pose.rotateY * (1 - t),
                      angleX: flight.pose.rotateX,
                      intensity: 0.8,
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
    final pack = context.watch<DeckPackController>().activePack;
    final flight = _flight;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: _TableHeader(
              ctrl: ctrl,
              mode: _viewMode,
              onModeChanged: (mode) {
                HapticFeedback.selectionClick();
                setState(() => _viewMode = mode);
              },
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_viewMode == TableViewMode.spread) {
                  return _buildSpreadOverview(ctrl, pack, constraints);
                }
                return SingleChildScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Stack(
                      key: _contentKey,
                      clipBehavior: Clip.none,
                      children: [
                        // The whole table column is centered on the
                        // screen's central vertical axis.
                        Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: tableTopPad),
                              // Clean space above the deck — the decluttered
                              // table (no BEFORE YOU DRAW box). Runes swap
                              // the paper deck for the 3D stone cluster.
                              SizedBox(
                                width: deckWidth,
                                height: deckBoxHeight,
                                child: ctrl.system == DivinationSystem.runes
                                    ? InteractiveRuneStonesWidget(
                                        key: _deckKey,
                                        onCastRelease: _onRuneCastRelease,
                                      )
                                    : InteractiveDeckWidget(
                                        key: _deckKey,
                                        onDealRelease: _onDealRelease,
                                      ),
                              ),
                              const SizedBox(height: deckToPillarGap),
                              BoardPillarView(
                                onTapFaceUp: (slotIndex) =>
                                    ReadingBottomSheet.show(context,
                                        cardIndex: slotIndex),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        // Live counter badge hugging the deck's bottom
                        // edge — lives at the content-Stack level so its
                        // overlap area stays fully hit-testable.
                        Positioned(
                          top: tableTopPad + deckBoxHeight - 11,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _DeckCounterBadge(
                              ctrl: ctrl,
                              onReset: _resetTable,
                              dealHint: ctrl.system.dealHint,
                            ),
                          ),
                        ),
                        if (flight != null && _flightCtl != null)
                          AnimatedBuilder(
                            animation: _flightCtl!,
                            builder: (context, _) => _flightOverlay(
                                ctrl.system, pack, flight, _flightCtl!.value),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.ctrl,
    required this.mode,
    required this.onModeChanged,
  });

  final SpreadController ctrl;
  final TableViewMode mode;
  final ValueChanged<TableViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Row 1 — the [ FOCUS VIEW | SPREAD VIEW ] segmented toggle,
          // top-center where the old static title used to sit.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _ViewModeToggle(mode: mode, onChanged: onModeChanged),
          ),
          const SizedBox(height: 4),
          // Row 2 — the 3-system segmented selector.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _SystemSelector(ctrl: ctrl),
          ),
          const SizedBox(height: 6),
          // Row 3 — pack picker + spread picker, two balanced pills.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Expanded(child: _SystemPackPill()),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('spread-selector-pill'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => SpreadSelectorSheet.show(context),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              ctrl.spreadLabel.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8.5,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lavender,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 13,
                            color: AppColors.lavender,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The TAROT | LENORMAND | RUNES segmented system selector (header Row 2).
class _SystemSelector extends StatelessWidget {
  const _SystemSelector({required this.ctrl});

  final SpreadController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final system in DivinationSystem.values)
            _SystemSegment(
              key: ValueKey('system-segment-${system.name}'),
              label: system.label,
              active: ctrl.system == system,
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<SpreadController>().setSystem(system);
              },
            ),
        ],
      ),
    );
  }
}

/// Focus ↔ Spread view switch in the top table bar (pill segmented toggle).
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final TableViewMode mode;
  final ValueChanged<TableViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSegment(
            label: 'FOCUS VIEW',
            active: mode == TableViewMode.focus,
            onTap: () => onChanged(TableViewMode.focus),
          ),
          _ModeSegment(
            label: 'SPREAD VIEW',
            active: mode == TableViewMode.spread,
            onTap: () => onChanged(TableViewMode.spread),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// One segment of the system selector.
class _SystemSegment extends StatelessWidget {
  const _SystemSegment({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// The pack picker pill (header Row 3 left) — filtered strictly to packs
/// of the ACTIVE divination system (DeckPickerSheet branches on it).
class _SystemPackPill extends StatelessWidget {
  const _SystemPackPill();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final packs = context.watch<DeckPackController>();
    final label = switch (ctrl.system) {
      DivinationSystem.tarot => packs.activePack.name.toUpperCase(),
      DivinationSystem.lenormand => packs.activeLenormandPack.name.toUpperCase(),
      DivinationSystem.runes => packs.activeRunePack.name.toUpperCase(),
    };
    return GestureDetector(
      key: const ValueKey('system-pack-pill'),
      behavior: HitTestBehavior.opaque,
      onTap: () => DeckPickerSheet.show(context, system: ctrl.system),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctrl.system.packGlyph,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lavender,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 13,
              color: AppColors.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live counter badge hugging the deck's bottom edge: decrements in real
/// time as the 78-card stack depletes; invites a tap-to-reset once the
/// spread is complete (the deck itself never shrinks).
class _DeckCounterBadge extends StatelessWidget {
  const _DeckCounterBadge({
    required this.ctrl,
    this.onReset,
    this.dealHint = 'SWIPE ↓ TO DEAL',
  });

  final SpreadController ctrl;
  final VoidCallback? onReset;

  /// Mode-specific deal instruction ('SWIPE ↓' in focus, 'TAP DECK' in
  /// spread overview).
  final String dealHint;

  @override
  Widget build(BuildContext context) {
    final armed = ctrl.pendingClarifierQuestion != null;
    final atMax = ctrl.dealtCount >= SpreadController.maxTableCards;
    final canReset = ctrl.nextEmptySlotIndex == null && onReset != null;
    // NO deck-size prefixes — the pill shows only the action (the old
    // "78 ·" counter and "IN DECK" text are gone by design).
    final String label;
    if (atMax) {
      label = '10/10 TABLE FULL';
    } else if (armed) {
      label = 'PULL CLARIFIER ↓';
    } else if (canReset) {
      label = 'TAP TO RESET · NEW SPREAD';
    } else if (ctrl.nextEmptySlotIndex != null) {
      label = dealHint;
    } else {
      label = 'IN DECK';
    }
    return GestureDetector(
      onTap: armed && !atMax
          ? () {
              // The badge toggles: dismiss the armed clarifier question.
              HapticFeedback.selectionClick();
              ctrl.cancelClarifierScan();
            }
          : canReset
              ? () {
                  HapticFeedback.selectionClick();
                  onReset!();
                }
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8.5,
            letterSpacing: 1.6,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}

/// Centered proportional mini-deck for the Spread Overview mode: tap to
/// deal the next card DIRECTLY into the spread. The deck plays a gentle
/// breathing pulse on every tap while the dealt card materializes in its
/// slot. Size is passed in by [_DigitalTableScreenState] so it stays
/// proportional to the spread's slot cards.
class _OverviewDeck extends StatefulWidget {
  const _OverviewDeck({
    required this.system,
    required this.pack,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final DivinationSystem system;
  final TarotDeckPack pack;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_OverviewDeck> createState() => _OverviewDeckState();
}

class _OverviewDeckState extends State<_OverviewDeck>
    with SingleTickerProviderStateMixin {
  /// 420ms soft breathing pulse (1.0 → 1.12 → 1.0) on each tap.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    _pulse.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final p = 1.0 + 0.12 * math.sin(math.pi * _pulse.value);
          return Transform.scale(
            scale: p,
            child: SizedBox(
              key: const ValueKey('overview-deck'),
              width: w,
              height: h,
              // Only the rounded card / stone pile itself is rendered — no
              // static backing strip above it (same artifact class as the
              // hero deck).
              child: switch (widget.system) {
                DivinationSystem.tarot => CardBack(
                    width: w,
                    height: h,
                    pack: widget.pack,
                  ),
                DivinationSystem.lenormand => CardBack(
                    width: w,
                    height: h,
                    styleOverride: context
                        .watch<DeckPackController>()
                        .activeLenormandPack
                        .backStyle,
                    accentOverride: context
                        .watch<DeckPackController>()
                        .activeLenormandPack
                        .backAccentArgb,
                    secondaryOverride: context
                        .watch<DeckPackController>()
                        .activeLenormandPack
                        .backSecondaryArgb,
                  ),
                DivinationSystem.runes => const _OverviewStonePile(),
              },
            ),
          );
        },
      ),
    );
  }
}

/// One spread slot on the overview canvas: a subtle hairline placeholder
/// (with its role) while empty; once dealt, the card MATERIALIZES directly
/// inside the slot — a 550ms fade-in 0→1 + scale 0.88→1.0 with an
/// elemental rim shimmer (no flying overlay card). Tapping a face-down
/// card reveals it; a face-up card opens the reading sheet.
class _OverviewSlot extends StatefulWidget {
  const _OverviewSlot({required this.slot, required this.slotIndex});

  final DealtCardSlot slot;
  final int slotIndex;

  @override
  State<_OverviewSlot> createState() => _OverviewSlotState();
}

class _OverviewSlotState extends State<_OverviewSlot>
    with SingleTickerProviderStateMixin {
  /// Materialization entrance; starts completed when the view opens with
  /// already-dealt cards (no replay).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    value: widget.slot.card == null ? 0.0 : 1.0,
  );

  @override
  void didUpdateWidget(covariant _OverviewSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.card == null && widget.slot.card != null) {
      HapticFeedback.selectionClick();
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final card = slot.card;
    if (card == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(deckWidth * 0.06),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          slot.role.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.6,
            color: AppColors.textMuted.withValues(alpha: 0.65),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) {
        final v = Curves.easeOutCubic.transform(_entrance.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: v,
              child: Transform.scale(
                scale: 0.88 + 0.12 * v,
                child: SlottedDivinationCard(
                  slot: slot,
                  width: deckWidth,
                  height: deckHeight,
                  onFlip: () =>
                      context.read<SpreadController>().flipSlot(slot.index),
                  onTapFaceUp: () =>
                      ReadingBottomSheet.show(context, cardIndex: slot.index),
                ),
              ),
            ),
            // Elemental rim shimmer fading out as the card settles.
            if (v < 1)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(deckWidth * 0.06),
                    border: Border.all(
                      color: card.element.accent
                          .withValues(alpha: (1 - v) * 0.85),
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

/// The face-down carved stone used by the rune cast flight overlay.
class _FlightStone extends StatelessWidget {
  const _FlightStone();

  @override
  Widget build(BuildContext context) {
    return RuneStone3DWidget(
      stone: const RuneStone(
        id: 0,
        name: 'Fehu',
        glyph: 'ᚠ',
        phonetic: 'F',
        aett: RuneAett.freyr,
        element: Element.fire,
        keywords: ['Wealth'],
        upright: '',
        lore: '',
      ),
      isMerkstave: false,
      state: SlotState.faceDown,
      width: 150,
      height: 178,
      interactive: false,
    );
  }
}

/// The mini stone pile shown in the overview deck corner for RUNES — a
/// small heap of face-down stones instead of a paper card deck.
class _OverviewStonePile extends StatelessWidget {
  const _OverviewStonePile();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Positioned(
            left: 4.0 + i * 5,
            top: 10.0 - i * 4,
            child: CustomPaint(
              size: const Size(48, 57),
              painter: RuneStonePainter(
                stone: elderFuthark[0],
                pack: context.watch<DeckPackController>().activeRunePack,
                faceUp: false,
                ignite: 0,
                seed: 21 + i,
              ),
            ),
          ),
      ],
    );
  }
}

