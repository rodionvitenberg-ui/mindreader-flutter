import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/data/intention_prompts.dart' show tableContextChips;
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/models/natal_chart.dart' show ZodiacSignX;
import '../../core/models/reading_mode.dart';
import '../../core/models/reading_source.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/services/ritual_notification_service.dart';
import '../../core/services/spread_check_in_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/astral_controller.dart';
import '../../state/daily_quota_controller.dart';
import '../../state/daily_ritual_controller.dart';
import '../../state/oracle_session_controller.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../../state/synthesis_session.dart';
import '../../state/user_profile_controller.dart';
import '../share/share_card_payload.dart';
import '../share/share_card_preview_sheet.dart';
import '../shell/widgets/pro_subscription_sheet.dart';
import 'digital_table_screen.dart';
import 'oracle_chat_pane.dart';
import 'spread_history_pane.dart';
import 'widgets/analyze_reading_button.dart';
import 'widgets/cosmos_send_burst.dart';
import 'widgets/deal_lock_prompt.dart';
import 'widgets/gemini_input_capsule.dart';
import 'widgets/reading_context_field.dart';
import 'widgets/reading_guide.dart';
import '../../core/l10n/app_strings.dart';

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
    this.onResumeCamera,
    this.astralHandoff,
    this.oracleService,
  });

  /// Shell callback: switches to the Camera tab armed for a single-card
  /// physical clarifier scan (phygital camera-to-table sync).
  final VoidCallback? onOpenCameraClarifier;

  /// Shell callback: switches to the Camera tab to resume a physical flow
  /// (quick scan / live oracle / guided session) — no clarifier armed.
  final VoidCallback? onResumeCamera;

  /// Cross-tab handoff published by the ASTRAL tab; the workspace consumes
  /// it and streams a natal or synastry reading from the Oracle.
  final ValueNotifier<OracleHandoff?>? astralHandoff;
  final OracleSynthesisService? oracleService;

  @override
  State<TableWorkspace> createState() => _TableWorkspaceState();
}

class _TableWorkspaceState extends State<TableWorkspace>
    with TickerProviderStateMixin {
  late final PageController _paneController = PageController();
  int _pane = tablePane;
  late int _readingRevision;
  // The Oracle is also shared with the camera and Astral. Only a conversation
  // started or restored by this table belongs to its current spread.
  int? _tableSessionEpoch;
  bool _restoringSpread = false;
  String? _archivedSpreadSignature;
  bool _recordedReadingDay = false;
  final _dictation = ReadingDictation();
  bool _finishingDraft = false;

  late final SpreadController _ctrl = context.read<SpreadController>();
  late final OracleSessionController _session = context
      .read<OracleSessionController>();
  late final SessionHistoryController _history = context
      .read<SessionHistoryController>();

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
  OracleHandoff? _astralContext;

  @override
  void initState() {
    super.initState();
    _readingRevision = _ctrl.readingRevision;
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
    // The dialogue session and the archive are owned by the root providers —
    // never disposed here.
    super.dispose();
  }

  void _onCosmosStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _cosmosVisible = false);
    }
  }

  String _currentSpreadSignature() {
    final buf = StringBuffer()
      ..write(_ctrl.system.name)
      ..write('|')
      ..write(_ctrl.spreadKey)
      ..write('|')
      ..write(_ctrl.readingQuestion)
      ..write('|')
      ..write(_ctrl.readingForSelf)
      ..write('|')
      ..write(_ctrl.sessionContextNotes.join('\x1f'))
      ..write('|');
    for (final s in _ctrl.slots) {
      buf
        ..write(s.index)
        ..write(':')
        ..write(s.card?.id ?? -1)
        ..write(':')
        ..write(s.state.name)
        ..write(':')
        ..write(s.isReversed ? 'r' : 'u')
        ..write(':')
        ..write(s.userContext ?? '')
        ..write(';');
    }
    return buf.toString();
  }

  void _onSpreadChanged() {
    if (!mounted) return;
    if (_readingRevision != _ctrl.readingRevision) {
      _readingRevision = _ctrl.readingRevision;
      if (_restoringSpread) return;
      _archivedSpreadSignature = null;
      _recordedReadingDay = false;
      if (_sessionKind == SessionKind.divinationSpread) {
        if (_session.epoch == _tableSessionEpoch) _session.reset();
        _tableSessionEpoch = null;
        _sessionTimestamp = null;
      }
    }
    setState(() {});
    _maybeExpandClarifiers();
    // Auto-save spreads dynamically as soon as all base cards are revealed
    // (no AI chat required), and re-upsert whenever extra cards, flips, notes,
    // or questions update the same spread.
    if (_ctrl.isSpreadActive &&
        _ctrl.dealtCount > 0 &&
        (_ctrl.initialSpreadAllFaceUp ||
            (_sessionKind == SessionKind.divinationSpread &&
                _sessionTimestamp != null))) {
      final signature = _currentSpreadSignature();
      if (signature != _archivedSpreadSignature) {
        if (_sessionKind != SessionKind.divinationSpread) {
          _sessionKind = SessionKind.divinationSpread;
          _sessionTimestamp = null;
          _clearAstralContext();
        }
        _captureSession();
        if (!_recordedReadingDay && _ctrl.initialSpreadAllFaceUp) {
          _recordedReadingDay = true;
          final daily = context.read<DailyRitualController?>();
          if (daily != null) {
            daily.recordReadingDayNow();
          } else {
            LocalStorageService()
                .recordReadingDay()
                .then((_) {}, onError: (Object _) {});
          }
        }
      }
    }
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
    _session.reset();
    _sessionTimestamp = DateTime.now().toIso8601String();
    _session.beginSession(sessionId: _sessionTimestamp);
    _sessionKind = _sessionKindFor(handoff.kind);
    _astralTitle = _astralTitleFor(handoff);
    _astralChartId = handoff.chart?.id;
    _astralContext = handoff;

    _session.addUserMessage(handoff.prompt);
    _session.beginAnswer();
    _goToPane(chatPane);
    final epoch = _session.epoch;
    await _captureSession(); // persist the moment the CTA is tapped
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    String answer;
    try {
      answer = await OracleSynthesisService().answerAstral(
        context: handoff,
        history: const [],
      );
    } on OracleQuotaExceededException {
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _session.finishAnswer();
      await ProSubscriptionSheet.show(
        context,
        reason: ProGateReason.oracleMessages,
      );
      return;
    }
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    _session.addOracleMessage(answer);
    _session.finishAnswer();
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
      OracleHandoffKind.natalChart => AppStrings.g('table.astral.natalTitle', {
        'profile': chart?.profileName ?? AppStrings.g('table.astral.natalFallback'),
      }),
      OracleHandoffKind.horoscope => AppStrings.g('table.astral.horoscopeTitle', {
        'profile': chart?.profileName ?? AppStrings.g('table.astral.natalFallback'),
      }),
      OracleHandoffKind.synastry =>
        '${chart?.profileName ?? 'A'} × ${handoff.otherChart?.profileName ?? 'B'}',
      OracleHandoffKind.zodiac => AppStrings.g('table.astral.zodiacTitle', {
        'sign': handoff.zodiacSign?.title ?? AppStrings.g('table.astral.zodiacFallback'),
      }),
    };
  }

  // ---- clarifier expansion (moved from the old synthesis panel) ----

  void _maybeExpandClarifiers() {
    if (!_session.hasSynthesis || _session.epoch != _tableSessionEpoch) return;
    for (final s in _ctrl.slots) {
      final question = s.oracleQuestion;
      if (question == null) continue;
      if (s.state != SlotState.faceUp || s.card == null) continue;
      if (_session.chapterForSlot(s.index) != null) continue;
      final chapter = ClarifierChapter(
        slotIndex: s.index,
        question: question,
        cardName: s.card!.name,
        isReversed: s.isReversed,
      );
      _session.addPendingChapter(chapter);
      _generateClarifier(chapter);
    }
  }

  bool get _forSelf =>
      _ctrl.readingForSelf ??
      context.read<UserProfileController>().readingForSelf;

  String? get _tableSubject => _forSelf
      ? context.read<UserProfileController>().selfOracleContext
      : AppStrings.g('table.subject.other');

  Future<void> _generateClarifier(ClarifierChapter chapter) async {
    final slot = _ctrl.slots.firstWhere((s) => s.index == chapter.slotIndex);
    final previous = _ctrl.slots
        .where((s) => s.index < chapter.slotIndex)
        .toList();
    final epoch = _session.epoch;
    final oracle = widget.oracleService ?? OracleSynthesisService();
    String text;
    try {
      text = await oracle.synthesizeClarifier(
        question: chapter.question,
        newSlot: slot,
        previous: previous,
        profileContext: _tableSubject,
      );
    } on OracleQuotaExceededException {
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _session.completeChapter(
        chapter.slotIndex,
        AppStrings.g('oracle.quota.softClosing'),
      );
      await ProSubscriptionSheet.show(
        context,
        reason: ProGateReason.oracleMessages,
      );
      return;
    } catch (_) {
      text = AppStrings.g('table.oracleFailed');
    }
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    _session.completeChapter(chapter.slotIndex, text);
    await _captureSession();
  }
  // ---- synthesis ----

  // The spread service returns a complete response. Issuing the request
  // only starts the preparation spinner; usable response text opens chat.
  Future<void> _runSynthesis() async {
    if (_finishingDraft || _session.generatingInitial) return;
    if (_session.hasSynthesis) {
      _goToPane(chatPane);
      return;
    }
    if (!_ctrl.canSynthesize) return;
    if (_sessionKind != SessionKind.divinationSpread) {
      _session.reset();
      _sessionKind = SessionKind.divinationSpread;
      _sessionTimestamp = null;
      _clearAstralContext();
    }
    final epoch = _session.epoch;
    _tableSessionEpoch = epoch;
    // Keep the active editor mounted until the recognizer delivers its
    // final result, then leave the table and submit the confirmed draft.
    _finishingDraft = true;
    _session.startGenerating();
    StructuredSynthesis result;
    try {
      try {
        await _dictation.finish();
      } finally {
        _finishingDraft = false;
      }
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _goToPane(chatPane);
      if (!_ctrl.canSynthesize) {
        _session.failInitial();
        return;
      }
      _ctrl.setReadingForSelf(_forSelf);
      final contexts = {
        for (final s in _ctrl.slots)
          if (s.userContext != null) s.index: s.userContext!,
      };
      final lens = [
        if (_ctrl.readingQuestion.trim().isNotEmpty) _ctrl.readingQuestion.trim(),
        ..._ctrl.sessionContextNotes,
      ];
      final oracle = widget.oracleService ?? OracleSynthesisService();
      result = await oracle.synthesizeStructured(
        slots: _ctrl.slots,
        type: _ctrl.spreadType,
        spreadLabel: _ctrl.spreadLabel,
        focusLine: _ctrl.spreadFocusLine,
        system: _ctrl.system,
        contextChip: lens.isEmpty ? null : lens.join(' · '),
        slotContexts: contexts,
        profileContext: _tableSubject,
        positionQuestions: _ctrl.customSpread?.questions,
        relationships: _ctrl.relationships,
      );
    } on OracleQuotaExceededException {
      if (mounted && _session.isCurrentSession(epoch)) {
        _session.failInitial();
        await ProSubscriptionSheet.show(
          context,
          reason: ProGateReason.oracleMessages,
        );
      }
      return;
    } catch (_) {
      if (mounted && _session.isCurrentSession(epoch)) _session.failInitial();
      return;
    }
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    if (result.narrative.trim().isEmpty) {
      _session.failInitial();
      return;
    }
    _session.markInitial(result);
    _sessionTimestamp ??= DateTime.now().toIso8601String();
    // The reading is now an active session: stable id + provenance
    // (source mapped once from the table-level source mode).
    _session.beginSession(
      sessionId: _sessionTimestamp,
      source: ReadingSourceX.fromTableSourceMode(_ctrl.sourceMode),
      mode: ReadingMode.standard,
    );
    _tableSessionEpoch = _session.epoch;
    HapticFeedback.mediumImpact();
    await _captureSession();
  }

  /// Upserts the in-progress session into the local archive: a spread uses
  /// the dealt cards, an Astral reading only its conversation.
  Future<void> _captureSession() async {
    if (_sessionKind != SessionKind.divinationSpread) {
      if (_session.messages.isEmpty) return;
      final timestamp = _sessionTimestamp ?? DateTime.now().toIso8601String();
      _sessionTimestamp = timestamp;
      await _history.upsert(
        SpreadSessionSnapshot.astral(
          timestamp: timestamp,
          kind: _sessionKind,
          title: _astralTitle ?? AppStrings.g('table.astralReading'),
          natalChartId: _astralChartId,
          astralContext: _astralContext,
          messages: [..._session.messages],
        ),
      );
      return;
    }
    if (_ctrl.dealtCount == 0) return;
    if (!_ctrl.initialSpreadAllFaceUp &&
        _sessionTimestamp == null &&
        !_session.hasSynthesis) {
      return;
    }
    _archivedSpreadSignature = _currentSpreadSignature();
    final isNewEntry = _sessionTimestamp == null;
    final timestamp = _sessionTimestamp ?? DateTime.now().toIso8601String();
    _sessionTimestamp = timestamp;
    final existing = _history.findByTimestamp(timestamp);
    final checkInDays = existing?.checkInDays ?? _history.defaultCheckInDays;
    final createdAt = DateTime.tryParse(timestamp) ?? DateTime.now();
    final dueAt =
        existing?.checkInDueAt ??
        createdAt.add(Duration(days: checkInDays)).toIso8601String();
    final ownsDialogue = _session.epoch == _tableSessionEpoch;
    final dialogueSession = ownsDialogue ? _session : SynthesisSession();
    final source = ownsDialogue && _session.sessionId != null
        ? _session.readingSource
        : ReadingSourceX.fromTableSourceMode(_ctrl.sourceMode);
    final mode = ownsDialogue && _session.sessionId != null
        ? _session.readingMode
        : ReadingMode.standard;
    final snapshot = SpreadSessionSnapshot.capture(
      ctrl: _ctrl,
      session: dialogueSession,
      timestamp: timestamp,
      notebook: SessionHistoryController.notebookFor(_ctrl),
      readingForSelf: _forSelf,
      sessionId: ownsDialogue ? (_session.sessionId ?? timestamp) : timestamp,
      readingSource: source,
      readingMode: mode,
      readingStatus: ownsDialogue ? _session.readingStatus : null,
      checkInDays: checkInDays,
      checkInDueAt: dueAt,
      outcome: existing?.outcome,
      reflectionNote: existing?.reflectionNote,
      reflectedAt: existing?.reflectedAt,
      checkInDismissed: existing?.checkInDismissed ?? false,
    );
    await _history.upsert(snapshot);
    if (isNewEntry) {
      final dueDate = DateTime.tryParse(dueAt);
      if (dueDate != null) {
        RitualNotificationService.scheduleSpreadCheckIn(
          sessionTimestamp: timestamp,
          dueAt: dueDate,
          prompt: SpreadCheckInService.promptFor(
            snapshot,
            AppStrings.current,
            now: dueDate,
          ),
        ).then((_) {}, onError: (Object _) {});
      }
    }
  }

  // ---- Oracle AI Chat (Pane 1) ----

  Future<void> _askOracle(String question) async {
    if (_sessionKind == SessionKind.divinationSpread &&
        !_session.hasSynthesis) {
      _session.addSystemMessage(
        AppStrings.g('table.notSynthesized'),
      );
      return;
    }
    final isPro =
        context.read<AppSettingsController?>()?.isProUnlocked ?? false;
    final quota = context.read<DailyQuotaController?>();
    final skipSyntheticFirst =
        _sessionKind != SessionKind.divinationSpread &&
        _session.messages.isNotEmpty &&
        _session.messages.first.role == 'user';
    final sentByUser = _session.messages
        .skip(skipSyntheticFirst ? 1 : 0)
        .where((m) => m.role == 'user')
        .length;
    if (quota != null &&
        !quota.canSendOracleMessage(sentByUser, isPro: isPro)) {
      final closing = AppStrings.g('oracle.quota.softClosing');
      final alreadyClosed = _session.messages.isNotEmpty &&
          _session.messages.last.role == 'oracle' &&
          _session.messages.last.text == closing;
      if (!alreadyClosed) {
        _session.addOracleMessage(closing);
      }
      // Preserve the user's typed prompt across GeminiInputCapsule's clear()
      // so they don't lose their question after unlocking PRO.
      Future<void>.microtask(() {
        if (mounted && _capsuleText.text.isEmpty) {
          _capsuleText.value = TextEditingValue(
            text: question,
            selection: TextSelection.collapsed(offset: question.length),
          );
        }
      });
      await ProSubscriptionSheet.show(
        context,
        reason: ProGateReason.oracleMessages,
      );
      return;
    }
    _session.addUserMessage(question);
    _session.beginAnswer();
    final isSpread = _sessionKind == SessionKind.divinationSpread;
    final profileContext = isSpread ? _tableSubject : null;
    final epoch = _session.epoch;
    await _captureSession(); // persist the turn immediately
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    final oracle = OracleSynthesisService();
    String answer;
    try {
      answer = isSpread
          ? await oracle.answerChat(
              question: question,
              slots: _ctrl.slots,
              type: _ctrl.spreadType,
              spreadLabel: _ctrl.spreadLabel,
              history: _session.messages,
              profileContext: profileContext,
            )
          : await oracle.answerAstral(
              context: _astralContext,
              question: question,
              history: _session.messages.skip(1).toList(),
            );
    } on OracleQuotaExceededException {
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _session.finishAnswer();
      await ProSubscriptionSheet.show(
        context,
        reason: ProGateReason.oracleMessages,
      );
      return;
    }
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    _session.addOracleMessage(answer);
    _session.finishAnswer();
    await _captureSession();
  }

  // ---- Context actions from the existing composer menu ----

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

  void _playCosmos(String label) {
    _cosmosLabel = label;
    setState(() => _cosmosVisible = true);
    _cosmosCtl.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  // ---- Additional cards from the Oracle ----

  bool _requestClarifierForQuestion(String question) {
    if (!_session.hasSynthesis || _tableSessionEpoch != _session.epoch) {
      return false;
    }
    if (_session.chapters.any((chapter) =>
        chapter.generating && chapter.question == question.trim())) {
      return false;
    }
    if (_ctrl.drawOracleClarifier(question) == null) {
      showDealLockPrompt(context, _ctrl);
      return false;
    }
    HapticFeedback.mediumImpact();
    return true;
  }

  void _scanClarifier() {
    if (widget.onOpenCameraClarifier == null) return;
    if (_ctrl.clarifierScanRequested ||
        _ctrl.requestClarifierScan(AppStrings.g('table.clarifierQuestion'))) {
      widget.onOpenCameraClarifier!();
    } else {
      showDealLockPrompt(context, _ctrl);
    }
  }

  // ---- history (Pane 2) ----

  Future<void> _newSpread() async {
    await _captureSession(); // persist the current reading before leaving
    _sessionTimestamp = null;
    _archivedSpreadSignature = null;
    _recordedReadingDay = false;
    _sessionKind = SessionKind.divinationSpread;
    _clearAstralContext();
    _session.reset();
    _ctrl.exitSpread();
    HapticFeedback.mediumImpact();
    _goToPane(tablePane);
  }

  void _clearAstralContext() {
    _astralTitle = null;
    _astralChartId = null;
    _astralContext = null;
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
      _restoringSpread = true;
      try {
        _ctrl.restoreSpread(
          system: snapshot.system,
          type: snapshot.spreadType,
          lenormandSpread: snapshot.lenormandSpread,
          runeCast: snapshot.runeCast,
          customSpread: snapshot.customSpread,
          customQuestions: snapshot.customQuestions,
          compareNeighbors: snapshot.compareNeighbors,
          cards: snapshot.toRestoreCards(),
          sessionNotes: snapshot.sessionNotes,
          readingQuestion: snapshot.readingQuestion,
          readingForSelf: snapshot.readingForSelf,
          oracleQuestions: snapshot.oracleQuestions,
          faceDownCards: snapshot.faceDownCards,
          physicalCards: snapshot.physicalCards,
          sourceMode: snapshot.readingSource?.tableSourceMode ??
              TableSourceMode.physicalCameraSync,
        );
      } finally {
        _restoringSpread = false;
      }
      _session.restoreSession(
        initial: snapshot.synthesis,
        chapters: snapshot.chapters,
        messages: snapshot.messages,
        sessionId: snapshot.sessionId,
        readingSource: snapshot.readingSource,
        readingMode: snapshot.readingMode,
        readingStatus: snapshot.readingStatus,
      );
      _tableSessionEpoch = _session.epoch;
      _archivedSpreadSignature = _currentSpreadSignature();
      _recordedReadingDay = true;
      _maybeExpandClarifiers();
    } else {
      _clearAstralContext();
      _astralTitle = snapshot.astralSessionTitle;
      _astralChartId = snapshot.natalChartId;
      _astralContext = snapshot.astralContext;
      if (_astralContext == null &&
          snapshot.natalChartId != null &&
          snapshot.kind != SessionKind.synastryReading) {
        final chart = context
            .read<AstralController>()
            .profiles
            .where((p) => p.id == snapshot.natalChartId)
            .firstOrNull;
        if (chart != null) {
          _astralContext = OracleHandoff(
            prompt: '',
            kind: snapshot.kind == SessionKind.horoscopeReading
                ? OracleHandoffKind.horoscope
                : OracleHandoffKind.natalChart,
            chart: chart,
            horoscope: snapshot.kind == SessionKind.horoscopeReading
                ? NatalCalculatorService.computeDailyHoroscope(
                    chart,
                    forDate: DateTime.tryParse(snapshot.timestamp),
                  )
                : null,
          );
        }
      }
      _session.restoreSession(
        initial: null,
        chapters: const [],
        messages: snapshot.messages,
        sessionId: snapshot.sessionId,
        readingSource: snapshot.readingSource,
        readingMode: snapshot.readingMode,
        readingStatus: snapshot.readingStatus,
      );
    }
    HapticFeedback.mediumImpact();
    // Spreads with AI dialogue (or Astral readings) open on Oracle Chat;
    // standalone spreads saved without AI open directly on the Digital Table.
    final hasAiDialogue =
        snapshot.kind != SessionKind.divinationSpread ||
        snapshot.synthesis != null ||
        snapshot.messages.isNotEmpty;
    _goToPane(hasAiDialogue ? chatPane : tablePane);
  }

  void _openShareCurrentSpread() {
    if (!_ctrl.initialSpreadAllFaceUp) return;
    final lang =
        context.read<AppSettingsController?>()?.language ?? AppStrings.current;
    final ownsDialogue = _session.epoch == _tableSessionEpoch;
    final payload = ShareCardPayload.fromTable(
      ctrl: _ctrl,
      session: ownsDialogue ? _session : null,
      lang: lang,
    );
    ShareCardPreviewSheet.show(context, payload: payload);
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
    showTaroGlassSheet<void>(
      context: context,
      builder: (sheetContext) => TaroGlassSheet(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.g('ui.table_workspace.add_to_the_reading'),
              style: AppTypography.label(
                fontSize: 9.5,
                letterSpacing: 1.2,
                color: TaroColors.lavender,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in tableContextChips)
                  TaroGlassChip(
                    label: chip,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _sendChipToEther(chip);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _SheetAction(
              label: AppStrings.g('ui.table_workspace.attach_camera_card'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _scanClarifier();
              },
            ),
            const SizedBox(height: 8),
            _SheetAction(
              label: AppStrings.g('ui.table_workspace.new_spread'),
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
    final session = context.watch<OracleSessionController>();
    final isSpread = _sessionKind == SessionKind.divinationSpread;
    final inConversation =
        session.hasSynthesis ||
        (isSpread
            ? session.messages.any(
                (message) =>
                    message.role == 'oracle' && message.text.trim().isNotEmpty,
              )
            : session.messages.isNotEmpty);
    return Provider.value(
      value: _dictation,
      child: SafeArea(
        top: false,
        bottom: false,
        child: PageView(
          controller: _paneController,
          onPageChanged: (index) {
            HapticFeedback.selectionClick();
            _pane = index;
          },
          // Keep PageView panes outside any full-screen TaroGlassLayer: each
          // glass chrome control owns its own tight local layer so sideways
          // swipes never blur full-screen union bounds or paint ghost shells.
          children: <Widget>[
            Column(
              children: [
                const Expanded(child: DigitalTableScreen()),
                const ReadingGuide(),
                if (ctrl.sourceMode == TableSourceMode.physicalCameraSync)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: TaroGlassLayer(
                      child: TaroGlassPill(
                        key: ValueKey('physical-sync-ribbon'),
                        label: AppStrings.g('ui.table_workspace.physical_sync'),
                        icon: Icons.photo_camera_front_outlined,
                        accentColor: TaroColors.dawn,
                      ),
                    ),
                  ),
                if (ctrl.isSpreadActive) _buildFooter(ctrl, onTable: true),
              ],
            ),
            OracleChatPane(
              session: session,
              inConversation: inConversation,
              showReadingCards: isSpread,
              readingKey: session.sessionId ?? _sessionTimestamp ?? session.epoch,
              capsuleText: _capsuleText,
              composer: inConversation ? _buildFooter(ctrl, onTable: false) : null,
              onBackToTable: () => _goToPane(tablePane),
              onSynthesize: _runSynthesis,
              onClarifierQuestion: _requestClarifierForQuestion,
              onFocusInput: () => _capsuleFocus.requestFocus(),
              onScanClarifier: _scanClarifier,
              onResumeCamera: () => widget.onResumeCamera?.call(),
              onShareSpread: ctrl.initialSpreadAllFaceUp
                  ? _openShareCurrentSpread
                  : null,
            ),
            SpreadHistoryPane(
              history: _history,
              onNewSpread: _newSpread,
              onRestore: _restoreSession,
              onBackToTable: () => _goToPane(tablePane),
            ),
          ],
        ),
      ),
    );
  }

  /// Active dealing view (Step 2) anchors Analyze Reading above the dock.
  /// Pane 1 (Oracle Conversation) uses the same anchored capsule
  /// independently of the message viewport.
  Widget _buildFooter(SpreadController ctrl, {required bool onTable}) {
    final clarifier = ctrl.pendingClarifierQuestion;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTable) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    TaroGlassLayer(
                      child: ShareSpreadButton(
                        key: const ValueKey('share-spread-button'),
                        enabled:
                            ctrl.isSpreadActive && ctrl.initialSpreadAllFaceUp,
                        onPressed: _openShareCurrentSpread,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TaroGlassLayer(
                        child: AnalyzeReadingButton(
                          key: const ValueKey('analyze-reading-button'),
                          padding: EdgeInsets.zero,
                          enabled:
                              ctrl.isSpreadActive &&
                              (ctrl.canSynthesize || _session.hasSynthesis) &&
                              !_session.generatingInitial,
                          onPressed: () => _goToPane(chatPane),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TaroGlassLayer(
                      child: ResetTableButton(
                        key: const ValueKey('reset-table-button'),
                        enabled:
                            ctrl.allDealt &&
                            ctrl.dealtCount >= ctrl.initialSpreadCardCount,
                        onPressed: ctrl.resetTable,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TaroGlassLayer(
                child: GeminiInputCapsule(
                  fieldKey: const ValueKey('oracle-input'),
                  sendKey: const ValueKey('oracle-send'),
                  controller: _capsuleText,
                  focusNode: _capsuleFocus,
                  hint: AppStrings.g('table.oracleHint'),
                  onSend: _askOracle,
                  onPlus: _openPlusSheet,
                ),
              ),
            ],
          ],
        ),
        if (onTable && clarifier != null)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: _ClarifierBanner(
              question: clarifier,
              onCancel: ctrl.cancelClarifierScan,
            ),
          ),
        if (!onTable && _cosmosVisible)
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: CosmosSendBurst(animation: _cosmosCtl, label: _cosmosLabel),
          ),
      ],
    );
  }
}

/// A pending camera scan can be cancelled from the table.
class _ClarifierBanner extends StatelessWidget {
  const _ClarifierBanner({required this.question, required this.onCancel});

  final String question;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('clarifier-banner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TaroColors.lavender.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaroColors.lavender.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🃏', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppStrings.g('table.cameraClarifier', {'question': question}),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: TaroColors.lavender,
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.g('ui.table_workspace.cancel_clarifier'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: TaroColors.lavender),
            onPressed: onCancel,
          ),
        ],
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
    return TaroGlassButton(
      label: label,
      variant: TaroGlassButtonVariant.secondary,
      onPressed: onTap,
    );
  }
}
