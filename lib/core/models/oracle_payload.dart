import 'dealt_card_slot.dart';
import 'divination_system.dart';
import 'oracle_action.dart';
import 'reading_mode.dart';
import 'reading_source.dart';

/// The canonical, system-qualified identity of one card — the ONLY id form the
/// Oracle ever receives (never an image, never a bbox). Stable across
/// serialization: `tarot:13`, `lenormand:9`, `runes:5`.
String canonicalCardId(DivinationSystem system, int id) =>
    '${system.name}:$id';

/// One card in the compact Oracle context. Deliberately carries NO bounding
/// box and NO image bytes — a bbox update can therefore never change the
/// payload or trigger an LLM request.
class OraclePayloadCard {
  const OraclePayloadCard({
    required this.cardId,
    required this.position,
    this.role,
    required this.orientation,
    required this.source,
    required this.confirmed,
  });

  final String cardId;
  final int position;
  final String? role;

  /// 'upright' | 'reversed'.
  final String orientation;

  /// 'digital' | 'physical'.
  final String source;
  final bool confirmed;

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'position': position,
        if (role != null) 'role': role,
        'orientation': orientation,
        'source': source,
        'confirmed': confirmed,
      };
}

/// The compact, structured context handed to the Oracle for ONE reading turn
/// (4.7 payload contract): `schemaVersion/sessionId/source/mode/system/
/// spreadId/currentPosition/cards[...]/expectedAction`.
class OraclePayload {
  const OraclePayload({
    required this.schemaVersion,
    required this.sessionId,
    required this.source,
    required this.mode,
    required this.system,
    this.spreadId,
    this.currentPosition,
    required this.cards,
    this.expectedAction,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String sessionId;
  final String source;
  final String mode;
  final String system;
  final String? spreadId;
  final int? currentPosition;
  final List<OraclePayloadCard> cards;
  final String? expectedAction;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'sessionId': sessionId,
        'source': source,
        'mode': mode,
        'system': system,
        if (spreadId != null) 'spreadId': spreadId,
        if (currentPosition != null) 'currentPosition': currentPosition,
        'cards': [for (final c in cards) c.toJson()],
        if (expectedAction != null) 'expectedAction': expectedAction,
      };

  /// Builds the compact context from the live session state. Only FACE-UP
  /// (revealed, confirmed) cards are described — a face-down card's identity
  /// is not part of the reading yet and is never leaked to the Oracle. Real
  /// canonical IDs only (see [canonicalCardId]).
  static OraclePayload build({
    required String sessionId,
    required ReadingSource source,
    required ReadingMode mode,
    required DivinationSystem system,
    required List<DealtCardSlot> slots,
    String? spreadId,
    int? currentPosition,
    OracleAction? expectedAction,
  }) {
    final cards = <OraclePayloadCard>[];
    for (final s in slots) {
      final c = s.card;
      if (c == null || s.state != SlotState.faceUp) continue;
      cards.add(OraclePayloadCard(
        cardId: canonicalCardId(c.system, c.id),
        position: s.index,
        role: s.role,
        orientation: s.isReversed ? 'reversed' : 'upright',
        source: s.fromPhysicalCard ? 'physical' : 'digital',
        confirmed: true,
      ));
    }
    return OraclePayload(
      schemaVersion: currentSchemaVersion,
      sessionId: sessionId,
      source: source.name,
      mode: mode.name,
      system: system.name,
      spreadId: spreadId,
      currentPosition: currentPosition,
      cards: cards,
      expectedAction: expectedAction?.wireName,
    );
  }
}
