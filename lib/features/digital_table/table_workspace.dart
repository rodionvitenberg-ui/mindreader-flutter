import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/data/intention_prompts.dart' show tableContextChips;
import '../../core/l10n/app_strings.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/natal_chart.dart' show ZodiacSignX;
import '../../core/models/oracle_handoff.dart';
import '../../core/models/oracle_personality.dart';
import '../../core/models/reading_mode.dart';
import '../../core/models/reading_source.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_backend_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/astral_controller.dart';
import '../../state/oracle_session_controller.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../../state/synthesis_session.dart';
import '../../state/user_profile_controller.dart';
import 'digital_table_screen.dart';
import 'oracle_chat_pane.dart';
import 'spread_history_pane.dart';
import 'widgets/analyze_reading_button.dart';
import 'widgets/cosmos_send_burst.dart';
import 'widgets/deal_lock_prompt.dart';
import 'widgets/gemini_input_capsule.dart';
import 'widgets/oracle_personality_selector.dart';
import 'widgets/reading_context_field.dart';
import 'widgets/reading_guide.dart';

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
    this.oracleBackend,
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
  final OracleBackendService? oracleBackend;

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
  (int, int)? _archivedCardCounts;
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

  late final _backend = widget.oracleBackend ?? OracleBackendService();
  final _oraclePreferences = LocalStorageService();
  late final Future<String?> _storedPersonality = _oraclePreferences
      .loadOraclePersonality()
      .catchError((Object _) => null);
  List<OraclePersonality>? _catalogue;
  Future<List<OraclePersonality>>? _catalogueRequest;
  String? _preferredPersonality;
  OraclePersonality? _explicitPersonality;
  bool _useLocalOracle = false;
  RemoteOracleReading? _remoteOracle;
  ({String signature, String id, RemoteOracleReading? reading})? _remoteDraft;

  AppLanguage get _language => context.read<AppSettingsController>().language;

  OraclePersonality _localPersonality(AppLanguage language) =>
      OraclePersonality(
        id: '',
        name: AppStrings.t(language, 'oracle.personality.local'),
        description: AppStrings.t(language, 'oracle.personality.localHint'),
      );

  OraclePersonality? get _chosenPersonality {
    if (_explicitPersonality case final choice?) return choice;
    final catalogue = _catalogue ?? const <OraclePersonality>[];
    return catalogue.where((p) => p.id == _preferredPersonality).firstOrNull ??
        catalogue.where((p) => p.id == 'default').firstOrNull ??
        catalogue.firstOrNull;
  }

  bool get _oracleBusy =>
      _session.generatingInitial ||
      _session.generatingAnswer ||
      _session.hasPendingClarifiers;

  OracleSynthesisService get _legacyOracle =>
      widget.oracleService ??
      OracleSynthesisService(localOnly: _backend.isConfigured);

  Future<List<OraclePersonality>> _loadCatalogue({bool refresh = false}) {
    if (!_backend.isConfigured) return Future.value(const []);
    if (!refresh && _catalogue != null && _catalogue!.isNotEmpty) {
      return Future.value(_catalogue!);
    }
    return _catalogueRequest ??= _fetchCatalogue().whenComplete(() {
      _catalogueRequest = null;
    });
  }

  Future<List<OraclePersonality>> _fetchCatalogue() async {
    List<OraclePersonality> catalogue;
    try {
      _preferredPersonality ??= await _storedPersonality;
      catalogue = await _backend.personalities();
    } catch (_) {
      catalogue = const [];
    }
    if (mounted) setState(() => _catalogue = catalogue);
    return catalogue;
  }

  void _resetOracleBinding() {
    _remoteOracle = null;
    _remoteDraft = null;
    _explicitPersonality = null;
    _useLocalOracle = false;
  }

  Future<void> _pickPersonality() async {
    if (_oracleBusy) return;
    final epoch = _session.epoch;
    final hasConversation =
        _session.hasSynthesis || _session.messages.isNotEmpty;
    final language = _language;
    final choice = await showOraclePersonalities(
      context,
      catalogue: _loadCatalogue(refresh: true),
      selected: () =>
          _remoteOracle?.personalityId ??
          (hasConversation || _useLocalOracle ? '' : _chosenPersonality?.id),
      language: language,
      local: _localPersonality(language),
    );
    if (choice == null ||
        !mounted ||
        !_session.isCurrentSession(epoch) ||
        _oracleBusy) {
      return;
    }
    if (hasConversation) {
      if (choice.id == (_remoteOracle?.personalityId ?? '')) return;
      final handoff = _astralContext;
      if (_sessionKind != SessionKind.divinationSpread && handoff == null) {
        _showOracleError(
          const OracleBackendException('missing_astral_context'),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppStrings.t(language, 'oracle.personality.newReading')),
          content: Text(
            AppStrings.t(language, 'oracle.personality.keepHistory'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.t(language, 'oracle.personality.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                AppStrings.t(language, 'oracle.personality.newReading'),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          !_session.isCurrentSession(epoch) ||
          _oracleBusy) {
        return;
      }
      await _captureSession();
      if (!mounted || !_session.isCurrentSession(epoch) || _oracleBusy) return;
      _resetOracleBinding();
      _sessionTimestamp = null;
      if (handoff == null) {
        for (final slot in _ctrl.slots) {
          slot.oracleQuestion = null;
        }
        _session.reset();
        _tableSessionEpoch = _session.epoch;
        _capsuleText.clear();
      }
      _applyPersonality(choice);
      if (handoff != null) {
        await _runAstralReading(handoff, chosen: choice);
      }
      return;
    }
    _applyPersonality(choice);
  }

  void _applyPersonality(OraclePersonality choice) {
    setState(() {
      _useLocalOracle = choice.id.isEmpty;
      _explicitPersonality = _useLocalOracle ? null : choice;
      if (!_useLocalOracle) _preferredPersonality = choice.id;
    });
    if (choice.id.isNotEmpty) {
      _oraclePreferences
          .saveOraclePersonality(choice.id)
          .catchError((Object _) {});
    }
  }

  Future<RemoteOracleReading?> _prepareOracle({
    required int epoch,
    required Map<String, Object?> reading,
  }) async {
    if (!_backend.isConfigured || _useLocalOracle) return null;
    await _loadCatalogue();
    if (!mounted || !_session.isCurrentSession(epoch)) return null;
    final personality = _chosenPersonality;
    if (personality == null) return null;
    final signature = jsonEncode([personality.id, reading]);
    if (_remoteDraft?.signature != signature) {
      _remoteDraft = (
        signature: signature,
        id: OracleBackendService.newOperationKey(),
        reading: null,
      );
    }
    final draft = _remoteDraft!;
    final remote =
        draft.reading ??
        await _backend.createReading(
          personality: personality,
          clientSessionId: draft.id,
          reading: reading,
        );
    if (mounted && _session.isCurrentSession(epoch)) {
      _remoteDraft = (signature: signature, id: draft.id, reading: remote);
    }
    return remote;
  }

  void _showOracleError(Object error) {
    final code = error is OracleBackendException ? error.code : 'backend_error';
    final message = switch (code) {
      'guest_expired' => 'oracle.personality.guestExpired',
      'personality_unavailable' => 'oracle.personality.removed',
      'missing_astral_context' => 'oracle.personality.openAstral',
      _ => 'oracle.personality.failed',
    };
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(AppStrings.t(_language, message))));
  }

  Map<String, Object?> _spreadRequest() => {
    'kind': 'divinationSpread',
    'system': _ctrl.system.name,
    'source': ReadingSourceX.fromTableSourceMode(_ctrl.sourceMode).name,
    'mode': 'standard',
    'spreadId': _ctrl.isCustomSpread
        ? 'custom'
        : switch (_ctrl.system) {
            DivinationSystem.tarot => _ctrl.spreadType.name,
            DivinationSystem.lenormand => _ctrl.lenormandSpread.name,
            DivinationSystem.runes => _ctrl.runeCast.name,
          },
    'subject': _forSelf ? 'self' : 'other',
    if ((_forSelf ? _tableSubject : null) case final profile?)
      'selfContext': OracleBackendService.limitText(profile, 2000),
    'question': OracleBackendService.limitText(_ctrl.readingQuestion, 2000),
    'notes': [
      for (final note in _ctrl.sessionContextNotes.take(12))
        OracleBackendService.limitText(note, 500),
    ],
    'positions': [
      for (final slot in _ctrl.slots.take(_ctrl.initialSpreadCardCount))
        {
          'position': slot.index,
          'role': OracleBackendService.limitText(slot.role, 500),
          if (slot.userContext case final note?)
            'note': OracleBackendService.limitText(note, 2000),
        },
    ],
  };

  Future<void> _syncOracleCards(RemoteOracleReading remote) => _backend
      .syncCards(remote, _ctrl.slots, baseCount: _ctrl.initialSpreadCardCount);

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
    if (widget.oracleBackend == null) _backend.dispose();
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

  void _onSpreadChanged() {
    if (!mounted) return;
    if (_readingRevision != _ctrl.readingRevision) {
      _readingRevision = _ctrl.readingRevision;
      if (_restoringSpread) return;
      if (_sessionKind == SessionKind.divinationSpread) {
        if (_session.epoch == _tableSessionEpoch) _session.reset();
        _tableSessionEpoch = null;
        _sessionTimestamp = null;
        _resetOracleBinding();
      }
    }
    setState(() {});
    _maybeExpandClarifiers();
    if (_session.hasSynthesis &&
        _session.epoch == _tableSessionEpoch &&
        _archivedCardCounts != (_ctrl.dealtCount, _ctrl.faceUpCount)) {
      _captureSession();
    }
  }

  // ---- ASTRAL cross-tab handoff (natal / synastry to Oracle Chat) ----

  void _onAstralHandoff() {
    final handoff = widget.astralHandoff?.value;
    if (handoff == null) return;
    widget.astralHandoff!.value = null;
    _runAstralReading(handoff);
  }

  Future<void> _runAstralReading(
    OracleHandoff handoff, {
    OraclePersonality? chosen,
  }) async {
    // A fresh Astral reading replaces the previous astral thread and starts a
    // new history entry (astral dialogues were never persisted before).
    _resetOracleBinding();
    _useLocalOracle = chosen?.id.isEmpty ?? false;
    _explicitPersonality = _useLocalOracle ? null : chosen;
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
    try {
      final summary = OracleSynthesisService.astralOracleContext(handoff);
      final remote = summary.trim().isEmpty
          ? null
          : await _prepareOracle(
              epoch: epoch,
              reading: {
                'kind': _sessionKind.name,
                'astralContext': {
                  'schemaVersion': 1,
                  'summary': OracleBackendService.limitText(summary, 4000),
                },
              },
            );
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _remoteOracle = remote;
      if (remote != null) await _captureSession();
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      final answer = remote == null
          ? await _legacyOracle.answerAstral(
              context: handoff,
              history: const [],
            )
          : await _backend.answer(remote, 'Interpret this Astral reading.');
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _session.addOracleMessage(answer);
    } catch (error) {
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _showOracleError(error);
      _session.addSystemMessage('The Oracle could not respond.');
    }
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
      OracleHandoffKind.natalChart =>
        '${chart?.profileName ?? 'Natal'} · Natal',
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
    if (!_session.hasSynthesis || _session.epoch != _tableSessionEpoch) return;
    final remote = _remoteOracle;
    if (remote != null && _oracleBusy) return;
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
      if (remote != null) break;
    }
  }

  bool get _forSelf =>
      _ctrl.readingForSelf ??
      context.read<UserProfileController>().readingForSelf;

  String? get _tableSubject => _forSelf
      ? context.read<UserProfileController>().selfOracleContext
      : 'Reading for someone else';

  Future<void> _generateClarifier(ClarifierChapter chapter) async {
    final slot = _ctrl.slots.firstWhere((s) => s.index == chapter.slotIndex);
    final previous = _ctrl.slots
        .where((s) => s.index < chapter.slotIndex)
        .toList();
    final epoch = _session.epoch;
    final remote = _remoteOracle;
    String text;
    try {
      if (remote != null) {
        await _syncOracleCards(remote);
        if (!mounted || !_session.isCurrentSession(epoch)) return;
        text = await _backend.answer(
          remote,
          chapter.question,
          position: chapter.slotIndex,
        );
      } else {
        text = await _legacyOracle.synthesizeClarifier(
          question: chapter.question,
          newSlot: slot,
          previous: previous,
          profileContext: _tableSubject,
        );
      }
    } catch (_) {
      text = 'The Oracle could not answer. Your card is still in the spread.';
    }
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    _session.completeChapter(chapter.slotIndex, text);
    _maybeExpandClarifiers();
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
      _resetOracleBinding();
    }
    final epoch = _session.epoch;
    _tableSessionEpoch = epoch;
    // Keep the active editor mounted until the recognizer delivers its
    // final result, then leave the table and submit the confirmed draft.
    _finishingDraft = true;
    _session.startGenerating();
    StructuredSynthesis result;
    RemoteOracleReading? remote;
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
        if (_ctrl.readingQuestion.trim().isNotEmpty)
          _ctrl.readingQuestion.trim(),
        ..._ctrl.sessionContextNotes,
      ];
      remote = await _prepareOracle(epoch: epoch, reading: _spreadRequest());
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      if (remote != null) {
        await _syncOracleCards(remote);
        if (!mounted || !_session.isCurrentSession(epoch)) return;
        result = await _backend.synthesize(remote);
      } else {
        result = await _legacyOracle.synthesizeStructured(
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
      }
    } catch (error) {
      if (mounted && _session.isCurrentSession(epoch)) {
        _session.failInitial();
        if (_backend.isConfigured) _showOracleError(error);
      }
      return;
    }
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    if (result.narrative.trim().isEmpty) {
      _session.failInitial();
      return;
    }
    _remoteOracle = remote;
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
          title: _astralTitle ?? 'Astral reading',
          natalChartId: _astralChartId,
          astralContext: _astralContext,
          remoteOracle: _remoteOracle,
          messages: [..._session.messages],
        ),
      );
      return;
    }
    if (!_session.hasSynthesis) return;
    _archivedCardCounts = (_ctrl.dealtCount, _ctrl.faceUpCount);
    final timestamp = _sessionTimestamp ?? DateTime.now().toIso8601String();
    _sessionTimestamp = timestamp;
    await _history.upsert(
      SpreadSessionSnapshot.capture(
        ctrl: _ctrl,
        session: _session,
        timestamp: timestamp,
        notebook: SessionHistoryController.notebookFor(_ctrl),
        readingForSelf: _forSelf,
        sessionId: _session.sessionId,
        remoteOracle: _remoteOracle,
        readingSource: _session.readingSource,
        readingMode: _session.readingMode,
        readingStatus: _session.readingStatus,
      ),
    );
  }

  // ---- Oracle AI Chat (Pane 1) ----

  Future<void> _askOracle(String question) async {
    if (_sessionKind == SessionKind.divinationSpread &&
        !_session.hasSynthesis) {
      _session.addSystemMessage(
        'The reading is not synthesized yet — deal and flip your spread '
        'on the table, then tap ✦ SYNTHESIZE IN CHAT.',
      );
      return;
    }
    final remote = _remoteOracle;
    if (remote != null && _oracleBusy) {
      _restoreQuestionDraft(question);
      return;
    }
    if (remote == null) _session.addUserMessage(question);
    _session.beginAnswer();
    final isSpread = _sessionKind == SessionKind.divinationSpread;
    final profileContext = isSpread ? _tableSubject : null;
    final epoch = _session.epoch;
    if (remote == null) await _captureSession();
    if (!mounted || !_session.isCurrentSession(epoch)) return;
    try {
      String answer;
      if (remote != null) {
        if (isSpread) await _syncOracleCards(remote);
        if (!mounted || !_session.isCurrentSession(epoch)) return;
        answer = await _backend.answer(remote, question);
      } else {
        answer = isSpread
            ? await _legacyOracle.answerChat(
                question: question,
                slots: _ctrl.slots,
                type: _ctrl.spreadType,
                spreadLabel: _ctrl.spreadLabel,
                history: _session.messages,
                profileContext: profileContext,
              )
            : await _legacyOracle.answerAstral(
                context: _astralContext,
                question: question,
                history: _session.messages.skip(1).toList(),
              );
      }
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      if (remote != null) _session.addUserMessage(question);
      _session.addOracleMessage(answer);
    } catch (error) {
      if (!mounted || !_session.isCurrentSession(epoch)) return;
      _showOracleError(error);
      _restoreQuestionDraft(question);
    }
    _session.finishAnswer();
    await _captureSession();
    if (mounted && _session.isCurrentSession(epoch)) _maybeExpandClarifiers();
  }

  void _restoreQuestionDraft(String question) {
    Future<void>.microtask(() {
      if (mounted && _capsuleText.text.isEmpty) _capsuleText.text = question;
    });
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
    if (_remoteOracle != null && _oracleBusy) return false;
    if (_session.chapters.any(
      (chapter) => chapter.generating && chapter.question == question.trim(),
    )) {
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
        _ctrl.requestClarifierScan('What else does the table want to show?')) {
      widget.onOpenCameraClarifier!();
    } else {
      showDealLockPrompt(context, _ctrl);
    }
  }

  // ---- history (Pane 2) ----

  Future<void> _newSpread() async {
    await _captureSession(); // persist the current reading before leaving
    _sessionTimestamp = null;
    _sessionKind = SessionKind.divinationSpread;
    _clearAstralContext();
    _resetOracleBinding();
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
    _resetOracleBinding();
    _remoteOracle = snapshot.remoteOracle;
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
          sourceMode:
              snapshot.readingSource?.tableSourceMode ??
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
      _archivedCardCounts = (_ctrl.dealtCount, _ctrl.faceUpCount);
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
    showTaroGlassSheet<void>(
      context: context,
      builder: (sheetContext) => TaroGlassSheet(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ADD TO THE READING',
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

  String _oracleName(AppLanguage language, bool inConversation) {
    if (_remoteOracle case final remote?) return remote.personalityName;
    if (inConversation || _useLocalOracle) {
      return _localPersonality(language).name;
    }
    return _chosenPersonality?.name ??
        (_catalogue == null
            ? AppStrings.t(language, 'header.oracle')
            : _localPersonality(language).name);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final session = context.watch<OracleSessionController>();
    final language = context.watch<AppSettingsController>().language;
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
        bottom: false,
        child: PageView(
          controller: _paneController,
          onPageChanged: (index) {
            HapticFeedback.selectionClick();
            _pane = index;
            if (index == chatPane && _catalogue == null) _loadCatalogue();
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: TaroGlassLayer(
                      child: TaroGlassPill(
                        key: ValueKey('physical-sync-ribbon'),
                        label: 'PHYSICAL SYNC',
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
              oracleHeading: _backend.isConfigured || _remoteOracle != null
                  ? OraclePersonalitySelector(
                      name: _oracleName(language, inConversation),
                      onTap: _oracleBusy ? null : _pickPersonality,
                    )
                  : null,
              inConversation: inConversation,
              showReadingCards: isSpread,
              readingKey:
                  session.sessionId ?? _sessionTimestamp ?? session.epoch,
              capsuleText: _capsuleText,
              composer: inConversation
                  ? _buildFooter(ctrl, onTable: false)
                  : null,
              onBackToTable: () => _goToPane(tablePane),
              onSynthesize: _runSynthesis,
              onClarifierQuestion: _requestClarifierForQuestion,
              onFocusInput: () => _capsuleFocus.requestFocus(),
              onScanClarifier: _scanClarifier,
              onResumeCamera: () => widget.onResumeCamera?.call(),
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
              TaroGlassLayer(
                child: AnalyzeReadingButton(
                  key: const ValueKey('analyze-reading-button'),
                  enabled:
                      ctrl.isSpreadActive &&
                      (ctrl.canSynthesize || _session.hasSynthesis) &&
                      !_session.generatingInitial,
                  onPressed: () => _goToPane(chatPane),
                ),
              ),
            ] else ...[
              TaroGlassLayer(
                child: GeminiInputCapsule(
                  fieldKey: const ValueKey('oracle-input'),
                  sendKey: const ValueKey('oracle-send'),
                  controller: _capsuleText,
                  focusNode: _capsuleFocus,
                  hint: 'Ask the Oracle — or type a question for a +1 card...',
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
              'CAMERA CLARIFIER: "$question"',
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
            tooltip: 'Cancel clarifier',
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
