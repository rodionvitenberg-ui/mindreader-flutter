import '../core/models/chat_message.dart';
import '../core/models/divination_system.dart';
import '../core/models/lenormand_spread.dart';
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
  });

  final int cardId;
  final bool reversed;
  final String role;
  final String? userContext;

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'reversed': reversed,
        'role': role,
        if (userContext != null) 'userContext': userContext,
      };

  static RestoredSpreadCard fromJson(Map<String, dynamic> json) =>
      RestoredSpreadCard(
        cardId: json['cardId'] as int,
        reversed: json['reversed'] as bool,
        role: json['role'] as String,
        userContext: json['userContext'] as String?,
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
    required this.synthesis,
    required this.chapters,
    required this.messages,
    this.system = DivinationSystem.tarot,
    this.lenormandSpread = LenormandSpread.three,
    this.runeCast = RuneCast.three,
    this.kind = SessionKind.divinationSpread,
    this.astralSessionTitle,
    this.natalChartId,
  });

  /// An Astral (natal / horoscope / synastry / zodiac) conversation with no
  /// dealt cards — the snapshot only carries the Oracle dialogue.
  factory SpreadSessionSnapshot.astral({
    required String timestamp,
    required SessionKind kind,
    required String title,
    required List<ChatMessage> messages,
    String? natalChartId,
  }) =>
      SpreadSessionSnapshot(
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
  final StructuredSynthesis? synthesis;
  final List<ClarifierChapter> chapters;
  final List<ChatMessage> messages;

  /// Which flow saved this session (spread vs. Astral reading).
  final SessionKind kind;

  /// Human-readable Astral title, e.g. 'Self · Natal' (null for spreads).
  final String? astralSessionTitle;

  /// The natal profile the Astral session was read from (null if none).
  final String? natalChartId;

  /// Captures the current table + session state into a serializable
  /// snapshot (history upsert).
  static SpreadSessionSnapshot capture({
    required SpreadController ctrl,
    required SynthesisSession session,
    required String timestamp,
    required String notebook,
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
            ),
      ],
      sessionNotes: [...ctrl.sessionContextNotes],
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
    );
  }

  List<({int cardId, bool reversed, String role, String? userContext})>
      toRestoreCards() => [
            for (final c in cards)
              (cardId: c.cardId, reversed: c.reversed, role: c.role, userContext: c.userContext),
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
        if (astralSessionTitle != null)
          'astralSessionTitle': astralSessionTitle,
        if (natalChartId != null) 'natalChartId': natalChartId,
      };

  static SpreadSessionSnapshot fromJson(Map<String, dynamic> json) {
    final synthesisJson = json['synthesis'] as Map<String, dynamic>?;
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
      sessionNotes:
          (json['sessionNotes'] as List? ?? const []).cast<String>(),
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

