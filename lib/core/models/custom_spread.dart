/// User-defined spread built from an ordered list of questions ("Свой расклад"
/// / "Custom Spread"): 1 question = 1 position, from 1 to [maxPositions] (12).
/// Pure Dart — no Flutter imports.
class CustomSpreadConfig {
  const CustomSpreadConfig({
    required this.name,
    required this.questions,
    required this.slotRoleShorts,
  });

  /// Maximum number of question-driven positions in the v1 Custom Spread
  /// builder.
  static const int maxPositions = 12;

  /// Builds a sanitized custom spread strictly from [questions]: blank lines
  /// are dropped, order is preserved, and count is capped at [maxCards] (12).
  /// Throws [ArgumentError] if no non-empty question remains.
  factory CustomSpreadConfig.fromQuestions({
    required List<String> questions,
    String name = '',
    String defaultName = 'Custom Spread',
    int maxCards = maxPositions,
  }) {
    final cleaned = <String>[];
    for (final q in questions) {
      final t = q.trim();
      if (t.isNotEmpty) {
        cleaned.add(t);
        if (cleaned.length >= maxCards) break;
      }
    }
    if (cleaned.isEmpty) {
      throw ArgumentError('CustomSpreadConfig requires at least one question.');
    }
    final resolvedName = name.trim().isEmpty ? defaultName : name.trim();
    final shorts = List<String>.generate(cleaned.length, (i) {
      final q = cleaned[i];
      if (q.length <= 24) return q;
      return '${q.substring(0, 23)}…';
    });
    return CustomSpreadConfig(
      name: resolvedName,
      questions: List.unmodifiable(cleaned),
      slotRoleShorts: List.unmodifiable(shorts),
    );
  }

  /// Display name of the custom spread (e.g. "Свой расклад" / "Custom Spread").
  final String name;

  /// Ordered list of user questions — one question per table position (1..12).
  final List<String> questions;

  /// Compact labels per slot for Spread View empty-slot placeholders.
  final List<String> slotRoleShorts;

  /// Position count is strictly determined by the list of questions.
  int get cardCount => questions.length;

  /// Each slot's role IS its user question, in exact position order.
  List<String> get slotRoles => questions;

  /// Concise label matching preset format, e.g. "5 · Custom Spread".
  String get label => '$cardCount · $name';

  /// Focus line sent to the Oracle synthesis prompt.
  String get focusLine =>
      'Custom $cardCount-card spread: connect every question–card pair into '
      'one cohesive reading.';
}
