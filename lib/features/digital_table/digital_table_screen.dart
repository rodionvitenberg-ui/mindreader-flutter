import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/data/intention_prompts.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/spread_type.dart';
import '../../core/models/tarot_deck_pack.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/synthesis_session.dart';
import 'widgets/board_pillar_view.dart';
import 'widgets/deck_picker_sheet.dart';
import 'widgets/foil_glint.dart';
import 'widgets/intention_prompt_bar.dart';
import 'widgets/interactive_deck_widget.dart';
import 'widgets/reading_bottom_sheet.dart';
import 'widgets/ritual_settings_sheet.dart';
import 'widgets/shuffle_physics.dart';
import 'widgets/spread_threads_layer.dart';
import 'widgets/synthesis_panel.dart';
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
  /// like a real tarot table. Compact 90×148 deck in the corner, dealt
  /// cards in their true spread geometry (Triad row / Target & Shadow 2×2
  /// / Deep Synthesis 3-1-3), FittedBox-scaled to fit the viewport.
  spread,
}

/// One single continuous scrollable table canvas: the full-size 220×360
/// 3D deck at the top, the dealt 220×360 cards directly below it in the
/// SAME scroll view (28 px gap), nothing else. The deck NEVER shrinks;
/// scrolling moves the deck off the top edge like a real table camera.
/// Also hosts the Full Spread Overview mode (see [TableViewMode]).
class DigitalTableScreen extends StatefulWidget {
  const DigitalTableScreen({super.key, this.onOpenCameraClarifier});

  /// Shell callback: switches to the Camera tab armed for a single-card
  /// physical clarifier scan (phygital camera-to-table sync).
  final VoidCallback? onOpenCameraClarifier;

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
    this.startScale = 1,
    this.endScale = 1,
  });

  final Offset start; // release point, body-local coordinates
  final Offset target; // slot top-left, body-local coordinates
  final FanLayerPose pose;
  final double velocity;

  /// Card scale at take-off (overview mini-deck flight starts at 90/220).
  final double startScale;

  /// Card scale at landing (overview slots are FittedBox-scaled).
  final double endScale;
}

class _DigitalTableScreenState extends State<DigitalTableScreen>
    with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _overviewStackKey = GlobalKey();
  final GlobalKey _overviewDeckKey = GlobalKey();
  final GlobalKey _spreadCanvasKey = GlobalKey();
  final GlobalKey _intentKey = GlobalKey();

  TableViewMode _viewMode = TableViewMode.focus;

  AnimationController? _flightCtl;
  _CardFlight? _flight;

  // ---- pre-draw intention state (prompt bar above the deck) ----
  final TextEditingController _intentText = TextEditingController();
  String? _selectedChip;
  bool _micListening = false;
  SpeechToText? _speech;

  // ---- synthesis + endless clarifier state ----
  final SynthesisSession _synthesis = SynthesisSession();
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

  /// The spread changed: repaint and, when a clarifier card was flipped
  /// face-up after the synthesis, append its expansion chapter.
  void _onSpreadChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeExpandClarifiers();
  }

  @override
  void dispose() {
    _controller.removeListener(_onSpreadChanged);
    _speech?.stop();
    _intentText.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _flightCtl?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Height of the intention prompt bar above the deck, measured after
  /// layout (reading sizes during build is illegal). Offsets every slot
  /// target below it.
  double _intentBarHeight = 0;
  bool _measureScheduled = false;

  /// Post-frame measurement of the intention bar — one-frame lag at most.
  void _scheduleIntentBarMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final size = _intentKey.currentContext?.size?.height ?? 0;
      if (size != _intentBarHeight) {
        setState(() => _intentBarHeight = size);
      }
    });
  }

  /// Content-space top-left of dealt slot [slotIndex]: intention bar +
  /// deck bottom + the 52 px deck→pillar gap + stacked 220×360 slots with
  /// 56 px thread gaps.
  Offset _slotContentTopLeft(int slotIndex, double contentWidth) => Offset(
        (contentWidth - deckWidth) / 2,
        tableTopPad +
            _intentBarHeight +
            intentBarGapPx +
            deckBoxHeight +
            deckToPillarGap +
            slotIndex * (deckHeight + slotGapPx),
      );

  /// The deck handed us an extracted card: deal the exact grabbed card and
  /// play ONE continuous flight from the release point into its slot.
  /// The camera does NOT follow — the user stays focused on the deck while
  /// pulling multiple cards and scrolls down manually whenever ready.
  /// When the initial spread is full, the pull becomes a Clarifier (+1).
  void _onDealRelease(DeckDealReleaseRequest request) {
    final ctrl = context.read<SpreadController>();
    final slotIndex = ctrl.dealCardAtOrClarifier(request.depth);
    if (slotIndex == null) {
      HapticFeedback.heavyImpact(); // table is full and the deck is empty
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

  /// Stores the pending chip/typed note into the freshly dealt slot and
  /// clears the bar for the next card.
  void _storeIntentionInto(SpreadController ctrl, int slotIndex) {
    final chip = _selectedChip;
    final text = _intentText.text.trim();
    if (chip == null && text.isEmpty) return;
    ctrl.setSlotUserContext(
      slotIndex,
      chip: chip,
      text: text.isEmpty ? null : text,
    );
    setState(() {
      _selectedChip = null;
      _intentText.clear();
    });
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

  /// Overview mode: tapping the compact mini-deck draws the next card into
  /// the spread with a single scaled flight from the deck to its slot.
  /// Once the initial spread is full, the tap appends a Clarifier (+1).
  void _onOverviewDeckTap() {
    final ctrl = context.read<SpreadController>();
    final slotIndex = ctrl.dealNextCardOrClarifier();
    if (slotIndex == null) {
      HapticFeedback.heavyImpact(); // table is full and the deck is empty
      return;
    }
    final stackBox =
        _overviewStackKey.currentContext?.findRenderObject() as RenderBox?;
    final deckBox =
        _overviewDeckKey.currentContext?.findRenderObject() as RenderBox?;
    final canvasBox =
        _spreadCanvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || deckBox == null || canvasBox == null) return;
    final design =
        spreadCanvasDesignSize(ctrl.spreadType, totalSlots: ctrl.slots.length);
    final scale = canvasBox.size.width / design.width;
    final deckCenter = deckBox.localToGlobal(deckBox.size.center(Offset.zero));
    final slotGlobal = canvasBox.localToGlobal(
      spreadSlotDesignTopLeft(
        ctrl.spreadType,
        slotIndex,
        totalSlots: ctrl.slots.length,
      ) *
          scale,
    );
    final start = stackBox.globalToLocal(deckCenter) -
        const Offset(deckWidth / 2, deckHeight / 2);
    final target = stackBox.globalToLocal(slotGlobal);

    HapticFeedback.mediumImpact();
    setState(() {
      _flightCtl = AnimationController(vsync: this);
      _flight = _CardFlight(
        start: start,
        target: target,
        pose: const FanLayerPose(
          dx: 0,
          dy: 0,
          depthZ: 0,
          rotateY: 0,
          rotateX: 0,
          rotateZ: 0,
        ),
        velocity: 0,
        startScale: overviewDeckWidth / deckWidth,
        endScale: scale,
      );
    });
    _flightCtl!
        .animateWith(SpringSimulation(spring, 0, 1, 0))
        .whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() => _flight = null);
      _flightCtl?.dispose();
      _flightCtl = null;
    });
  }

  void _resetTable() {
    HapticFeedback.mediumImpact();
    _synthesis.reset();
    _selectedChip = null;
    _intentText.clear();
    context.read<SpreadController>().resetTable();
  }

  // ---- synthesis + endless clarifiers -----------------------------------

  /// The ceremonial SYNTHESIZE READING pipeline: gathers the complete
  /// payload (cards, orientations, slot roles, pre-draw answers, elemental
  /// balance + thread dynamics) and fills the session.
  Future<void> _runSynthesis() async {
    if (_synthesis.generatingInitial || _synthesis.hasSynthesis) return;
    final ctrl = context.read<SpreadController>();
    setState(() => _synthesis.startGenerating());
    final contexts = {
      for (final s in ctrl.slots)
        if (s.userContext != null) s.index: s.userContext!,
    };
    final result = await OracleSynthesisService().synthesizeStructured(
      slots: ctrl.slots,
      type: ctrl.spreadType,
      slotContexts: contexts,
    );
    if (!mounted) return;
    setState(() => _synthesis.markInitial(result));
    HapticFeedback.mediumImpact();
    _maybeExpandClarifiers();
  }

  /// Spread overview: the synthesis panel opens as a scrollable modal sheet
  /// over the canvas (the overview keeps its one-screen geometry).
  Future<void> _openSynthesisSheet() async {
    if (!_synthesis.hasSynthesis && !_synthesis.generatingInitial) {
      await _runSynthesis();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: SingleChildScrollView(
            child: _buildSynthesisPanel(),
          ),
        ),
      ),
    );
  }

  /// Pull ONE clarifier card from the digital deck with its follow-up
  /// question and fly it into the appended slot.
  void _pullClarifier(String question) {
    final ctrl = context.read<SpreadController>();
    final slotIndex = ctrl.addClarifierSlot(question: question);
    if (slotIndex == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    final deckBox = _deckKey.currentContext?.findRenderObject() as RenderBox?;
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (deckBox == null || contentBox == null) return;
    final start = deckBox
            .localToGlobal(
              Offset(
                deckBox.size.width / 2 - deckWidth / 2,
                deckBox.size.height / 2 - deckHeight / 2,
              ),
              ancestor: contentBox,
            ) +
        const Offset(0, deckHeight);
    _flyCardToSlot(
      slotIndex,
      start: start,
      pose: const FanLayerPose(
        dx: 0,
        dy: 0,
        depthZ: 0,
        rotateY: 0,
        rotateX: 0,
        rotateZ: 0,
      ),
      velocity: 0,
    );
  }

  /// Arm the camera for a single physical clarifier card and switch tabs.
  void _scanClarifier(String question) {
    final ctrl = context.read<SpreadController>();
    ctrl.requestClarifierScan(question);
    widget.onOpenCameraClarifier?.call();
  }

  /// Whenever a clarifier card lands face-up after the synthesis, append
  /// its "Clarifier Expansion" chapter to the reading.
  void _maybeExpandClarifiers() {
    final ctrl = context.read<SpreadController>();
    final session = _synthesis;
    if (!session.hasSynthesis) return;
    for (final s in ctrl.slots) {
      if (s.index < ctrl.initialSpreadCardCount) continue;
      if (s.state != SlotState.faceUp || s.card == null) continue;
      if (session.chapterForSlot(s.index) != null) continue;
      final chapter = ClarifierChapter(
        slotIndex: s.index,
        question: s.userContext ?? 'Clarifier',
        cardName: s.card!.name,
        isReversed: s.isReversed,
      );
      session.addPendingChapter(chapter);
      _generateClarifier(chapter);
    }
  }

  Future<void> _generateClarifier(ClarifierChapter chapter) async {
    final ctrl = context.read<SpreadController>();
    final slot = ctrl.slots.firstWhere((s) => s.index == chapter.slotIndex);
    final previous =
        ctrl.slots.where((s) => s.index < chapter.slotIndex).toList();
    final text = await OracleSynthesisService().synthesizeClarifier(
      question: chapter.question,
      newSlot: slot,
      previous: previous,
    );
    if (!mounted) return;
    _synthesis.completeChapter(chapter.slotIndex, text);
  }

  Future<void> _toggleMic() async {
    if (_micListening) {
      await _speech?.stop();
      setState(() => _micListening = false);
      return;
    }
    _speech ??= SpeechToText();
    bool ok;
    try {
      ok = await _speech!.initialize();
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is not available here — type your thought instead.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _micListening = true);
    await _speech!.listen(
      onResult: (r) {
        _intentText.text = r.recognizedWords;
        _intentText.selection =
            TextSelection.collapsed(offset: _intentText.text.length);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
      ),
    );
    if (mounted) setState(() => _micListening = false);
  }

  /// Mode B — Full Spread Overview: the entire spread on one screen like a
  /// real tarot table. Portrait: compact deck panel on top, the FittedBox
  /// spread canvas below. Landscape: the deck panel sits on the LEFT, the
  /// wide spread canvas expands to the right.
  Widget _buildSpreadOverview(
    SpreadController ctrl,
    TarotDeckPack pack,
    _CardFlight? flight,
  ) {
    final design =
        spreadCanvasDesignSize(ctrl.spreadType, totalSlots: ctrl.slots.length);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final miniDeck = _OverviewDeck(
      key: _overviewDeckKey,
      pack: pack,
      onTap: _onOverviewDeckTap,
    );
    final counterBadge = _DeckCounterBadge(
      ctrl: ctrl,
      onReset: _resetTable,
      dealHint: 'TAP DECK TO DEAL',
    );

    // Portrait: deck above the badge. Landscape (short viewport): the badge
    // sits NEXT to the deck so the panel never overflows vertically.
    final deckPanel = isLandscape
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              miniDeck,
              const SizedBox(width: 12),
              counterBadge,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              miniDeck,
              const SizedBox(height: 8),
              counterBadge,
            ],
          );

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

    final canvas = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        key: _spreadCanvasKey,
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
      ),
    );

    return Stack(
      key: _overviewStackKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: isLandscape
              ? Row(
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
                        child: canvas,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [deckPanel],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: canvas,
                      ),
                    ),
                    if (ctrl.initialSpreadAllFaceUp)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _SynthesizeCta(
                          synthesized: _synthesis.hasSynthesis,
                          onTap: _openSynthesisSheet,
                        ),
                      ),
                  ],
                ),
        ),
        if (flight != null && _flightCtl != null)
          AnimatedBuilder(
            animation: _flightCtl!,
            builder: (context, _) =>
                _flightOverlay(pack, flight, _flightCtl!.value),
          ),
      ],
    );
  }

  /// The flight card, positioned in the active body Stack's local
  /// coordinates: it flies from the release pose and scale (overview
  /// mini-deck = 90/220) to the exact slot rect, landing pixel-perfectly
  /// on the already-materialized slot card.
  Widget _flightOverlay(TarotDeckPack pack, _CardFlight flight, double t) {
    final pos = Offset.lerp(flight.start, flight.target, t)!;
    final scale = flight.startScale + (flight.endScale - flight.startScale) * t;
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final pack = context.watch<DeckPackController>().activePack;
    final flight = _flight;
    _scheduleIntentBarMeasure();
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
                  return _buildSpreadOverview(ctrl, pack, flight);
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
                              // The pre-draw intention prompt above the
                              // deck (or the clarifier prompts once the
                              // reading was synthesized).
                              _buildIntentBar(ctrl),
                              const SizedBox(height: intentBarGapPx),
                              // Full-size 3D deck.
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
                              if (ctrl.initialSpreadAllFaceUp) ...[
                                const SizedBox(height: 20),
                                if (!_synthesis.generatingInitial &&
                                    !_synthesis.hasSynthesis)
                                  _SynthesizeCta(
                                    synthesized: false,
                                    onTap: _runSynthesis,
                                  ),
                                if (_synthesis.generatingInitial ||
                                    _synthesis.hasSynthesis) ...[
                                  const SizedBox(height: 8),
                                  _buildSynthesisPanel(),
                                ],
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        // Live counter badge hugging the deck's bottom
                        // edge — lives at the content-Stack level so its
                        // overlap area stays fully hit-testable.
                        Positioned(
                          top: tableTopPad +
                              _intentBarHeight +
                              intentBarGapPx +
                              deckBoxHeight -
                              11,
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
          _BottomControlBar(
            onSynthesize: _openSynthesisSheet,
            synthesisReady: ctrl.initialSpreadAllFaceUp,
          ),
        ],
      ),
    );
  }
  /// The intention prompt bar above the deck, mode-aware:
  /// 1. slot question + chips while the initial spread is being drawn;
  /// 2. context chips for the photographed cards (physical camera sync);
  /// 3. clarifier follow-up prompts after the synthesis.
  Widget _buildIntentBar(SpreadController ctrl) {
    final nextEmpty = ctrl.nextEmptySlotIndex;
    final cameraSync =
        ctrl.sourceMode == TableSourceMode.physicalCameraSync;

    // 3) Endless clarifier mode: initial spread full + synthesized.
    if (nextEmpty == null && _synthesis.hasSynthesis) {
      return IntentionPromptBar(
        key: _intentKey,
        eyebrow: 'EXPAND THE READING',
        question: 'Pull one more card to deepen the forecast.',
        chips: const [],
        selectedChip: null,
        onChipTap: (_) {},
        controller: _intentText,
        onMicTap: _toggleMic,
        micListening: _micListening,
        actionLabel: cameraSync ? null : 'PULL +1 CARD',
        onAction: () {
          final q = _intentText.text.trim();
          _intentText.clear();
          _pullClarifier(q.isEmpty ? 'What else does the table want to show?' : q);
        },
        extraActions: cameraSync
            ? [
                IntentionBarAction(
                  icon: Icons.photo_camera_outlined,
                  label: '📷 PHOTO +1',
                  onTap: () {
                    final q = _intentText.text.trim();
                    _intentText.clear();
                    _scanClarifier(
                      q.isEmpty
                          ? 'What does the next physical card reveal?'
                          : q,
                    );
                  },
                ),
                IntentionBarAction(
                  icon: Icons.style_outlined,
                  label: '🃏 DIGITAL +1',
                  onTap: () {
                    final q = _intentText.text.trim();
                    _intentText.clear();
                    _pullClarifier(
                      q.isEmpty
                          ? 'What does the digital deck clarify?'
                          : q,
                    );
                  },
                ),
              ]
            : const [],
      );
    }

    // 2) Photographed spread (camera sync), no synthesis yet: attach
    // context to the face-up cards one by one.
    if (cameraSync && ctrl.initialSpreadAllFaceUp) {
      return IntentionPromptBar(
        key: _intentKey,
        eyebrow: 'ADD CONTEXT FOR YOUR CARDS',
        question: 'Why did you draw these cards? Tag the first one.',
        chips: intentionForSlot(0).chips,
        selectedChip: _selectedChip,
        onChipTap: (chip) {
          HapticFeedback.selectionClick();
          setState(() => _selectedChip = _selectedChip == chip ? null : chip);
        },
        controller: _intentText,
        onMicTap: _toggleMic,
        micListening: _micListening,
        actionLabel: 'APPLY',
        inlineAction: true,
        onAction: () {
          final chip = _selectedChip;
          final text = _intentText.text.trim();
          if (chip == null && text.isEmpty) return;
          ctrl.attachContextToNextUntagged(
            chip: chip,
            text: text.isEmpty ? null : text,
          );
          setState(() {
            _selectedChip = null;
            _intentText.clear();
          });
        },
      );
    }

    // 1) Pre-draw intention question for the next slot of the initial
    // spread (or a neutral hint while the cards await the flip).
    final slotPrompt =
        nextEmpty != null ? intentionForSlot(nextEmpty) : null;
    return IntentionPromptBar(
      key: _intentKey,
      eyebrow: nextEmpty != null
          ? 'SLOT ${nextEmpty + 1} · BEFORE YOU DRAW'
          : 'THE TABLE IS SET',
      question: slotPrompt?.question ??
          'Flip the cards face-up to reveal the reading.',
      chips: slotPrompt?.chips ?? const [],
      selectedChip: _selectedChip,
      onChipTap: (chip) {
        HapticFeedback.selectionClick();
        setState(() => _selectedChip = _selectedChip == chip ? null : chip);
      },
      controller: _intentText,
      onMicTap: _toggleMic,
      micListening: _micListening,
    );
  }

  /// The synthesis panel bound to the screen-level session (inline in
  /// focus mode, inside the modal sheet in spread overview mode).
  Widget _buildSynthesisPanel() {
    return ListenableBuilder(
      listenable: _synthesis,
      builder: (context, _) => SynthesisPanel(
        session: _synthesis,
        ctrl: context.read<SpreadController>(),
        onClarifierPull: _pullClarifier,
        onClarifierCamera: _scanClarifier,
      ),
    );
  }
}

class _SynthesizeCta extends StatelessWidget {
  const _SynthesizeCta({required this.synthesized, required this.onTap});

  final bool synthesized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lavender.withValues(alpha: 0.24),
              AppColors.indigo.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lavender, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              synthesized ? '✦ OPEN SYNTHESIS' : '✦ SYNTHESIZE READING',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'СИНТЕЗИРОВАТЬ ПРОГНОЗ',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                letterSpacing: 1.8,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
    final canReset = ctrl.nextEmptySlotIndex == null && onReset != null;
    final String label;
    if (canReset) {
      label = '${ctrl.remaining} · TAP TO RESET · NEW SPREAD';
    } else if (ctrl.nextEmptySlotIndex != null) {
      label = '${ctrl.remaining} · $dealHint';
    } else {
      label = '${ctrl.remaining} · IN DECK';
    }
    return GestureDetector(
      onTap: canReset
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

/// Compact 90×148 mini-deck for the Spread Overview mode: tap to draw the
/// next card into the spread. A few edge rims hint at the physical stack.
class _OverviewDeck extends StatelessWidget {
  const _OverviewDeck({super.key, required this.pack, required this.onTap});

  final TarotDeckPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        key: const ValueKey('overview-deck'),
        width: overviewDeckWidth,
        height: overviewDeckHeight,
        // Only the rounded card itself is rendered — no static backing
        // strip/rectangle above it (same artifact class as the hero deck).
        child: CardBack(
          width: overviewDeckWidth,
          height: overviewDeckHeight,
          pack: pack,
        ),
      ),
    );
  }
}

/// One spread slot on the overview canvas: a subtle hairline placeholder
/// (with its role) while empty, a full interactive TarotCard3DWidget once
/// dealt. Tapping a face-down card flips it; a face-up card opens the
/// reading sheet.
class _OverviewSlot extends StatelessWidget {
  const _OverviewSlot({required this.slot, required this.slotIndex});

  final DealtCardSlot slot;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
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
    return TarotCard3DWidget(
      key: ValueKey('overview-slot-$slotIndex-${slot.state}'),
      card: card,
      isReversed: slot.isReversed,
      state: slot.state,
      width: deckWidth,
      height: deckHeight,
      onFlip: () =>
          context.read<SpreadController>().flipSlot(slot.index),
      onTapFaceUp: () => ReadingBottomSheet.show(context, cardIndex: slot.index),
    );
  }
}

/// Spread method selector + SYNTHESIZE — docked immediately above the
/// bottom navigation bar. Never above the deck, never mid-screen. The
/// SYNTHESIZE pill upgrades to the ceremonial CTA once the spread is
/// dealt and flipped face-up.
class _BottomControlBar extends StatelessWidget {
  const _BottomControlBar({
    required this.onSynthesize,
    required this.synthesisReady,
  });

  final VoidCallback onSynthesize;
  final bool synthesisReady;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        children: [
          for (final type in SpreadType.values) ...[
            Center(
              child: _SpreadPill(
                type: type,
                active: type == ctrl.spreadType,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Center(
            child: Container(
              width: 1,
              height: 24,
              color: AppColors.border,
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: _GlassPill(
              label: synthesisReady
                  ? '✦ SYNTHESIZE READING'
                  : 'SYNTHESIZE',
              onTap: onSynthesize,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpreadPill extends StatelessWidget {
  const _SpreadPill({required this.type, required this.active});

  final SpreadType type;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<SpreadController>().setSpreadType(type);
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          type.label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.2,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Small glass capsule used for header/bottom-bar actions.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.4,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}
