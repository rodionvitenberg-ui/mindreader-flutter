import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/spread_type.dart';
import '../../core/models/tarot_deck_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import 'widgets/board_pillar_view.dart';
import 'widgets/deal_lock_prompt.dart';
import 'widgets/deck_picker_sheet.dart';
import 'widgets/foil_glint.dart';
import 'widgets/interactive_deck_widget.dart';
import 'widgets/reading_bottom_sheet.dart';
import 'widgets/ritual_settings_sheet.dart';
import 'widgets/shuffle_physics.dart';
import 'widgets/spread_selector_sheet.dart';
import 'widgets/spread_threads_layer.dart';
import 'widgets/tarot_card_3d_widget.dart';

/// Fixed header above the table canvas (title + deck/ritual/view pills).
const _headerHeight = 84.0;

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
    final design =
        spreadCanvasDesignSize(ctrl.spreadType, totalSlots: ctrl.slots.length);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final dealt = [for (final s in ctrl.slots) if (s.card != null) s];
    final rects = [
      for (var i = 0; i < ctrl.slots.length; i++)
        Rect.fromLTWH(
          spreadSlotDesignTopLeft(
            ctrl.spreadType,
            i,
            totalSlots: ctrl.slots.length,
          ).dx,
          spreadSlotDesignTopLeft(
            ctrl.spreadType,
            i,
            totalSlots: ctrl.slots.length,
          ).dy,
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
          // The living Elemental Fate Threads across the spread geometry.
          SpreadThreadsLayer(dealt: dealt, rects: rects),
          for (var i = 0; i < ctrl.slots.length; i++)
            Positioned(
              left: spreadSlotDesignTopLeft(
                ctrl.spreadType,
                i,
                totalSlots: ctrl.slots.length,
              ).dx,
              top: spreadSlotDesignTopLeft(
                ctrl.spreadType,
                i,
                totalSlots: ctrl.slots.length,
              ).dy,
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
  /// already-materialized slot card.
  Widget _flightOverlay(TarotDeckPack pack, _CardFlight flight, double t) {
    final pos = Offset.lerp(flight.start, flight.target, t)!;
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
                CardBack(width: deckWidth, height: deckHeight, pack: pack),
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
                              // table (no BEFORE YOU DRAW box).
                              SizedBox(
                                width: deckWidth,
                                height: deckBoxHeight,
                                child: InteractiveDeckWidget(
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
                              dealHint: 'SWIPE ↓ TO DEAL',
                            ),
                          ),
                        ),
                        if (flight != null && _flightCtl != null)
                          AnimatedBuilder(
                            animation: _flightCtl!,
                            builder: (context, _) => _flightOverlay(
                                pack, flight, _flightCtl!.value),
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
          Text(
            'DIGITAL TABLE',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => SpreadSelectorSheet.show(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${ctrl.spreadType.label.toUpperCase()} · '
                  '${ctrl.remaining} IN DECK',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    letterSpacing: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 13,
                  color: AppColors.lavender,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // The pill row NEVER overflows on narrow 360px screens: it is
          // scaled down as one unit instead of spilling off the edge.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DeckPackPill(),
                  const SizedBox(width: 8),
                  const _BellPill(),
                  const SizedBox(width: 8),
                  if (ctrl.sourceMode == TableSourceMode.physicalCameraSync) ...[
                    const _PhysicalSyncPill(),
                    const SizedBox(width: 8),
                  ],
                  _ViewModeToggle(mode: mode, onChanged: onModeChanged),
                ],
              ),
            ),
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

/// Physical-sync badge: shown while the table hosts cards photographed
/// from the user's real deck.
class _PhysicalSyncPill extends StatelessWidget {
  const _PhysicalSyncPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.harmonyCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.harmonyCyan),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_camera_front_outlined,
            size: 12,
            color: AppColors.harmonyCyan,
          ),
          const SizedBox(width: 6),
          Text(
            'PHYSICAL SYNC',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.harmonyCyan,
            ),
          ),
        ],
      ),
    );
  }
}

/// Deck switcher pill — opens the 3D carousel picker.
class _DeckPackPill extends StatelessWidget {
  const _DeckPackPill();

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activePack;
    return GestureDetector(
      onTap: () => DeckPickerSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined,
                size: 12, color: AppColors.lavender),
            const SizedBox(width: 6),
            Text(
              pack.name.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ritual bell — opens the daily ritual settings sheet.
class _BellPill extends StatelessWidget {
  const _BellPill();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => RitualSettingsSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_outlined,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'RITUAL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
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
    final String label;
    if (atMax) {
      label = '${ctrl.remaining} · 10/10 TABLE FULL';
    } else if (armed) {
      label = '${ctrl.remaining} · PULL CLARIFIER ↓';
    } else if (canReset) {
      label = '${ctrl.remaining} · TAP TO RESET · NEW SPREAD';
    } else if (ctrl.nextEmptySlotIndex != null) {
      label = '${ctrl.remaining} · $dealHint';
    } else {
      label = '${ctrl.remaining} · IN DECK';
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
    required this.pack,
    required this.width,
    required this.height,
    required this.onTap,
  });

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
              // Only the rounded card itself is rendered — no static backing
              // strip/rectangle above it (same artifact class as the hero deck).
              child: CardBack(width: w, height: h, pack: widget.pack),
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
                child: TarotCard3DWidget(
                  card: card,
                  isReversed: slot.isReversed,
                  state: slot.state,
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

