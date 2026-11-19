import 'dart:convert';

/// What the Oracle may ASK the app to do next during a Live Oracle freeform
/// session. The app is AUTHORITATIVE: the Oracle only ever suggests an action;
/// it can never mutate cards, a canonicalCardId, an orientation, a deck limit,
/// the PRO gate or history. Actions that would do so are structurally
/// impossible — this enum carries no card-mutation payload, and the parser
/// (below) drops any attempt to smuggle one in.
enum OracleAction {
  respond,
  suggestSpread,
  requestNextCard,
  requestClarifier,
  requestReveal,
  askQuestion,
  summarizeSpread,
  completeReading,
  none,
}

extension OracleActionX on OracleAction {
  String get wireName => switch (this) {
        OracleAction.respond => 'respond',
        OracleAction.suggestSpread => 'suggestSpread',
        OracleAction.requestNextCard => 'requestNextCard',
        OracleAction.requestClarifier => 'requestClarifier',
        OracleAction.requestReveal => 'requestReveal',
        OracleAction.askQuestion => 'askQuestion',
        OracleAction.summarizeSpread => 'summarizeSpread',
        OracleAction.completeReading => 'completeReading',
        OracleAction.none => 'none',
      };

  /// Unknown/absent action names degrade to [OracleAction.respond] — a safe,
  /// text-only answer — so a malformed command NEVER becomes a state change.
  static OracleAction fromWire(String? raw) => switch (raw) {
        'respond' => OracleAction.respond,
        'suggestSpread' => OracleAction.suggestSpread,
        'requestNextCard' => OracleAction.requestNextCard,
        'requestClarifier' => OracleAction.requestClarifier,
        'requestReveal' => OracleAction.requestReveal,
        'askQuestion' => OracleAction.askQuestion,
        'summarizeSpread' => OracleAction.summarizeSpread,
        'completeReading' => OracleAction.completeReading,
        'none' => OracleAction.none,
        _ => OracleAction.respond,
      };
}

/// A validated Oracle turn: the spoken/shown text plus the (optional) action
/// the Oracle requests. Parsed STRICTLY from the LLM's output — unknown or
/// malformed input degrades to a plain [OracleAction.respond] carrying the raw
/// text, so an incorrect command becomes text/clarification, never a mutation.
class OracleActionCommand {
  const OracleActionCommand({
    required this.action,
    required this.text,
    this.position,
  });

  final OracleAction action;
  final String text;

  /// Honored only for [OracleAction.requestReveal] and
  /// [OracleAction.requestNextCard] — the 0-based slot the Oracle refers to.
  /// The CALLER validates it against the real spread (the app is
  /// authoritative); the parser only keeps a non-negative int for those two.
  final int? position;

  bool get hasAction =>
      action != OracleAction.none && action != OracleAction.respond;
}

/// Parses an LLM action response. Strict and total — never throws.
///
/// [raw] may be plain prose (no JSON) or a JSON object
/// `{"action": "...", "text": "...", "position": n}`. Only the whitelisted
/// keys are read; any attempt to inject cards / canonicalCardId / orientation /
/// limits / PRO / history is silently dropped, because those fields do not
/// exist on [OracleActionCommand].
OracleActionCommand parseOracleActionResponse(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const OracleActionCommand(action: OracleAction.respond, text: '');
  }

  final Map<String, dynamic> json;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      return OracleActionCommand(action: OracleAction.respond, text: trimmed);
    }
    json = decoded;
  } catch (_) {
    // Not JSON — a plain prose answer.
    return OracleActionCommand(action: OracleAction.respond, text: trimmed);
  }

  final text = (json['text'] is String ? json['text'] as String : '').trim();
  final action = OracleActionX.fromWire(json['action'] as String?);
  final rawPosition = json['position'];
  final position = rawPosition is int && rawPosition >= 0 ? rawPosition : null;
  final honorsPosition = action == OracleAction.requestReveal ||
      action == OracleAction.requestNextCard;

  return OracleActionCommand(
    action: action,
    text: text,
    position: honorsPosition ? position : null,
  );
}
