import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/data/intention_prompts.dart' show tableContextChips;
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/models/zodiac_forecast.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/astral_controller.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../../state/synthesis_session.dart';
import '../../state/user_profile_controller.dart';
import 'digital_table_screen.dart';
import 'oracle_chat_pane.dart';
import 'spread_history_pane.dart';
import 'widgets/cosmos_send_burst.dart';
import 'widgets/deal_lock_prompt.dart';
import 'widgets/gemini_input_capsule.dart';
import 'widgets/reading_subject_toggle.dart';
import 'widgets/synthesize_chat_cta.dart';

/// Pane indices of the 3-screen horizontal workspace.
const tablePane = 0;
const chatPane = 1;
const historyPane = 2;

/// The unified TABLE workspace: a horizontal 3-pane `PageView`
/// `[Digital Table] ⇄ [Oracle AI Chat] ⇄ [Spread History & Notebooks]`
/// with the shared Gemini-style floating input capsule docked above the
/// bottom navigation dock. Inspired by the Google Gemini mobile app.
///
/// Gesture disambiguation: the 3D deck (220×360) captures horizontal drags
/// strictly for shuffling (its recognizer sits deepest in the arena and
/// wins); swiping anywhere else — background, header, dealt cards — pans
/// the PageView between panes.
class TableWorkspace extends StatefulWidget {
  const TableWorkspace({
    super.key,
    this.onOpenCameraClarifier,
    this.astralHandoff,
  });

  /// Shell callback: switches to the Camera tab armed for a single-card
  /// physical clarifier scan (phygital camera-to-table sync).
  final VoidCallback? onOpenCameraClarifier;

  /// Cross-tab handoff published by the ASTRAL tab; the workspace consumes
  /// it and streams a natal or synastry reading from the Oracle.
  final ValueNotifier<OracleHandoff?>? astralHandoff;

  @override
  State<TableWorkspace> createState() => _TableWorkspaceState();
}

class _TableWorkspaceState extends State<TableWorkspace>
    with TickerProviderStateMixin {
  late final PageController _paneController = PageController();
  int _pane = tablePane;

  late final SpreadController _ctrl = context.read<SpreadController>();
  final SynthesisSession _synthesis = SynthesisSession();
  late final SessionHistoryController _history =
      context.read<SessionHistoryController>();

  late final AnimationController _cosmosCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  String _cosmosLabel = '';
  bool _cosmosVisible = false;

  /// The shared input capsule's text + focus — owned here so the chat
  /// pane's `+1 CARD FOR MY QUESTION` chip can read the typed question
  /// and pull the keyboard focus programmatically.
  final TextEditingController _capsuleText = TextEditingController();
  final FocusNode _capsuleFocus = FocusNode();

  /// Identity of the in-progress session in the local archive (set on the
  /// first synthesis so later chat turns upsert the same entry).
  String? _sessionTimestamp;

  /// What the in-progress session is (spread vs. Astral reading) + the
  /// context needed to keep answering follow-up questions.
  SessionKind _sessionKind = SessionKind.divinationSpread;
  String? _astralTitle;
  String? _astralChartId;
  NatalChart? _astralChart;
  NatalChart? _astralOtherChart;
  DailyHoroscopeReport? _astralHoroscope;
  ZodiacSign? _astralZodiacSign;
  ZodiacSignForecast? _astralZodiacForecast;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onSpreadChanged);
    _cosmosCtl.addStatusListener(_onCosmosStatus);
    widget.astralHandoff?.addListener(_onAstralHandoff);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onSpreadChanged);
    widget.astralHandoff?.removeListener(_onAstralHandoff);
    _paneController.dispose();
    _cosmosCtl.dispose();
    _capsuleText.dispose();
    _capsuleFocus.dispose();
    _synthesis.dispose();
    // The archive is owned by the root provider — never disposed here.
    super.dispose();
  }

  void _onCosmosStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _cosmosVisible = false);
    }
  }

  void _onSpreadChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeExpandClarifiers();
  }

  // ---- ASTRAL cross-tab handoff (natal / synastry to Oracle Chat) ----

  void _onAstralHandoff() {
    final handoff = widget.astralHandoff?.value;
    if (handoff == null) return;
    widget.astralHandoff!.value = null;
    _runAstralReading(handoff);
  }

  Future<void> _runAstralReading(OracleHandoff handoff) async {
    // A fresh Astral reading replaces the previous astral thread and starts a
    // new history entry (astral dialogues were never persisted before).
    _synthesis.reset();
    _sessionTimestamp = DateTime.now().toIso8601String();
    _sessionKind = _sessionKindFor(handoff.kind);
    _astralTitle = _astralTitleFor(handoff);
    _astralChartId = handoff.chart?.id;
    _astralChart = handoff.chart;
    _astralOtherChart = handoff.otherChart;
    _astralHoroscope = handoff.horoscope;
    _astralZodiacSign = handoff.zodiacSign;
    _astralZodiacForecast = handoff.zodiacForecast;

    _synthesis.addUserMessage(handoff.prompt);
    _synthesis.beginAnswer();
    _goToPane(chatPane);
    await _captureSession(); // persist the moment the CTA is tapped
    final answer = await OracleSynthesisService().synthesizeNatalReading(
      prompt: handoff.prompt,
      chart: handoff.chart,
      otherChart: handoff.otherChart,
      horoscope: handoff.horoscope,
      zodiacSign: handoff.zodiacSign,
      zodiacForecast: handoff.zodiacForecast,
      history: _synthesis.messages,
    );
    if (!mounted) return;
    _synthesis.addOracleMessage(answer);
    _synthesis.finishAnswer();
    await _captureSession();
  }

  static SessionKind _sessionKindFor(OracleHandoffKind kind) => switch (kind) {
        OracleHandoffKind.natalChart => SessionKind.natalChartReading,
        OracleHandoffKind.synastry => SessionKind.synastryReading,
        OracleHandoffKind.horoscope => SessionKind.horoscopeReading,
        OracleHandoffKind.zodiac => SessionKind.zodiacReading,
      };

  static String _astralTitleFor(OracleHandoff handoff) {
    final chart = handoff.chart;
    return switch (handoff.kind) {
      OracleHandoffKind.natalChart => '${chart?.profileName ?? 'Natal'} · Natal',
      OracleHandoffKind.horoscope =>
        '${chart?.profileName ?? 'Natal'} · Horoscope',
      OracleHandoffKind.synastry =>
        '${chart?.profileName ?? 'A'} × ${handoff.otherChart?.profileName ?? 'B'}',
      OracleHandoffKind.zodiac =>
        '${handoff.zodiacSign?.title ?? 'Zodiac'} · Horoscope',
    };
  }

  // ---- clarifier expansion (moved from the old synthesis panel) ----

  void _maybeExpandClarifiers() {
    if (!_synthesis.hasSynthesis) return;
    for (final s in _ctrl.slots) {
      if (s.index < _ctrl.initialSpreadCardCount) continue;
      if (s.state != SlotState.faceUp || s.card == null) continue;
      if (_synthesis.chapterForSlot(s.index) != null) continue;
      final chapter = ClarifierChapter(
        slotIndex: s.index,
        question: s.userContext ?? 'Clarifier',
        cardName: s.card!.name,
        isReversed: s.isReversed,
      );
      _synthesis.addPendingChapter(chapter);
      _generateClarifier(chapter);
    }
  }

  Future<void> _generateClarifier(ClarifierChapter chapter) async {
    final slot = _ctrl.slots.firstWhere((s) => s.index == chapter.slotIndex);
    final previous =
        _ctrl.slots.where((s) => s.index < chapter.slotIndex).toList();
    final text = await OracleSynthesisService().synthesizeClarifier(
      question: chapter.question,
      newSlot: slot,
      previous: previous,
      profileContext: context.read<UserProfileController>().oracleContext,
    );
    if (!mounted) return;
    _synthesis.completeChapter(chapter.slotIndex, text);
    await _captureSession();
  }
  // ---- synthesis ----

  /// Runs the structured AI synthesis and slides the PageView into the
  /// Oracle AI Chat (Pane 1).
  Future<void> _runSynthesis() async {
    if (_synthesis.generatingInitial) return;
    if (_synthesis.hasSynthesis) {
      _goToPane(chatPane);
      return;
    }
    _synthesis.startGenerating();
    setState(() {});
    final contexts = {
      for (final s in _ctrl.slots)
        if (s.userContext != null) s.index: s.userContext!,
    };
    final result = await OracleSynthesisService().synthesizeStructured(
      slots: _ctrl.slots,
      type: _ctrl.spreadType,
      spreadLabel: _ctrl.spreadLabel,
      focusLine: _ctrl.spreadFocusLine,
      system: _ctrl.system,
      contextChip: _ctrl.sessionContextNotes.isEmpty
          ? null
          : _ctrl.sessionContextNotes.join(' · '),
      slotContexts: contexts,
      profileContext: context.read<UserProfileController>().oracleContext,
    );
    if (!mounted) return;
    _synthesis.markInitial(result);
    // A spread synthesized after an Astral reading starts its own history
    // entry instead of overwriting the astral one.
    if (_sessionKind != SessionKind.divinationSpread) _sessionTimestamp = null;
    _sessionKind = SessionKind.divinationSpread;
    _clearAstralContext();
    _sessionTimestamp ??= DateTime.now().toIso8601String();
    await _captureSession();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _goToPane(chatPane);
  }

  /// Upserts the in-progress session into the local archive: a spread uses
  /// the dealt cards, an Astral reading only its conversation.
  Future<void> _captureSession() async {
    if (_sessionKind != SessionKind.divinationSpread) {
      if (_synthesis.messages.isEmpty) return;
      final timestamp = _sessionTimestamp ?? DateTime.now().toIso8601String();
      _sessionTimestamp = timestamp;
      await _history.upsert(SpreadSessionSnapshot.astral(
        timestamp: timestamp,
        kind: _sessionKind,
        title: _astralTitle ?? 'Astral reading',
        natalChartId: _astralChartId,
        messages: [..._synthesis.messages],
      ));
      return;
    }
    if (!_synthesis.hasSynthesis) return;
    final timestamp =
        _sessionTimestamp ?? DateTime.now().toIso8601String();
    _sessionTimestamp = timestamp;
    await _history.upsert(SpreadSessionSnapshot.capture(
      ctrl: _ctrl,
      session: _synthesis,
      timestamp: timestamp,
      notebook: SessionHistoryController.notebookFor(_ctrl),
    ));
  }

  // ---- Oracle AI Chat (Pane 1) ----

  Future<void> _askOracle(String question) async {
    if (_sessionKind == SessionKind.divinationSpread &&
        !_synthesis.hasSynthesis) {
      _synthesis.addSystemMessage(
        'The reading is not synthesized yet — deal and flip your spread '
        'on the table, then tap ✦ SYNTHESIZE IN CHAT.',
      );
      return;
    }
    _synthesis.addUserMessage(question);
    _synthesis.beginAnswer();
    final profileContext =
        context.read<UserProfileController>().oracleContext;
    await _captureSession(); // persist the turn immediately
    final oracle = OracleSynthesisService();
    final answer = _sessionKind == SessionKind.divinationSpread
        ? await oracle.answerChat(
            question: question,
            slots: _ctrl.slots,
            type: _ctrl.spreadType,
            spreadLabel: _ctrl.spreadLabel,
            history: _synthesis.messages,
            profileContext: profileContext,
          )
        : await oracle.synthesizeNatalReading(
            prompt: question,
            chart: _astralChart,
            otherChart: _astralOtherChart,
            horoscope: _astralHoroscope,
            zodiacSign: _astralZodiacSign,
            zodiacForecast: _astralZodiacForecast,
            history: _synthesis.messages,
          );
    if (!mounted) return;
    _synthesis.addOracleMessage(answer);
    _synthesis.finishAnswer();
    await _captureSession();
  }

  // ---- Digital Table context → the ether (Pane 0 chips → Pane 1) ----

  void _sendChipToEther(String chip) {
    // Never duplicate the same context note in the session.
    if (!_ctrl.sessionContextNotes.contains(chip)) {
      _ctrl.addSessionContextNote(chip);
    }
    _ctrl.queueContext(chip: chip);
    if (_ctrl.sourceMode == TableSourceMode.physicalCameraSync) {
      _ctrl.attachContextToNextUntagged(chip: chip);
      _ctrl.clearPendingContext();
    }
    _playCosmos(chip);
  }

  /// The single active context pill in the Oracle Chat pane (radio
  /// behavior) — null when none is selected.
  String? _selectedChip;

  /// Toggles a context pill on the Oracle Chat pane: EXACTLY ONE pill may
  /// be active at a time (tapping it again deselects it). Selection
  /// silently updates the active context state — it NEVER appends
  /// `Context woven into the reading` lines into the chat log.
  void _toggleContextChip(String chip) {
    HapticFeedback.selectionClick();
    final wasSelected = _selectedChip == chip;
    setState(() => _selectedChip = wasSelected ? null : chip);
    if (!wasSelected) _sendChipToEther(chip);
  }

  void _playCosmos(String label) {
    _cosmosLabel = label;
    setState(() => _cosmosVisible = true);
    _cosmosCtl.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  // ---- clarifiers (question-driven +1 unlock loop) ----

  /// Arms the deck for EXACTLY ONE +1 Clarifier Card with [question] (an
  /// AI-suggested follow-up or the reader's own question) and slides back
  /// to the Digital Table, where a subtle banner shows the armed question.
  /// In physical-camera-sync mode the draw routes through the camera.
  void _requestClarifierForQuestion(String question) {
    if (!_ctrl.armClarifierQuestion(question)) {
      showDealLockPrompt(context, _ctrl);
      return;
    }
    if (_ctrl.sourceMode == TableSourceMode.physicalCameraSync) {
      _ctrl.requestClarifierScan(question);
      widget.onOpenCameraClarifier?.call();
      return;
    }
    _synthesis.addSystemMessage(
      'Clarifier armed: "$question" — the deck unlocked exactly one card. '
      'Pull it and flip it face-up to hear the answer.',
    );
    HapticFeedback.mediumImpact();
    _goToPane(tablePane);
  }

  void _scanClarifier() {
    _ctrl.requestClarifierScan(
      _ctrl.pendingClarifierQuestion ?? 'What else does the table want to show?',
    );
    widget.onOpenCameraClarifier?.call();
  }

  // ---- history (Pane 2) ----

  Future<void> _newSpread() async {
    await _captureSession(); // persist the current reading before leaving
    _sessionTimestamp = null;
    _sessionKind = SessionKind.divinationSpread;
    _clearAstralContext();
    _synthesis.reset();
    _ctrl.exitSpread();
    HapticFeedback.mediumImpact();
    _goToPane(tablePane);
  }

  void _clearAstralContext() {
    _astralTitle = null;
    _astralChartId = null;
    _astralChart = null;
    _astralOtherChart = null;
    _astralHoroscope = null;
    _astralZodiacSign = null;
    _astralZodiacForecast = null;
  }

  /// 1-tap full session restore: the exact conversation in Pane 1 AND the
  /// exact dealt cards/orientations/threads on Pane 0.
  Future<void> _restoreSession(SpreadSessionSnapshot snapshot) async {
    _sessionTimestamp = snapshot.timestamp;
    _sessionKind = snapshot.kind;
    _astralTitle = snapshot.astralSessionTitle;
    _astralChartId = snapshot.natalChartId;

    if (snapshot.kind == SessionKind.divinationSpread) {
      _clearAstralContext();
      _ctrl.restoreSpread(
        system: snapshot.system,
        type: snapshot.spreadType,
        lenormandSpread: snapshot.lenormandSpread,
        runeCast: snapshot.runeCast,
        cards: snapshot.toRestoreCards(),
        sessionNotes: snapshot.sessionNotes,
      );
      _synthesis.restore(
        initial: snapshot.synthesis,
        chapters: snapshot.chapters,
        messages: snapshot.messages,
      );
    } else {
      // Astral sessions carry no dealt cards: restore the conversation only
      // and re-resolve the natal context so follow-ups keep the chart.
      _clearAstralContext();
      _astralTitle = snapshot.astralSessionTitle;
      _astralChartId = snapshot.natalChartId;
      if (snapshot.natalChartId != null) {
        final astral = context.read<AstralController>();
        for (final p in astral.profiles) {
          if (p.id == snapshot.natalChartId) {
            _astralChart = p;
            _astralHoroscope = NatalCalculatorService.computeDailyHoroscope(p);
            break;
          }
        }
      }
      _synthesis.restore(
        initial: null,
        chapters: const [],
        messages: snapshot.messages,
      );
    }
    HapticFeedback.mediumImpact();
    // Land on the Oracle Chat: the restored conversation is the first thing
    // the reader sees (not a jarring jump to the raw table).
    _goToPane(chatPane);
  }

  void _goToPane(int pane) {
    if (pane == _pane) return;
    HapticFeedback.selectionClick();
    _paneController.animateToPage(
      pane,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }
  // ---- `+` action sheet (quick context chips / attach camera card) ----

  void _openPlusSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ADD TO THE READING',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 2.2,
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in tableContextChips)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _sendChipToEther(chip);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        chip,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _SheetAction(
              label: '📷 ATTACH CAMERA CARD',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _scanClarifier();
              },
            ),
            const SizedBox(height: 8),
            _SheetAction(
              label: '✦ NEW SPREAD',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _newSpread();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Slim physical-sync ribbon: the table hosts cards photographed
          // from the reader's real deck (the header pill row was decluttered).
          if (_pane == tablePane &&
              ctrl.sourceMode == TableSourceMode.physicalCameraSync)
            Container(
              key: const ValueKey('physical-sync-ribbon'),
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.harmonyCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
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
            ),
          Expanded(
            child: PageView(
              controller: _paneController,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _pane = index);
              },
              children: [
                const DigitalTableScreen(),
                OracleChatPane(
                  session: _synthesis,
                  capsuleText: _capsuleText,
                  onBackToTable: () => _goToPane(tablePane),
                  onSynthesize: _runSynthesis,
                  onClarifierQuestion: _requestClarifierForQuestion,
                  onFocusInput: () => _capsuleFocus.requestFocus(),
                  onScanClarifier: _scanClarifier,
                ),
                SpreadHistoryPane(
                  history: _history,
                  onNewSpread: _newSpread,
                  onRestore: _restoreSession,
                ),
              ],
            ),
          ),
          if (_pane != historyPane) _buildBottomArea(ctrl),
        ],
      ),
    );
  }
  /// Pane 0 (Digital Table): the armed-clarifier banner + the PERMANENT
  /// dormant/ignited ✦ SYNTHESIZE IN CHAT CTA — a pure tactile sanctuary,
  /// no chat UI. Pane 1 (Oracle AI Chat): the context chips + the shared
  /// Gemini input capsule. Plus the "Sent to Cosmos" overlay on either.
  Widget _buildBottomArea(SpreadController ctrl) {
    final onTable = _pane == tablePane;
    // Step 1 (spread selection) is a clean picker — no reading-subject
    // toggle, no synthesize CTA, no clarifier banner.
    if (onTable && !ctrl.isSpreadActive) {
      return const SizedBox.shrink();
    }
    final clarifier = ctrl.pendingClarifierQuestion;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTable) ...[
              if (clarifier != null) ...[
                _ClarifierBanner(question: clarifier),
                const SizedBox(height: 2),
              ],
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: ReadingSubjectToggle(),
              ),
              SynthesizeChatCta(
                key: const ValueKey('synthesize-cta'),
                ignited: ctrl.initialSpreadAllFaceUp,
                synthesized: _synthesis.hasSynthesis,
                generating: _synthesis.generatingInitial,
                faceUp: _baseFaceUp(ctrl),
                total: ctrl.spreadCardCount,
                onTap: _runSynthesis,
              ),
            ] else ...[
              _ChatContextChips(
                selected: _selectedChip,
                onChipTap: _toggleContextChip,
              ),
              const SizedBox(height: 2),
              GeminiInputCapsule(
                fieldKey: const ValueKey('oracle-input'),
                sendKey: const ValueKey('oracle-send'),
                controller: _capsuleText,
                focusNode: _capsuleFocus,
                hint: 'Ask the Oracle — or type a question for a +1 card...',
                onSend: _askOracle,
                onPlus: _openPlusSheet,
              ),
            ],
          ],
        ),
        if (_cosmosVisible)
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: CosmosSendBurst(
              animation: _cosmosCtl,
              label: _cosmosLabel,
            ),
          ),
      ],
    );
  }

  /// Face-up cards among the base spread — the dormant CTA's progress
  /// hint.
  int _baseFaceUp(SpreadController ctrl) {
    var n = 0;
    final limit = ctrl.slots.length < ctrl.spreadCardCount
        ? ctrl.slots.length
        : ctrl.spreadCardCount;
    for (var i = 0; i < limit; i++) {
      if (ctrl.slots[i].state == SlotState.faceUp) n++;
    }
    return n;
  }
}


/// Context pills docked above the input capsule on the Oracle AI Chat
/// pane: SINGLE-SELECT radio behavior (one active pill at a time, tap
/// again to deselect). All 3 pills live in one `Row` of `Expanded`
/// children with equal width, 8 px gaps and 16 px horizontal screen
/// padding — they NEVER change size when tapped and NEVER overflow any
/// screen width. Selection is shown purely by a soft lavender tint
/// (#A78BFA @ 22%) and a glowing 1.2 px lavender border — no ✓ icon,
/// no font/padding growth.
class _ChatContextChips extends StatelessWidget {
  const _ChatContextChips({required this.selected, required this.onChipTap});

  /// The single active pill — null when none is selected.
  final String? selected;
  final ValueChanged<String> onChipTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < tableContextChips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                key: ValueKey('context-chip-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChipTap(tableContextChips[i]),
                child: Container(
                  key: selected == tableContextChips[i]
                      ? ValueKey('context-chip-$i-active')
                      : null,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected == tableContextChips[i]
                        ? AppColors.lavender.withValues(alpha: 0.22)
                        : AppColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected == tableContextChips[i]
                          ? AppColors.lavender
                          : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tableContextChips[i],
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: selected == tableContextChips[i]
                            ? AppColors.lavender
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The subtle banner shown on the Digital Table while a clarifier question
/// is armed: names the active question and reminds the reader that exactly
/// ONE card is unlocked (tap the badge to dismiss).
class _ClarifierBanner extends StatelessWidget {
  const _ClarifierBanner({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('clarifier-banner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🃏', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'CLARIFIER: "$question" — PULL THE UNLOCKED CARD',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The glowing `✦ SYNTHESIZE IN CHAT →` call to action now lives in
/// `widgets/synthesize_chat_cta.dart` — permanently anchored on Pane 0
/// with dormant/ignited states.

/// One action row of the `+` sheet.
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}



