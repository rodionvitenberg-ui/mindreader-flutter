import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/data/intention_prompts.dart' show tableContextChips;
import '../../core/models/dealt_card_slot.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../../state/synthesis_session.dart';
import 'digital_table_screen.dart';
import 'oracle_chat_pane.dart';
import 'spread_history_pane.dart';
import 'widgets/cosmos_send_burst.dart';
import 'widgets/gemini_input_capsule.dart';

/// Pane indices of the 3-screen horizontal workspace.
const tablePane = 0;
const chatPane = 1;
const historyPane = 2;

/// Fixed height of the 3-pill pane indicator above the PageView (used by
/// tests to compute the deck's resting position).
const paneIndicatorHeight = 34.0;

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
  const TableWorkspace({super.key, this.onOpenCameraClarifier});

  /// Shell callback: switches to the Camera tab armed for a single-card
  /// physical clarifier scan (phygital camera-to-table sync).
  final VoidCallback? onOpenCameraClarifier;

  @override
  State<TableWorkspace> createState() => _TableWorkspaceState();
}

class _TableWorkspaceState extends State<TableWorkspace>
    with TickerProviderStateMixin {
  late final PageController _paneController = PageController();
  int _pane = tablePane;

  late final SpreadController _ctrl = context.read<SpreadController>();
  final SynthesisSession _synthesis = SynthesisSession();
  final SessionHistoryController _history = SessionHistoryController();

  late final AnimationController _cosmosCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  String _cosmosLabel = '';
  bool _cosmosVisible = false;

  /// Identity of the in-progress session in the local archive (set on the
  /// first synthesis so later chat turns upsert the same entry).
  String? _sessionTimestamp;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onSpreadChanged);
    _cosmosCtl.addStatusListener(_onCosmosStatus);
    _history.load();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onSpreadChanged);
    _paneController.dispose();
    _cosmosCtl.dispose();
    _synthesis.dispose();
    _history.dispose();
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
      contextChip: _ctrl.sessionContextNotes.isEmpty
          ? null
          : _ctrl.sessionContextNotes.join(' · '),
      slotContexts: contexts,
    );
    if (!mounted) return;
    _synthesis.markInitial(result);
    _sessionTimestamp ??= DateTime.now().toIso8601String();
    await _captureSession();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _goToPane(chatPane);
  }

  /// Upserts the in-progress session into the local archive.
  Future<void> _captureSession() async {
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
    if (!_synthesis.hasSynthesis) {
      _synthesis.addSystemMessage(
        'The reading is not synthesized yet — deal and flip your spread '
        'on the table, then tap ✦ SYNTHESIZE IN CHAT.',
      );
      return;
    }
    _synthesis.addUserMessage(question);
    _synthesis.beginAnswer();
    final answer = await OracleSynthesisService().answerChat(
      question: question,
      slots: _ctrl.slots,
      type: _ctrl.spreadType,
      history: _synthesis.messages,
    );
    if (!mounted) return;
    _synthesis.addOracleMessage(answer);
    _synthesis.finishAnswer();
    await _captureSession();
  }

  // ---- Digital Table context → the ether (Pane 0) ----

  void _sendToEther(String text) {
    _ctrl.addSessionContextNote(text);
    _ctrl.queueContext(note: text);
    if (_ctrl.sourceMode == TableSourceMode.physicalCameraSync) {
      _ctrl.attachContextToNextUntagged(text: text);
      _ctrl.clearPendingContext();
    }
    _playCosmos(text);
  }

  void _sendChipToEther(String chip) {
    _ctrl.addSessionContextNote(chip);
    _ctrl.queueContext(chip: chip);
    if (_ctrl.sourceMode == TableSourceMode.physicalCameraSync) {
      _ctrl.attachContextToNextUntagged(chip: chip);
      _ctrl.clearPendingContext();
    }
    _playCosmos(chip);
  }

  void _playCosmos(String label) {
    _cosmosLabel = label;
    setState(() => _cosmosVisible = true);
    _cosmosCtl.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  // ---- clarifiers ----

  void _pullClarifier() {
    final slotIndex = _ctrl.addClarifierSlot(
      question: 'What else does the table want to show?',
    );
    if (slotIndex == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    _synthesis.addSystemMessage(
      'A clarifier was dealt — flip it face-up on the table to hear it '
      'speak.',
    );
    HapticFeedback.selectionClick();
  }

  void _scanClarifier() {
    _ctrl.requestClarifierScan('What else does the table want to show?');
    widget.onOpenCameraClarifier?.call();
  }

  // ---- history (Pane 2) ----

  Future<void> _newSpread() async {
    await _captureSession(); // persist the current reading before leaving
    _sessionTimestamp = null;
    _synthesis.reset();
    _ctrl.resetTable();
    HapticFeedback.mediumImpact();
    _goToPane(tablePane);
  }

  /// 1-tap full session restore: the exact conversation in Pane 1 AND the
  /// exact dealt cards/orientations/threads on Pane 0.
  Future<void> _restoreSession(SpreadSessionSnapshot snapshot) async {
    _ctrl.restoreSpread(
      type: snapshot.spreadType,
      cards: snapshot.toRestoreCards(),
      sessionNotes: snapshot.sessionNotes,
    );
    _synthesis.restore(
      initial: snapshot.synthesis,
      chapters: snapshot.chapters,
      messages: snapshot.messages,
    );
    _sessionTimestamp = snapshot.timestamp;
    HapticFeedback.mediumImpact();
    _goToPane(tablePane);
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
    final hasSynthesis = _synthesis.hasSynthesis;
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
            if (hasSynthesis) ...[
              const SizedBox(height: 8),
              _SheetAction(
                label: '🃏 PULL A CLARIFIER',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pullClarifier();
                },
              ),
            ],
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
          _PaneIndicator(pane: _pane, onTap: _goToPane),
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
                  onBackToTable: () => _goToPane(tablePane),
                  onSynthesize: _runSynthesis,
                  onPullClarifier: _pullClarifier,
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
  /// The shared floating input capsule area: quick-context chips + the
  /// glowing SYNTHESIZE CTA (Table) or plain capsule (Chat), plus the
  /// "Sent to Cosmos" overlay.
  Widget _buildBottomArea(SpreadController ctrl) {
    final onTable = _pane == tablePane;
    final ready = ctrl.initialSpreadAllFaceUp;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTable) ...[
              _QuickContextChips(onChipTap: _sendChipToEther),
              const SizedBox(height: 2),
            ],
            if (onTable && ready) ...[
              _SynthesizeChatCta(
                synthesized: _synthesis.hasSynthesis,
                generating: _synthesis.generatingInitial,
                onTap: _runSynthesis,
              ),
              const SizedBox(height: 2),
            ],
            GeminiInputCapsule(
              fieldKey: const ValueKey('oracle-input'),
              sendKey: const ValueKey('oracle-send'),
              hint: onTable
                  ? 'Add context or ask Oracle...'
                  : 'Ask the Oracle about your spread...',
              onSend: onTable ? _sendToEther : _askOracle,
              onPlus: _openPlusSheet,
            ),
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
}


/// Subtle 3-pill indicator: Table • Oracle Chat • History — 1-tap pane
/// switching on top of the workspace.
class _PaneIndicator extends StatelessWidget {
  const _PaneIndicator({required this.pane, required this.onTap});

  final int pane;
  final ValueChanged<int> onTap;

  static const _labels = ['TABLE', 'ORACLE CHAT', 'HISTORY'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: paneIndicatorHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textMuted,
                ),
              ),
            GestureDetector(
              key: ValueKey('pane-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pane == i
                      ? AppColors.lavender.withValues(alpha: 0.16)
                      : AppColors.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: pane == i ? AppColors.lavender : AppColors.border,
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: pane == i ? AppColors.lavender : AppColors.textMuted,
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

/// Single-line quick-context chips floating above the input capsule on
/// the Digital Table.
class _QuickContextChips extends StatelessWidget {
  const _QuickContextChips({required this.onChipTap});

  final ValueChanged<String> onChipTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < tableContextChips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChipTap(tableContextChips[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                tableContextChips[i],
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The glowing `✦ SYNTHESIZE IN CHAT →` call to action above the capsule.
class _SynthesizeChatCta extends StatelessWidget {
  const _SynthesizeChatCta({
    required this.synthesized,
    required this.generating,
    required this.onTap,
  });

  final bool synthesized;
  final bool generating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (generating) {
      return Text(
        'WEAVING THE READING · · ·',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8.5,
          letterSpacing: 1.8,
          color: AppColors.lavender,
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lavender.withValues(alpha: 0.24),
              AppColors.indigo.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lavender, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.lavender.withValues(alpha: 0.3),
              blurRadius: 14,
            ),
          ],
        ),
        child: Text(
          synthesized ? '✦ OPEN ORACLE CHAT →' : '✦ SYNTHESIZE IN CHAT →',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}

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



