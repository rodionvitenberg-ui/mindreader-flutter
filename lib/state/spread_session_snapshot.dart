import '../core/models/chat_message.dart';
import '../core/models/spread_type.dart';
import '../core/services/oracle_synthesis_service.dart';
import 'spread_controller.dart';
import 'synthesis_session.dart';

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
  });

  /// Identity + local persistence key (ISO-8601).
  final String timestamp;

  final SpreadType spreadType;

  /// Thematic notebook: 'All Readings' | 'Relationships' | 'Career & Path'.
  final String notebook;

  final List<RestoredSpreadCard> cards;
  final List<String> sessionNotes;
  final StructuredSynthesis? synthesis;
  final List<ClarifierChapter> chapters;
  final List<ChatMessage> messages;

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
      spreadType: ctrl.spreadType,
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
        'spreadType': spreadType.name,
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
      };

  static SpreadSessionSnapshot fromJson(Map<String, dynamic> json) {
    final synthesisJson = json['synthesis'] as Map<String, dynamic>?;
    return SpreadSessionSnapshot(
      timestamp: json['timestamp'] as String,
      spreadType: SpreadType.values.byName(json['spreadType'] as String),
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
