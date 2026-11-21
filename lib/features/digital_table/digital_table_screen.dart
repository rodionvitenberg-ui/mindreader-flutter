import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/rune_stone.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/models/tarot_deck_pack.dart';
import '../../core/theme/card_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import '../profile/widgets/profile_header.dart';
import 'widgets/board_pillar_view.dart';
import 'widgets/reading_guide.dart';
import 'widgets/custom_spread_sheet.dart';
import 'widgets/deal_lock_prompt.dart';
import 'widgets/foil_glint.dart';
import 'widgets/interactive_deck_widget.dart';
import 'widgets/interactive_rune_stones_widget.dart';
import 'widgets/reading_bottom_sheet.dart';
import 'widgets/rune_stone_3d_widget.dart';
import 'widgets/shuffle_physics.dart';
import 'widgets/spread_blueprint_grid.dart';
import 'widgets/spread_board.dart';
import 'widgets/tarot_card_3d_widget.dart';

/// The two switchable view modes of the Digital Table.
enum TableViewMode {
  /// Mode A — tactile focus: full-size 220×360 deck at the top + full-size
  /// dealt cards below in ONE unified vertical scroll canvas. No
  /// auto-scroll on deal — the camera stays on the deck.
  focus,

  /// An interactive overhead view of the complete spread.
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

  /// Hook on the [ FOCUS VIEW | SPREAD VIEW ] toggle for a future onboarding
  /// tooltip (kept as a stable key; no consumer yet).
  final GlobalKey _viewModeToggleKey = GlobalKey();

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
    final start =
        deckBox.localToGlobal(Offset.zero, ancestor: contentBox) +
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
    final start =
        deckBox.localToGlobal(Offset.zero, ancestor: contentBox) +
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
        .animateWith(
          SpringSimulation(
            spring,
            0,
            1,
            (velocity / distance).clamp(-8.0, 8.0),
          ),
        )
        .whenCompleteOrCancel(() {
          if (!mounted) return;
          setState(() => _flight = null);
          _flightCtl?.dispose();
          _flightCtl = null;
        });
  }

  Future<void> _inspect(int index) =>
      ReadingBottomSheet.show(context, cardIndex: index);

  int? _dealOverviewPiece() {
    final ctrl = context.read<SpreadController>();
    final clarifier = ctrl.nextEmptySlotIndex == null;
    final index = ctrl.dealNextCardOrClarifier();
    if (index != null && !clarifier && ctrl.system != DivinationSystem.runes) {
      _storeIntentionInto(ctrl, index);
    }
    return index;
  }

  void _resetTable() {
    HapticFeedback.mediumImpact();
    context.read<SpreadController>().resetTable();
  }

  /// The flight card for the Focus pillar,
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
        styleOverride: context
            .read<DeckPackController>()
            .activeLenormandPack
            .backStyle,
        accentOverride: context
            .read<DeckPackController>()
            .activeLenormandPack
            .backAccentArgb,
        secondaryOverride: context
            .read<DeckPackController>()
            .activeLenormandPack
            .backSecondaryArgb,
      ),
      DivinationSystem.runes => const Center(
        child: SizedBox(width: 150, height: 178, child: _FlightStone()),
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
    // Step 1 — the pre-table spread selection view (default entry state):
    // avatar + system switcher + "Choose Spread" + one swipeable spread row.
    if (!ctrl.isSpreadActive) {
      return const _SpreadSelectionView();
    }
    final pack = context.watch<DeckPackController>().activePack;
    final flight = _flight;
    final canReset =
        ctrl.allDealt && ctrl.dealtCount >= ctrl.initialSpreadCardCount;
    final viewMode = ctrl.isSpreadOverview
        ? TableViewMode.spread
        : TableViewMode.focus;
    final header = _ActiveTableHeader(
      mode: viewMode,
      toggleKey: _viewModeToggleKey,
      onModeChanged: (mode) {
        HapticFeedback.selectionClick();
        ctrl.setSpreadOverview(mode == TableViewMode.spread);
      },
      onBack: () {
        HapticFeedback.selectionClick();
        ctrl.exitSpread();
      },
    );
    if (ctrl.isSpreadOverview) {
      return SafeArea(
        bottom: false,
        child: SpreadBoard(
          key: ValueKey(ctrl.readingRevision),
          header: header,
          onDeal: _dealOverviewPiece,
          inspect: _inspect,
          badge: _ResetTableButton(enabled: canReset, onReset: _resetTable),
        ),
      );
    }
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          SizedBox(height: ProfileHeader.actionSize, child: header),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                                child: GuideHighlight(child: ctrl.system == DivinationSystem.runes
                                    ? InteractiveRuneStonesWidget(
                                        key: _deckKey,
                                        onCastRelease: _onRuneCastRelease,
                                      )
                                    : InteractiveDeckWidget(
                                        key: _deckKey,
                                        onDealRelease: _onDealRelease,
                                      )),
                              ),
                              const SizedBox(height: deckToPillarGap),
                              BoardPillarView(
                                onTapFaceUp: _inspect,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        // Reset button hugging the deck's bottom
                        // edge — lives at the content-Stack level so its
                        // overlap area stays fully hit-testable.
                        Positioned(
                          top: tableTopPad + deckBoxHeight - 11,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _ResetTableButton(
                              enabled: canReset,
                              onReset: _resetTable,
                            ),
                          ),
                        ),
                        if (flight != null && _flightCtl != null)
                          AnimatedBuilder(
                            animation: _flightCtl!,
                            builder: (context, _) => _flightOverlay(
                              ctrl.system,
                              pack,
                              flight,
                              _flightCtl!.value,
                            ),
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

/// Step 2 header — the clean active-table bar: the `←` back button (top-left)
/// that exits the spread back to Step 1, and the reordered
/// `[SPREAD VIEW | FOCUS VIEW]` toggle (SPREAD VIEW first/left, default).
class _ActiveTableHeader extends StatelessWidget {
  const _ActiveTableHeader({
    required this.mode,
    required this.toggleKey,
    required this.onModeChanged,
    required this.onBack,
  });

  final TableViewMode mode;
  final GlobalKey toggleKey;
  final ValueChanged<TableViewMode> onModeChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ProfileHeader(
      leading: BackButton(
        key: const ValueKey('table-back-button'),
        color: TaroColors.lavender,
        onPressed: onBack,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _ViewModeToggle(
            key: toggleKey,
            mode: mode,
            onChanged: onModeChanged,
          ),
        ),
      ),
    );
  }
}

class _SpreadSelectionView extends StatelessWidget {
  const _SpreadSelectionView();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ProfileHeader(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _SystemSelector(ctrl: context.watch<SpreadController>()),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Text(
                      AppStrings.t(lang, 'spread.choose'),
                      style: AppTypography.display(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ),
                  const SpreadBlueprintGrid(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _CustomSpreadAction(
                      lang: lang,
                      onTap: () => CustomSpreadSheet.show(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSpreadAction extends StatelessWidget {
  const _CustomSpreadAction({required this.lang, required this.onTap});

  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.t(lang, 'spread.custom'),
      child: GestureDetector(
        key: const ValueKey('custom-spread-button'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TaroGlassPanel(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          tint: TaroColors.lavender.withValues(alpha: 0.10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TaroColors.lavender.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: TaroColors.lavender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(lang, 'spread.custom'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.t(lang, 'spread.customSubtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        fontSize: 11,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: TaroColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The TAROT | LENORMAND | RUNES segmented system selector.
class _SystemSelector extends StatelessWidget {
  const _SystemSelector({required this.ctrl});

  final SpreadController ctrl;

  @override
  Widget build(BuildContext context) {
    return TaroGlassSurface(
      radius: TaroRadii.segment,
      fillColor: TaroColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(2),
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
      ),
    );
  }
}

/// Spread ↔ Focus view switch in the top table bar (pill segmented toggle):
/// SPREAD VIEW first (left, active by default), FOCUS VIEW second (right).
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TableViewMode mode;
  final ValueChanged<TableViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaroGlassSurface(
      radius: TaroRadii.segment,
      fillColor: TaroColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSegment(
              label: 'SPREAD VIEW',
              active: mode == TableViewMode.spread,
              onTap: () => onChanged(TableViewMode.spread),
            ),
            _ModeSegment(
              label: 'FOCUS VIEW',
              active: mode == TableViewMode.focus,
              onTap: () => onChanged(TableViewMode.focus),
            ),
          ],
        ),
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
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? TaroColors.lavender.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: active ? TaroColors.textPrimary : TaroColors.textSecondary,
            ),
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
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? TaroColors.lavender.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: active ? TaroColors.textPrimary : TaroColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Resets the current table after the last card or rune is dealt.
class _ResetTableButton extends StatelessWidget {
  const _ResetTableButton({required this.enabled, required this.onReset});

  final bool enabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'TAP TO RESET',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onReset : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: enabled
                ? TaroColors.lavender.withValues(alpha: 0.16)
                : TaroColors.surface.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: enabled
                  ? TaroColors.lavender.withValues(alpha: 0.55)
                  : TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
          ),
          child: Text(
            'TAP TO RESET',
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.9,
              color: enabled ? TaroColors.lavender : TaroColors.textDisabled,
            ),
          ),
        ),
      ),
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
