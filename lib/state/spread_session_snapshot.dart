import '../core/models/chat_message.dart';
import '../core/models/dealt_card_slot.dart';
import '../core/models/divination_system.dart';
import '../core/models/lenormand_spread.dart';
import '../core/models/oracle_handoff.dart';
import '../core/models/reading_mode.dart';
import '../core/models/reading_source.dart';
import '../core/models/reading_status.dart';
import '../core/models/rune_cast.dart';
import '../core/models/spread_type.dart';
import '../core/services/oracle_synthesis_service.dart';
import 'spread_controller.dart';
import 'synthesis_session.dart';

/// What produced a saved session — a table spread or an Astral reading.
/// Drives the history badge and the restore branch (astral sessions have no
/// dealt cards, only the conversation).
enum SessionKind {
  divinationSpread,
  natalChartReading,
  horoscopeReading,
  synastryReading,
  zodiacReading,
}

/// One saved card of a session: exact identity, orientation, slot role and
/// the pre-draw intention it carried.
class RestoredSpreadCard {
  const RestoredSpreadCard({
    required this.cardId,
    required this.reversed,
    required this.role,
    this.userContext,
    this.oracleQuestion,
    this.fromPhysicalCard,
    this.faceDown = false,
  });

  final int cardId;
  final bool reversed;
  final String role;
  final String? userContext;
  final String? oracleQuestion;
  final bool? fromPhysicalCard;
  final bool faceDown;

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'reversed': reversed,
    'role': role,
    if (userContext != null) 'userContext': userContext,
    if (oracleQuestion != null) 'oracleQuestion': oracleQuestion,
    if (fromPhysicalCard != null) 'fromPhysicalCard': fromPhysicalCard,
    if (faceDown) 'faceDown': true,
  };

  static RestoredSpreadCard fromJson(Map<String, dynamic> json) =>
      RestoredSpreadCard(
        cardId: json['cardId'] as int,
        reversed: json['reversed'] as bool,
        role: json['role'] as String,
        userContext: json['userContext'] as String?,
        oracleQuestion: json['oracleQuestion'] as String?,
        fromPhysicalCard: json['fromPhysicalCard'] as bool?,
        faceDown: json['faceDown'] == true,
      );
}

/// One fully restorable reading session: the exact dealt cards with their
/// orientations and roles, the session context notes (the ether), the
/// structured synthesis, the clarifier chapters and the whole Oracle AI
/// Chat conversation. Serialized to local JSON — the device is the only
/// store of truth.
class SpreadSessionSnapshot {
  const SpreadSessionSnapshot({
    required this.timestamp,
    required this.spreadType,
    required this.notebook,
    required this.cards,
    required this.sessionNotes,
    this.readingQuestion = '',
    this.readingForSelf,
    required this.synthesis,
    required this.chapters,
    required this.messages,
    this.system = DivinationSystem.tarot,
    this.lenormandSpread = LenormandSpread.three,
    this.runeCast = RuneCast.three,
    this.kind = SessionKind.divinationSpread,
    this.astralSessionTitle,
    this.natalChartId,
    this.astralContext,
    this.sessionId,
    this.readingSource,
    this.readingMode,
    this.readingStatus,
    this.completionStatus,
    this.voiceUsed,
    this.customSpread,
    this.customQuestions = const [],
    this.compareNeighbors = false,
    this.pendingGuidedPosition,
  });

  /// An Astral (natal / horoscope / synastry / zodiac) conversation with no
  /// dealt cards — the snapshot only carries the Oracle dialogue.
  factory SpreadSessionSnapshot.astral({
    required String timestamp,
    required SessionKind kind,
    required String title,
    required List<ChatMessage> messages,
    String? natalChartId,
    OracleHandoff? astralContext,
  }) => SpreadSessionSnapshot(
    timestamp: timestamp,
    spreadType: SpreadType.three,
    notebook: 'All Readings',
    cards: const [],
    sessionNotes: const [],
    synthesis: null,
    chapters: const [],
    messages: messages,
    kind: kind,
    astralSessionTitle: title,
    natalChartId: natalChartId,
    astralContext: astralContext,
  );

  /// Identity + local persistence key (ISO-8601).
  final String timestamp;

  /// The divination system this session was cast with.
  final DivinationSystem system;

  /// Tarot spread template (authoritative when [system] == tarot).
  final SpreadType spreadType;

  /// Lenormand spread template (authoritative when [system] == lenormand).
  final LenormandSpread lenormandSpread;

  /// Rune cast template (authoritative when [system] == runes).
  final RuneCast runeCast;

  /// Thematic notebook: 'All Readings' | 'Relationships' | 'Career & Path'.
  final String notebook;

  final List<RestoredSpreadCard> cards;
  final List<String> sessionNotes;
  final String readingQuestion;
  final bool? readingForSelf;
  final StructuredSynthesis? synthesis;
  final List<ClarifierChapter> chapters;
  final List<ChatMessage> messages;

  /// Which flow saved this session (spread vs. Astral reading).
  final SessionKind kind;

  /// Human-readable Astral title, e.g. 'Self · Natal' (null for spreads).
  final String? astralSessionTitle;

  /// The natal profile the Astral session was read from (null if none).
  final String? natalChartId;

  /// Frozen chart and forecast used by the original Oracle reading.
  final OracleHandoff? astralContext;

  /// Stable session id shared across Camera/Table/Oracle for ONE reading.
  /// Optional for backward compatibility: legacy snapshots have none and
  /// fall back to [timestamp] (see [effectiveSessionId]); the archive key
  /// stays [timestamp] regardless.
  final String? sessionId;

  /// Session-level origin of the reading (null for legacy snapshots).
  final ReadingSource? readingSource;

  /// How the reading was driven (null for legacy snapshots).
  final ReadingMode? readingMode;

  /// Live lifecycle status at capture time (null for legacy snapshots).
  final ReadingStatus? readingStatus;

  /// True when the reading reached a completed end-state, false when it was
  /// abandoned/incomplete, null when unknown (legacy snapshots).
  final bool? completionStatus;

  /// True when voice input/output was used during this reading.
  final bool? voiceUsed;

  /// A custom (non-template) spread definition identifier, when the reading
  /// used one (null for template spreads and legacy snapshots).
  final String? customSpread;

  /// Ordered list of questions for a custom spread (1 question = 1 position),
  /// stored alongside the cards so history preserves questions and order.
  final List<String> customQuestions;
  final bool compareNeighbors;

  /// The guided-spread slot position the session was paused at, so a restored
  /// guided reading can resume there (null when not a paused guided session).
  final int? pendingGuidedPosition;

  /// Runtime identity: the stable [sessionId] when present, else the legacy
  /// [timestamp] — old and new snapshots share one fallback.
  String get effectiveSessionId => sessionId ?? timestamp;

  /// Captures the current table + session state into a serializable
  /// snapshot (history upsert). The optional session metadata is read from
  /// the shared [OracleSessionController] by the caller (passed explicitly
  /// to avoid a circular import between the snapshot and the controller).
  static SpreadSessionSnapshot capture({
    required SpreadController ctrl,
    required SynthesisSession session,
    required String timestamp,
    required String notebook,
    bool? readingForSelf,
    String? sessionId,
    ReadingSource? readingSource,
    ReadingMode? readingMode,
    ReadingStatus? readingStatus,
  }) {
    return SpreadSessionSnapshot(
      timestamp: timestamp,
      system: ctrl.system,
      spreadType: ctrl.spreadType,
      lenormandSpread: ctrl.lenormandSpread,
      runeCast: ctrl.runeCast,
      notebook: notebook,
      cards: [
        for (final s in ctrl.slots)
          if (s.card != null)
            RestoredSpreadCard(
              cardId: s.card!.id,
              reversed: s.isReversed,
              role: s.role,
              userContext: s.userContext,
              oracleQuestion: s.oracleQuestion,
              fromPhysicalCard: s.fromPhysicalCard,
              faceDown: s.state == SlotState.faceDown,
            ),
      ],
      sessionNotes: [...ctrl.sessionContextNotes],
      readingQuestion: ctrl.readingQuestion,
      readingForSelf: ctrl.readingForSelf ?? readingForSelf,
      synthesis: session.initial,
      chapters: [
        for (final c in session.chapters)
          if (c.text.isNotEmpty)
            ClarifierChapter(
              slotIndex: c.slotIndex,
              question: c.question,
              cardName: c.cardName,
              isReversed: c.isReversed,
            )..text = c.text,
      ],
      messages: [...session.messages],
      sessionId: sessionId,
      readingSource: readingSource,
      readingMode: readingMode,
      readingStatus: readingStatus,
      customSpread: ctrl.customSpread?.name,
      compareNeighbors: ctrl.customSpread?.compareNeighbors ?? false,
      customQuestions: ctrl.customSpread?.questions ?? const [],
    );
  }

  Map<int, String> get oracleQuestions => {
    for (final (index, card) in cards.indexed)
      if (card.oracleQuestion != null) index: card.oracleQuestion!,
  };

  Set<int> get faceDownCards => {
    for (final (index, card) in cards.indexed)
      if (card.faceDown) index,
  };

  Set<int> get physicalCards => {
    for (final (index, card) in cards.indexed)
      if (card.fromPhysicalCard ?? readingSource != ReadingSource.digital)
        index,
  };

  List<({int cardId, bool reversed, String role, String? userContext})>
  toRestoreCards() => [
    for (final c in cards)
      (
        cardId: c.cardId,
        reversed: c.reversed,
        role: c.role,
        userContext: c.userContext,
      ),
  ];

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'system': system.name,
    'spreadType': spreadType.name,
    'lenormandSpread': lenormandSpread.name,
    'runeCast': runeCast.name,
    'notebook': notebook,
    'cards': [for (final c in cards) c.toJson()],
    'sessionNotes': sessionNotes,
    if (readingQuestion.isNotEmpty) 'readingQuestion': readingQuestion,
    if (readingForSelf != null) 'readingForSelf': readingForSelf,
    if (synthesis != null)
      'synthesis': {
        'narrative': synthesis!.narrative,
        'elementalAlchemy': synthesis!.elementalAlchemy,
        'verdict': synthesis!.verdict,
        'followUp': synthesis!.followUp,
      },
    'chapters': [
      for (final c in chapters)
        {
          'slotIndex': c.slotIndex,
          'question': c.question,
          'cardName': c.cardName,
          'isReversed': c.isReversed,
          'text': c.text,
        },
    ],
    'messages': [for (final m in messages) m.toJson()],
    'kind': kind.name,
    if (astralSessionTitle != null) 'astralSessionTitle': astralSessionTitle,
    if (natalChartId != null) 'natalChartId': natalChartId,
    if (astralContext != null) 'astralContext': astralContext!.toJson(),
    if (sessionId != null) 'sessionId': sessionId,
    if (readingSource != null) 'readingSource': readingSource!.name,
    if (readingMode != null) 'readingMode': readingMode!.name,
    if (readingStatus != null) 'readingStatus': readingStatus!.name,
    if (completionStatus != null) 'completionStatus': completionStatus,
    if (voiceUsed != null) 'voiceUsed': voiceUsed,
    if (customSpread != null) 'customSpread': customSpread,
    if (compareNeighbors) 'compareNeighbors': true,
    if (customQuestions.isNotEmpty) 'customQuestions': customQuestions,
    if (pendingGuidedPosition != null)
      'pendingGuidedPosition': pendingGuidedPosition,
  };

  static SpreadSessionSnapshot fromJson(Map<String, dynamic> json) {
    final synthesisJson = json['synthesis'] as Map<String, dynamic>?;
    OracleHandoff? astralContext;
    final rawContext = json['astralContext'];
    if (rawContext is Map<String, dynamic>) {
      try {
        astralContext = OracleHandoff.fromJson(rawContext);
      } catch (_) {
        // An invalid calculation snapshot must not hide the saved dialogue.
      }
    }
    return SpreadSessionSnapshot(
      timestamp: json['timestamp'] as String,
      system: _enumOr<DivinationSystem>(
        DivinationSystem.values,
        json['system'] as String?,
        DivinationSystem.tarot,
      ),
      spreadType: _enumOr<SpreadType>(
        SpreadType.values,
        json['spreadType'] as String?,
        SpreadType.three,
      ),
      lenormandSpread: _enumOr<LenormandSpread>(
        LenormandSpread.values,
        json['lenormandSpread'] as String?,
        LenormandSpread.three,
      ),
      runeCast: _enumOr<RuneCast>(
        RuneCast.values,
        json['runeCast'] as String?,
        RuneCast.three,
      ),
      notebook: json['notebook'] as String? ?? 'All Readings',
      cards: [
        for (final raw in (json['cards'] as List? ?? const []))
          RestoredSpreadCard.fromJson(raw as Map<String, dynamic>),
      ],
      readingQuestion: json['readingQuestion'] as String? ?? '',
      readingForSelf: json['readingForSelf'] as bool?,
      sessionNotes: (json['sessionNotes'] as List? ?? const []).cast<String>(),
      synthesis: synthesisJson == null
          ? null
          : StructuredSynthesis(
              narrative: synthesisJson['narrative'] as String,
              elementalAlchemy: synthesisJson['elementalAlchemy'] as String,
              verdict: synthesisJson['verdict'] as String,
              followUp: synthesisJson['followUp'] as String,
            ),
      chapters: [
        for (final raw in (json['chapters'] as List? ?? const []))
          _chapterFromJson(raw as Map<String, dynamic>),
      ],
      messages: [
        for (final raw in (json['messages'] as List? ?? const []))
          ChatMessage.fromJson(raw as Map<String, dynamic>),
      ],
      kind: _enumOr<SessionKind>(
        SessionKind.values,
        json['kind'] as String?,
        SessionKind.divinationSpread,
      ),
      astralSessionTitle: json['astralSessionTitle'] as String?,
      natalChartId: json['natalChartId'] as String?,
      astralContext: astralContext,
      sessionId: json['sessionId'] as String?,
      readingSource: _enumOrNullable<ReadingSource>(
        ReadingSource.values,
        json['readingSource'] as String?,
      ),
      readingMode: _enumOrNullable<ReadingMode>(
        ReadingMode.values,
        json['readingMode'] as String?,
      ),
      readingStatus: _enumOrNullable<ReadingStatus>(
        ReadingStatus.values,
        json['readingStatus'] as String?,
      ),
      completionStatus: json['completionStatus'] as bool?,
      voiceUsed: json['voiceUsed'] as bool?,
      compareNeighbors: json['compareNeighbors'] == true,
      customSpread: json['customSpread'] as String?,
      customQuestions:
          (json['customQuestions'] as List? ?? const []).cast<String>(),
      pendingGuidedPosition: json['pendingGuidedPosition'] as int?,
    );
  }

  static ClarifierChapter _chapterFromJson(Map<String, dynamic> json) {
    final chapter = ClarifierChapter(
      slotIndex: json['slotIndex'] as int,
      question: json['question'] as String,
      cardName: json['cardName'] as String,
      isReversed: json['isReversed'] as bool,
    );
    chapter.text = json['text'] as String? ?? '';
    chapter.generating = false;
    return chapter;
  }
}

/// Forgiving enum lookup for persisted JSON: unknown/missing keys fall
/// back to [fallback] instead of throwing (forward compatibility with
/// sessions saved before a field existed).
T _enumOr<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Nullable variant of [_enumOr] for fields that did not exist in legacy
/// snapshots: missing or unknown names fall back to null (forward
/// compatible), so old JSON loads without error.
T? _enumOrNullable<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
